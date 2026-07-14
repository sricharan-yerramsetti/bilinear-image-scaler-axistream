module stage2 #(
    parameter NUM_CH = 1,
    parameter CH_W = 8,
    parameter SRC_W = 1920,
    parameter SRC_H = 1080,
    parameter DST_W = 1280,
    parameter FRAC_BITS = 8,
    parameter ADDR_BITS = 11
)(
    input  clk,
    input  rst,
    input s1_valid,
    input[ADDR_BITS-1:0] col_left,
    input[ADDR_BITS-1:0] col_right,
    input[ADDR_BITS-1:0] row_top,
    input[ADDR_BITS-1:0] row_bot,
    input[1:0] row_top_mod3,
    input[1:0] row_bot_mod3,
    input[FRAC_BITS-1:0] frac_x,
    input[FRAC_BITS-1:0] frac_y,
    input row_done,
    output s1_ready,
    input[NUM_CH*CH_W-1:0] s_axis_tdata,
    input s_axis_tvalid,
    input s_axis_tlast,
    output wire s_axis_tready,
    output reg s2_valid,
    output[NUM_CH*CH_W-1:0] TL,TR,
    output[NUM_CH*CH_W-1:0] BL,BR,
    output reg [FRAC_BITS-1:0] s2_frac_x,
    output reg [FRAC_BITS-1:0] s2_frac_y,
    input s2_ready
);

// ────────────────────────────────────────────────────────────
localparam DW = NUM_CH * CH_W;
localparam COL_BITS = $clog2(SRC_W);

reg  bram_valid[0:2];
reg  [ADDR_BITS-1:0] bram_row[0:2];   // absolute source row currently held by each slot
wire rd_en[0:2];
wire [ADDR_BITS-2:0] rd_addr[0:1];
wire [NUM_CH*CH_W-1:0] pixel_data[0:5];   // BRAM outputs -> wire, correct width
reg [2:0] sel[0:3];

wire top_match = bram_valid[row_top_mod3] && (bram_row[row_top_mod3] == row_top);
wire bot_match = bram_valid[row_bot_mod3] && (bram_row[row_bot_mod3] == row_bot);

assign rd_en[0] =  (s1_valid)&&((row_top_mod3 == 0)||(row_bot_mod3 == 0));
assign rd_en[1] =  (s1_valid)&&((row_top_mod3 == 1)||(row_bot_mod3 == 1));
assign rd_en[2] =  (s1_valid)&&((row_top_mod3 == 2)||(row_bot_mod3 == 2));
assign rd_addr[0] = (col_left != col_right) ? ((col_left[0] == 0) ? (col_left[ADDR_BITS - 1 : 1]) : (col_right[ADDR_BITS - 1 : 1])) : col_left[ADDR_BITS - 1 : 1];
assign rd_addr[1] = (col_left != col_right) ? ((col_left[0] == 1) ? (col_left[ADDR_BITS - 1 : 1]) : (col_right[ADDR_BITS - 1 : 1])) : col_left[ADDR_BITS - 1 : 1];
assign TL = pixel_data[sel[0]];
assign TR = pixel_data[sel[1]];
assign BL = pixel_data[sel[2]];
assign BR = pixel_data[sel[3]];


reg [ADDR_BITS-1:0] wr_col;    // column within the row currently being written
reg [1:0] wr_slot;   // (source row being written) % 3
reg [ADDR_BITS-1:0] wr_row;    // absolute source row being written

assign s_axis_tready = (!bram_valid[wr_slot]) || (row_top > bram_row[wr_slot]);
wire wr_fire = s_axis_tvalid && s_axis_tready;
wire wr_row_last  = wr_fire && s_axis_tlast;

wire [ADDR_BITS-2:0] wr_addr = wr_col[ADDR_BITS-1:1];  // col>>1, same convention as rd_addr
wire wr_bank = wr_col[0];               // 0=even bank, 1=odd bank

wire [5:0] wr_en_vec;

assign wr_en_vec[0] = wr_fire && (wr_slot == 2'd0) && (wr_bank == 1'b0); // Slot 0, Bank 0
assign wr_en_vec[1] = wr_fire && (wr_slot == 2'd0) && (wr_bank == 1'b1); // Slot 0, Bank 1
assign wr_en_vec[2] = wr_fire && (wr_slot == 2'd1) && (wr_bank == 1'b0); // Slot 1, Bank 0
assign wr_en_vec[3] = wr_fire && (wr_slot == 2'd1) && (wr_bank == 1'b1); // Slot 1, Bank 1
assign wr_en_vec[4] = wr_fire && (wr_slot == 2'd2) && (wr_bank == 1'b0); // Slot 2, Bank 0
assign wr_en_vec[5] = wr_fire && (wr_slot == 2'd2) && (wr_bank == 1'b1); // Slot 2, Bank 1

