module stage4 #(
    parameter NUM_CH = 1,
    parameter CH_W = 8,
    parameter FRAC_BITS = 8,
    parameter DST_W = 1280,
    parameter DST_H = 720,
    parameter ADDR_BITS = 11
)(
    input clk,
    input rst,
    input s3_valid,
    input [NUM_CH*CH_W-1:0] top_interp,
    input [NUM_CH*CH_W-1:0] bot_interp,
    input [FRAC_BITS-1:0] s3_frac_y,

    output s3_ready,

    output reg [NUM_CH*CH_W-1:0] m_axis_tdata,
    output reg m_axis_tvalid,
    input m_axis_tready,
    output reg m_axis_tlast
);

reg [ADDR_BITS-1:0] x_cnt;
reg [ADDR_BITS-1:0] y_cnt;

wire [NUM_CH*CH_W-1:0] interleaved_pixel;

genvar ch;
generate
for(ch=0; ch<NUM_CH; ch=ch+1)
begin : VERT_CH

    wire [CH_W-1:0] top_ch = top_interp[ch*CH_W +: CH_W];
    wire [CH_W-1:0] bot_ch = bot_interp[ch*CH_W +: CH_W];
    wire signed [CH_W:0] diff_v = $signed({1'b0,bot_ch})- $signed({1'b0,top_ch});
    wire signed [FRAC_BITS+CH_W:0] vert_delta = $signed({1'b0,s3_frac_y})* diff_v;
    wire signed [CH_W:0] vert_corr = vert_delta >>> FRAC_BITS;
    wire [CH_W-1:0] out_ch = top_ch + vert_corr;
    assign interleaved_pixel[ch*CH_W +: CH_W] = out_ch;

end
endgenerate

assign s3_ready = (!m_axis_tvalid) ||  m_axis_tready;

always @(posedge clk)
begin
    if(rst)
    begin
        m_axis_tdata  <= 0;
        m_axis_tvalid <= 0;
        m_axis_tlast  <= 0;

        x_cnt <= 0;
        y_cnt <= 0;
    end
    else if(s3_ready)
    begin
        if(s3_valid) begin
            m_axis_tdata  <= interleaved_pixel;
            m_axis_tvalid <= 1'b1;
            m_axis_tlast <= (x_cnt == DST_W-1);

            if(x_cnt == DST_W-1) begin
                x_cnt <= 0;

                if(y_cnt == DST_H-1) begin
                    y_cnt <= 0;
                end
                else begin
                    y_cnt <= y_cnt + 1'b1;
                end
            end
            else begin
                x_cnt <= x_cnt + 1'b1;
            end
        end
        else begin
            m_axis_tvalid <= 0;
            m_axis_tlast  <= 0;
        end
    end
end

endmodule
