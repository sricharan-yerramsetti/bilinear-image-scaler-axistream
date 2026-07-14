module input_image #(
    parameter NUM_CH = 1,
    parameter CH_W = 8,
    parameter SRC_W = 1920,
    parameter SRC_H = 1080
)(
    input clk,
    input rst,
    output wire [NUM_CH*CH_W-1:0] m_axis_tdata,
    output wire m_axis_tvalid,
    output wire m_axis_tlast,
    input  wire m_axis_tready
);

localparam ABITS = $clog2(SRC_W*SRC_H);
localparam RBITS = $clog2(SRC_W);

assign m_axis_tvalid = 1'b1;

reg [NUM_CH*CH_W-1:0] input_mem [0:SRC_W*SRC_H-1];
reg [ABITS-1:0] addr;
reg [RBITS-1:0] col_cnt;   
assign m_axis_tdata = input_mem[addr];
assign m_axis_tlast = (col_cnt == SRC_W - 1);

always @(posedge clk) begin
    if (rst) begin
        addr <= 0;
        col_cnt <= 0;
    end
    else if (m_axis_tready) begin
        addr <= (addr == SRC_W*SRC_H - 1) ? 0 : addr + 1'b1;
        col_cnt <= (col_cnt == SRC_W - 1) ? 0 : col_cnt + 1'b1;
    end
end

endmodule
