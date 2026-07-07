// module stage1 #(
//     parameter SRC_W     = 1920,
//     parameter SRC_H     = 1080,
//     parameter DST_W     = 1280,
//     parameter DST_H     = 720,
//     parameter ADDR_BITS = 11,
//     parameter FRAC_BITS = 8
// )(
//     input  clk,
//     input  rst,
//     input  start,
//     input  s1_ready,
//     output               row_done,
//     output reg [ADDR_BITS-1:0] col_left,
//     output reg [ADDR_BITS-1:0] col_right,
//     output reg [ADDR_BITS-1:0] row_top,
//     output reg [ADDR_BITS-1:0] row_bot,
//     output reg [FRAC_BITS-1:0] frac_x,
//     output reg [FRAC_BITS-1:0] frac_y,
//     output reg                 s1_valid,
//     output reg [1:0]           row_top_mod3,
//     output reg [1:0]           row_bot_mod3
// );

//     localparam SCALE_X = (SRC_W << FRAC_BITS) / DST_W;
//     localparam SCALE_Y = (SRC_H << FRAC_BITS) / DST_H;

//     reg [ADDR_BITS+FRAC_BITS-1:0] x_total;
//     reg [ADDR_BITS+FRAC_BITS-1:0] y_total;
//     reg [ADDR_BITS-1:0]           x_out;
//     reg [ADDR_BITS-1:0]           y_out;
//     reg                           active;

//     reg [1:0] src_row_mod3;

//     // ── Combinational coordinate decode ──────────────────────────
//     wire [ADDR_BITS-1:0] col_left_next  = x_total[ADDR_BITS+FRAC_BITS-1 : FRAC_BITS];
//     wire [ADDR_BITS-1:0] col_right_next = (col_left_next == SRC_W-1)? col_left_next: col_left_next + 1'b1;
//     wire [ADDR_BITS-1:0] row_top_next   = y_total[ADDR_BITS+FRAC_BITS-1 : FRAC_BITS];
//     wire [ADDR_BITS-1:0] row_bot_next   = (row_top_next == SRC_H-1)? row_top_next: row_top_next + 1'b1;
//     wire [FRAC_BITS-1:0] frac_x_next    = x_total[FRAC_BITS-1:0];
//     wire [FRAC_BITS-1:0] frac_y_next    = y_total[FRAC_BITS-1:0];
//     assign row_done = (row_top_next != row_top);
//     wire [1:0] row_top_mod3_next = (row_top_mod3 == 2'd2) ? 2'd0: row_top_mod3 + 1'b1;
//     wire [1:0] row_bot_mod3_next = (row_top_next != SRC_H - 1)?((row_bot_mod3 == 2'd2) ? 2'd0: row_bot_mod3 + 1'b1) : (row_top_mod3_next);

//     always @(posedge clk) begin
//         if (rst) begin
//             active       <= 1'b0;
//             s1_valid     <= 1'b0;
//             x_out        <= 0;
//             y_out        <= 0;
//             x_total      <= 0;
//             y_total      <= 0;
//             col_left     <= 0;
//             col_right    <= 0;
//             row_top      <= 0;
//             row_bot      <= 0;
//             frac_x       <= 0;
//             frac_y       <= 0;
//             row_top_mod3 <= 2'd0;
//             row_bot_mod3 <= 2'd0;

//         end
//         else if (start) begin
//             active       <= 1'b1;
//             s1_valid     <= 1'b0;
//             x_out        <= 0;
//             y_out        <= 0;
//             x_total      <= 0;
//             y_total      <= 0;
//             row_top_mod3 <= 0;
//             row_bot_mod3 <= 1;   
//         end
//         else if (active) begin
//             if(s1_ready) begin
//                 col_left     <= col_left_next;
//                 col_right    <= col_right_next;
//                 row_top      <= row_top_next;
//                 row_bot      <= row_bot_next;
//                 frac_x       <= frac_x_next;
//                 frac_y       <= frac_y_next;
//                 s1_valid     <= 1'b1;
//             end

//             if (s1_ready && row_done) begin
//                 row_top_mod3 <= row_top_mod3_next;
//                 row_bot_mod3 <= row_bot_mod3_next;
//             end


//             if (s1_ready) begin
//                 if (x_out == DST_W - 1) begin
//                     x_out   <= 0;
//                     x_total <= 0;
//                     if (y_out == DST_H - 1) begin
//                         active   <= 1'b0;
//                         // NOTE: s1_valid is intentionally left alone here.
//                         // It was already set <= 1'b1 above for THIS (final)
//                         // pixel earlier in this same always block; since
//                         // both were NBAs to the same reg on the same edge,
//                         // writing s1_valid <= 1'b0 here used to silently
//                         // win and drop the last pixel of every frame.
//                         // active going low next cycle naturally stops the
//                         // (active) branch from firing again, which drives
//                         // s1_valid back to 0 on the cycle after this one.
//                     end
//                     else begin
//                         y_out   <= y_out + 1'b1;
//                         y_total <= y_total + SCALE_Y;
//                     end
//                 end
//                 else begin
//                     x_out   <= x_out + 1'b1;
//                     x_total <= x_total + SCALE_X;
//                 end
//             end
//         end
//         else begin
//             // Idle (rst=0, start=0, active=0): the cycle right after the
//             // final pixel's s1_valid<=1 was issued lands here. Drop it
//             // now so s1_valid doesn't latch high forever with no `active`
//             // branch left to ever clear it.
//             s1_valid <= 1'b0;
//         end
//     end

