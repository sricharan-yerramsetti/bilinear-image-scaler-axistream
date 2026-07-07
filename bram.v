module bram #(
    parameter NUM_CH    = 1,
    parameter CH_W      = 8,
    parameter SRC_W     = 1920,
    parameter SRC_H     = 1080,
    parameter ADDR_BITS = 11
)(
    input                         clk,
    input                         rd_en,
    input  [ADDR_BITS-2:0]        rd_addr,
    input  [NUM_CH*CH_W-1:0]      write_data,
    input  [ADDR_BITS-2:0]        write_addr,
    input                         wr_en,
    output reg [NUM_CH*CH_W-1:0]  pixel_data
);

reg [NUM_CH*CH_W-1:0] bram_mem [0:(SRC_W >> 1) - 1];

always @(posedge clk) begin
    if (rd_en)
        pixel_data <= bram_mem[rd_addr];
    if (wr_en)
        bram_mem[write_addr] <= write_data;
end

endmodule