module scaler_top #(
    parameter NUM_CH = 1,
    parameter CH_W = 8,
    parameter SRC_W = 1920,
    parameter SRC_H = 1080,
    parameter DST_W = 1280,
    parameter DST_H = 720,
    parameter FRAC_BITS = 8,
    parameter ADDR_BITS = 11
)(
    input clk,
    input rst,
    input start,
    input[NUM_CH*CH_W-1:0] s_axis_tdata,
    input s_axis_tvalid,
    input s_axis_tlast,
    output s_axis_tready,
    output[NUM_CH*CH_W-1:0] m_axis_tdata,
    output m_axis_tvalid,
    output m_axis_tlast,
    input m_axis_tready
);

    wire  s1_valid;
    wire s1_ready;
    wire row_done;
    wire[ADDR_BITS-1:0] col_left,  col_right;
    wire[ADDR_BITS-1:0] row_top,   row_bot;
    wire[1:0] row_top_mod3, row_bot_mod3;
    wire[FRAC_BITS-1:0] frac_x,    frac_y;
    wire s2_valid;
    wire s2_ready;
    wire[NUM_CH*CH_W-1:0] TL, TR, BL, BR;
    wire[FRAC_BITS-1:0] s2_frac_x, s2_frac_y;
    wire s3_valid;
    wire s3_ready;
    wire [NUM_CH*CH_W-1:0]  top_interp, bot_interp;
    wire [FRAC_BITS-1:0]    s3_frac_y;
    
    stage1 #(
        .SRC_W(SRC_W),
        .SRC_H(SRC_H),
        .DST_W(DST_W),
        .DST_H(DST_H),
        .ADDR_BITS(ADDR_BITS),
        .FRAC_BITS(FRAC_BITS)
    ) stage1_inst (
        .clk(clk),
        .rst(rst),
        .start(start),
        .s1_ready(s1_ready),
        .row_done(row_done),
        .col_left(col_left),
        .col_right(col_right),
        .row_top(row_top),
        .row_bot(row_bot),
        .frac_x(frac_x),
        .frac_y(frac_y),
        .s1_valid(s1_valid),
        .row_top_mod3(row_top_mod3),
        .row_bot_mod3(row_bot_mod3)
    );

    stage2 #(
        .NUM_CH(NUM_CH),
        .CH_W(CH_W),
        .SRC_W(SRC_W),
        .SRC_H(SRC_H),
        .DST_W(DST_W),
        .FRAC_BITS(FRAC_BITS),
        .ADDR_BITS(ADDR_BITS)
    ) stage2_inst (
        .clk(clk),
        .rst(rst),
        .s1_valid(s1_valid),
        .col_left(col_left),
        .col_right(col_right),
        .row_top(row_top),
        .row_bot(row_bot),
        .row_top_mod3(row_top_mod3),
        .row_bot_mod3(row_bot_mod3),
        .frac_x(frac_x),
        .frac_y(frac_y),
        .row_done(row_done),
        .s1_ready(s1_ready),
        .s_axis_tdata(s_axis_tdata),
        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tlast(s_axis_tlast),
        .s_axis_tready(s_axis_tready),
        .s2_valid(s2_valid),
        .TL(TL),
        .TR(TR),
        .BL(BL),
        .BR(BR),
        .s2_frac_x(s2_frac_x),
        .s2_frac_y(s2_frac_y),
        .s2_ready(s2_ready)
    );

    stage3 #(
        .NUM_CH(NUM_CH),
        .CH_W(CH_W),
        .FRAC_BITS(FRAC_BITS)
    ) stage3_inst (
        .clk(clk),
        .rst(rst),
        .s2_valid(s2_valid),
        .TL(TL),
        .TR(TR),
        .BL(BL),
        .BR(BR),
        .s2_frac_x(s2_frac_x),
        .s2_frac_y(s2_frac_y),
        .s2_ready(s2_ready),
        .s3_ready(s3_ready),
        .s3_valid(s3_valid),
        .top_interp(top_interp),
        .bot_interp(bot_interp),
        .s3_frac_y(s3_frac_y)
    );

    stage4 #(
        .NUM_CH(NUM_CH),
        .CH_W(CH_W),
        .FRAC_BITS(FRAC_BITS),
        .DST_W(DST_W),
        .DST_H(DST_H),
        .ADDR_BITS(ADDR_BITS)
    ) stage4_inst (
        .clk(clk),
        .rst(rst),
        .s3_valid(s3_valid),
        .top_interp(top_interp),
        .bot_interp(bot_interp),
        .s3_frac_y(s3_frac_y),
        .s3_ready(s3_ready),
        .m_axis_tdata(m_axis_tdata),
        .m_axis_tvalid(m_axis_tvalid),
        .m_axis_tready(m_axis_tready),
        .m_axis_tlast(m_axis_tlast)
    );

endmodule
