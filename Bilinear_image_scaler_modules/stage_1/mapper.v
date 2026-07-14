module stage1 #(
    parameter SRC_W = 1920,
    parameter SRC_H = 1080,
    parameter DST_W = 1280,
    parameter DST_H = 720,
    parameter ADDR_BITS = 11,
    parameter FRAC_BITS = 8
)(
    input  clk,
    input  rst,
    input  start,
    input  s1_ready,
    output row_done,
    output reg [ADDR_BITS-1:0] col_left,
    output reg [ADDR_BITS-1:0] col_right,
    output reg [ADDR_BITS-1:0] row_top,
    output reg [ADDR_BITS-1:0] row_bot,
    output reg [FRAC_BITS-1:0] frac_x,
    output reg [FRAC_BITS-1:0] frac_y,
    output reg s1_valid,
    output reg [1:0] row_top_mod3,
    output reg [1:0] row_bot_mod3
);

    localparam SCALE_X = (SRC_W << FRAC_BITS) / DST_W;
    localparam SCALE_Y = (SRC_H << FRAC_BITS) / DST_H;

    reg [ADDR_BITS+FRAC_BITS-1:0] x_total;
    reg [ADDR_BITS+FRAC_BITS-1:0] y_total;
    reg [ADDR_BITS-1:0] x_out;
    reg [ADDR_BITS-1:0] y_out;
    reg active;

    reg [1:0] src_row_mod3;

    // ── Combinational coordinate decode ──────────────────────────
    wire [ADDR_BITS-1:0] col_left_next  = x_total[ADDR_BITS+FRAC_BITS-1 : FRAC_BITS];
    wire [ADDR_BITS-1:0] col_right_next = (col_left_next == SRC_W-1)? col_left_next: col_left_next + 1'b1;
    wire [ADDR_BITS-1:0] row_top_next = y_total[ADDR_BITS+FRAC_BITS-1 : FRAC_BITS];
    wire [ADDR_BITS-1:0] row_bot_next = (row_top_next == SRC_H-1)? row_top_next: row_top_next + 1'b1;
    wire [FRAC_BITS-1:0] frac_x_next = x_total[FRAC_BITS-1:0];
    wire [FRAC_BITS-1:0] frac_y_next = y_total[FRAC_BITS-1:0];
    assign row_done = (row_top_next != row_top);
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

            s1_valid <= 1'b0;
        end
    end

endmodule
