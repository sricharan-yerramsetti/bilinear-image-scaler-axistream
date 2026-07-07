module stage3 #(
    parameter NUM_CH    = 1,
    parameter CH_W      = 8,
    parameter FRAC_BITS = 8
)(
    input  clk,
    input  rst,

    input                        s2_valid,
    input  [NUM_CH*CH_W-1:0]     TL,
    input  [NUM_CH*CH_W-1:0]     TR,
    input  [NUM_CH*CH_W-1:0]     BL,
    input  [NUM_CH*CH_W-1:0]     BR,
    input  [FRAC_BITS-1:0]       s2_frac_x,
    input  [FRAC_BITS-1:0]       s2_frac_y,

    output                       s2_ready,
    input                        s3_ready,

    output reg                   s3_valid,
    output reg [NUM_CH*CH_W-1:0] top_interp,
    output reg [NUM_CH*CH_W-1:0] bot_interp,
    output reg [FRAC_BITS-1:0]   s3_frac_y
);

assign s2_ready = s3_ready;

genvar ch;
generate
for(ch=0; ch<NUM_CH; ch=ch+1) begin : CHANNEL

    wire [CH_W-1:0] tl_ch = TL[ch*CH_W +: CH_W];

    wire [CH_W-1:0] tr_ch = TR[ch*CH_W +: CH_W];

    wire [CH_W-1:0] bl_ch = BL[ch*CH_W +: CH_W];

    wire [CH_W-1:0] br_ch = BR[ch*CH_W +: CH_W];

    wire signed [CH_W:0] diff_top = $signed({1'b0,tr_ch}) - $signed({1'b0,tl_ch});

    wire signed [CH_W:0] diff_bot = $signed({1'b0,br_ch}) - $signed({1'b0,bl_ch});

    wire signed [FRAC_BITS+CH_W:0] top_delta = $signed({1'b0,s2_frac_x}) * diff_top;

    wire signed [FRAC_BITS+CH_W:0] bot_delta = $signed({1'b0,s2_frac_x}) * diff_bot;

    wire signed [CH_W:0] top_corr = top_delta >>> FRAC_BITS;

    wire signed [CH_W:0] bot_corr = bot_delta >>> FRAC_BITS;

    wire [CH_W-1:0] top_ch = tl_ch + top_corr;

    wire [CH_W-1:0] bot_ch = bl_ch + bot_corr;

    always @(posedge clk)
    begin
        if(rst)
        begin
            top_interp[ch*CH_W +: CH_W] <= 0;
            bot_interp[ch*CH_W +: CH_W] <= 0;
        end
        else if(s3_ready)
        begin
            top_interp[ch*CH_W +: CH_W]
                <= top_ch;

            bot_interp[ch*CH_W +: CH_W]
                <= bot_ch;
        end
    end

end
endgenerate

always @(posedge clk)
begin
    if(rst)
    begin
        s3_valid  <= 0;
        s3_frac_y <= 0;
    end
    else if(s3_ready)
    begin
        s3_valid  <= s2_valid;
        s3_frac_y <= s2_frac_y;
    end
end

endmodule