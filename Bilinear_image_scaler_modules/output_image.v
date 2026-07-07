module output_image #(
    parameter NUM_CH = 1,
    parameter CH_W   = 8,
    parameter DST_W  = 1280,
    parameter DST_H  = 720
)(
    input clk,
    input rst,
    input  wire [NUM_CH*CH_W-1:0] s_axis_tdata,
    input  wire s_axis_tvalid,
    input  wire s_axis_tlast,
    output wire s_axis_tready
);

localparam ABITS     = $clog2(DST_W*DST_H);
localparam TOTAL_PIX = DST_W * DST_H;

assign s_axis_tready = 1'b1;

reg [NUM_CH*CH_W-1:0] output_mem [0:TOTAL_PIX-1];
reg [ABITS-1:0] addr;

always @(posedge clk) begin
    if (rst) begin
        addr <= 0;
    end else if (s_axis_tvalid) begin
        output_mem[addr] <= s_axis_tdata;
        addr <= (addr == TOTAL_PIX - 1) ? 0 : addr + 1;
    end
end

endmodule