// endmodule
module stage1 #(
    parameter SRC_W     = 1920,
    parameter SRC_H     = 1080,
    parameter DST_W     = 1280,
    parameter DST_H     = 720,
    parameter ADDR_BITS = 11,
    parameter FRAC_BITS = 8
)(
    input  clk,
    input  rst,
    input  start,
    input  s1_ready,
    output               row_done,
    output reg [ADDR_BITS-1:0] col_left,
    output reg [ADDR_BITS-1:0] col_right,
    output reg [ADDR_BITS-1:0] row_top,
    output reg [ADDR_BITS-1:0] row_bot,
    output reg [FRAC_BITS-1:0] frac_x,
    output reg [FRAC_BITS-1:0] frac_y,
    output reg                 s1_valid,
    output reg [1:0]           row_top_mod3,
    output reg [1:0]           row_bot_mod3
);

    localparam SCALE_X = (SRC_W << FRAC_BITS) / DST_W;
    localparam SCALE_Y = (SRC_H << FRAC_BITS) / DST_H;

    reg [ADDR_BITS+FRAC_BITS-1:0] x_total;
    reg [ADDR_BITS+FRAC_BITS-1:0] y_total;
    reg [ADDR_BITS-1:0]           x_out;
    reg [ADDR_BITS-1:0]           y_out;
    reg                           active;

    reg [1:0] src_row_mod3;

    // ── Combinational coordinate decode ──────────────────────────
    wire [ADDR_BITS-1:0] col_left_next  = x_total[ADDR_BITS+FRAC_BITS-1 : FRAC_BITS];
    wire [ADDR_BITS-1:0] col_right_next = (col_left_next == SRC_W-1)? col_left_next: col_left_next + 1'b1;
    wire [ADDR_BITS-1:0] row_top_next   = y_total[ADDR_BITS+FRAC_BITS-1 : FRAC_BITS];
    wire [ADDR_BITS-1:0] row_bot_next   = (row_top_next == SRC_H-1)? row_top_next: row_top_next + 1'b1;
    wire [FRAC_BITS-1:0] frac_x_next    = x_total[FRAC_BITS-1:0];
    wire [FRAC_BITS-1:0] frac_y_next    = y_total[FRAC_BITS-1:0];
    assign row_done = (row_top_next != row_top);

    // Computed directly from the actual next row number (not incrementally
    // from the old tag via +1). The old code assumed row_top/row_bot always
    // advance by exactly 1 per dest row, which silently desyncs the moment
    // a row gets skipped — which happens under any non-integer height
    // downscale ratio. Deriving mod3 directly from row_top_next/row_bot_next
    // is correct for any jump size.
    wire [1:0] row_top_mod3_next = row_top_next % 3;
    wire [1:0] row_bot_mod3_next = row_bot_next % 3;

    always @(posedge clk) begin
        if (rst) begin
            active       <= 1'b0;
            s1_valid     <= 1'b0;
            x_out        <= 0;
            y_out        <= 0;
            x_total      <= 0;
            y_total      <= 0;
            col_left     <= 0;
            col_right    <= 0;
            row_top      <= 0;
            row_bot      <= 0;
            frac_x       <= 0;
            frac_y       <= 0;
            row_top_mod3 <= 2'd0;
            row_bot_mod3 <= 2'd0;

        end
        else if (start) begin
            active       <= 1'b1;
            s1_valid     <= 1'b0;
            x_out        <= 0;
            y_out        <= 0;
            x_total      <= 0;
            y_total      <= 0;

            // Must stay consistent with row_top/row_bot below — stage2's
            // row-identity match checks these before the first s1_ready
            // ever fires, so they can't lag behind.
            col_left     <= 0;
            col_right    <= (SRC_W > 1) ? 1'b1 : 1'b0;
            row_top      <= 0;
            row_bot      <= (SRC_H > 1) ? 1'b1 : 1'b0;

            row_top_mod3 <= 0;
            row_bot_mod3 <= (SRC_H > 1) ? 2'd1 : 2'd0;
        end
        else if (active) begin
            if(s1_ready) begin
                col_left     <= col_left_next;
                col_right    <= col_right_next;
                row_top      <= row_top_next;
                row_bot      <= row_bot_next;
                frac_x       <= frac_x_next;
                frac_y       <= frac_y_next;
                s1_valid     <= 1'b1;
            end

            if (s1_ready && row_done) begin
                row_top_mod3 <= row_top_mod3_next;
                row_bot_mod3 <= row_bot_mod3_next;
            end


            if (s1_ready) begin
                if (x_out == DST_W - 1) begin
                    x_out   <= 0;
                    x_total <= 0;
                    if (y_out == DST_H - 1) begin
                        active   <= 1'b0;
                        // NOTE: s1_valid is intentionally left alone here.
                        // It was already set <= 1'b1 above for THIS (final)
                        // pixel earlier in this same always block; since
                        // both were NBAs to the same reg on the same edge,
                        // writing s1_valid <= 1'b0 here used to silently
                        // win and drop the last pixel of every frame.
                        // active going low next cycle naturally stops the
                        // (active) branch from firing again, which drives
                        // s1_valid back to 0 on the cycle after this one.
                    end
                    else begin
                        y_out   <= y_out + 1'b1;
                        y_total <= y_total + SCALE_Y;
                    end
                end
                else begin
                    x_out   <= x_out + 1'b1;
                    x_total <= x_total + SCALE_X;
                end
            end
        end
        else begin
            // Idle (rst=0, start=0, active=0): the cycle right after the
            // final pixel's s1_valid<=1 was issued lands here. Drop it
            // now so s1_valid doesn't latch high forever with no `active`
            // branch left to ever clear it.
            s1_valid <= 1'b0;
        end
    end

endmodule