always @(posedge clk) begin
    if (rst) begin
        wr_col <= 0;
        wr_slot <= 2'd0;
        wr_row <= 0;
        bram_valid[0] <= 1'b0;
        bram_valid[1] <= 1'b0;
        bram_valid[2] <= 1'b0;
        bram_row[0] <= 0;
        bram_row[1] <= 0;
        bram_row[2] <= 0;
    end

    else if (wr_fire) begin

        if (wr_row_last) begin
            bram_valid[wr_slot] <= 1'b1;
            bram_row[wr_slot]   <= wr_row; 
            wr_col  <= 0;
            wr_slot <= (wr_slot == 2'd2) ? 2'd0 : wr_slot + 1'b1;
            wr_row  <= (wr_row == SRC_H-1) ? 0 : wr_row + 1'b1;
        end

        else begin
            wr_col <= wr_col + 1'b1;
        end
    end
end

bram #(.NUM_CH(NUM_CH), .CH_W(CH_W), .SRC_W(SRC_W), .SRC_H(SRC_H), .ADDR_BITS(ADDR_BITS))
bram_0(.clk(clk), .rd_en(rd_en[0]), .rd_addr(rd_addr[0]),.wr_en(wr_en_vec[0]), .write_data(s_axis_tdata), .write_addr(wr_addr),.pixel_data(pixel_data[0]));

bram #(.NUM_CH(NUM_CH), .CH_W(CH_W), .SRC_W(SRC_W), .SRC_H(SRC_H), .ADDR_BITS(ADDR_BITS))
bram_1(.clk(clk), .rd_en(rd_en[0]), .rd_addr(rd_addr[1]),.wr_en(wr_en_vec[1]), .write_data(s_axis_tdata), .write_addr(wr_addr),.pixel_data(pixel_data[1]));

bram #(.NUM_CH(NUM_CH), .CH_W(CH_W), .SRC_W(SRC_W), .SRC_H(SRC_H), .ADDR_BITS(ADDR_BITS))
bram_2(.clk(clk), .rd_en(rd_en[1]), .rd_addr(rd_addr[0]),.wr_en(wr_en_vec[2]), .write_data(s_axis_tdata), .write_addr(wr_addr),.pixel_data(pixel_data[2]));

bram #(.NUM_CH(NUM_CH), .CH_W(CH_W), .SRC_W(SRC_W), .SRC_H(SRC_H), .ADDR_BITS(ADDR_BITS))
bram_3(.clk(clk), .rd_en(rd_en[1]), .rd_addr(rd_addr[1]),.wr_en(wr_en_vec[3]), .write_data(s_axis_tdata), .write_addr(wr_addr),.pixel_data(pixel_data[3]));

bram #(.NUM_CH(NUM_CH), .CH_W(CH_W), .SRC_W(SRC_W), .SRC_H(SRC_H), .ADDR_BITS(ADDR_BITS))
bram_4(.clk(clk), .rd_en(rd_en[2]), .rd_addr(rd_addr[0]),.wr_en(wr_en_vec[4]), .write_data(s_axis_tdata), .write_addr(wr_addr),.pixel_data(pixel_data[4]));

bram #(.NUM_CH(NUM_CH), .CH_W(CH_W), .SRC_W(SRC_W), .SRC_H(SRC_H), .ADDR_BITS(ADDR_BITS))
bram_5(.clk(clk), .rd_en(rd_en[2]), .rd_addr(rd_addr[1]),.wr_en(wr_en_vec[5]), .write_data(s_axis_tdata), .write_addr(wr_addr),.pixel_data(pixel_data[5]));

always @(posedge clk) begin
    if (rst) begin
        s2_valid  <= 0;
        sel[0] <= 0;
        sel[1] <= 0;
        sel[2] <= 0;
        sel[3] <= 0;
        s2_frac_x <= 0;
        s2_frac_y <= 0;
    end
    else if (s2_ready) begin
        s2_valid <= 0;
        sel[0] <= 0;
        sel[1] <= 0;
        sel[2] <= 0;
        sel[3] <= 0;

        if (col_left != col_right) begin
            case(row_top_mod3)
                2'd0 : begin
                    sel[0] <= (col_left[0]  == 0) ? 0 : 1;
                    sel[1] <= (col_right[0] == 0) ? 0 : 1;
                end
                2'd1 : begin
                    sel[0] <= (col_left[0]  == 0) ? 2 : 3;
                    sel[1] <= (col_right[0] == 0) ? 2 : 3;
                end
                2'd2 : begin
                    sel[0] <= (col_left[0]  == 0) ? 4 : 5;
                    sel[1] <= (col_right[0] == 0) ? 4 : 5;
                end
            endcase

            case(row_bot_mod3)
                2'd0 : begin
                    sel[2] <= (col_left[0]  == 0) ? 0 : 1;
                    sel[3] <= (col_right[0] == 0) ? 0 : 1;
                end
                2'd1 : begin
                    sel[2] <= (col_left[0]  == 0) ? 2 : 3;
                    sel[3] <= (col_right[0] == 0) ? 2 : 3;
                end
                2'd2 : begin
                    sel[2] <= (col_left[0]  == 0) ? 4 : 5;
                    sel[3] <= (col_right[0] == 0) ? 4 : 5;
                end
            endcase

        end
        else begin
            case(row_top_mod3)
                2'd0 : begin
                    sel[0] <= (col_left[0] == 0) ? 0 : 1;
                    sel[1] <= (col_left[0] == 0) ? 0 : 1;
                end
                2'd1 : begin
                    sel[0] <= (col_left[0] == 0) ? 2 : 3;
                    sel[1] <= (col_left[0] == 0) ? 2 : 3;
                end
                2'd2 : begin
                    sel[0] <= (col_left[0] == 0) ? 4 : 5;
                    sel[1] <= (col_left[0] == 0) ? 4 : 5;
                end
            endcase

            case(row_bot_mod3)
                2'd0 : begin
                    sel[2] <= (col_left[0] == 0) ? 0 : 1;
                    sel[3] <= (col_left[0] == 0) ? 0 : 1;
                end
                2'd1 : begin
                    sel[2] <= (col_left[0] == 0) ? 2 : 3;
                    sel[3] <= (col_left[0] == 0) ? 2 : 3;
                end
                2'd2 : begin
                    sel[2] <= (col_left[0] == 0) ? 4 : 5;
                    sel[3] <= (col_left[0] == 0) ? 4 : 5;
                end
            endcase

        end

        s2_valid <= s1_valid && top_match && bot_match;
        s2_frac_x <= frac_x;
        s2_frac_y <= frac_y;
    end
end
    
assign s1_ready = s2_ready && top_match && bot_match;

endmodule
