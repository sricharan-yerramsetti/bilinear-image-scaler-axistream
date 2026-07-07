// module input_image #(
//     parameter NUM_CH = 1,
//     parameter CH_W   = 8,
//     parameter SRC_W  = 1920,
//     parameter SRC_H  = 1080
// )(
//     input  clk,
//     input  rst,
//     output reg [NUM_CH*CH_W-1:0] m_axis_tdata,
//     output wire                  m_axis_tvalid,
//     output reg                   m_axis_tlast,
//     input  wire                  m_axis_tready
// );

// localparam ABITS = $clog2(SRC_W*SRC_H);
// localparam RBITS = $clog2(SRC_W);

// // tvalid is always 1 — this is an infinite-ready memory source.
// // The consumer (stage2) gates flow via tready.
// assign m_axis_tvalid = 1'b1;

// reg [NUM_CH*CH_W-1:0] input_mem [0:SRC_W*SRC_H-1];
// reg [ABITS-1:0] addr;

// // NOTE: $readmemh is called from the testbench AFTER input.hex is written,
// // so input_mem is pre-loaded before simulation begins advancing.
// // (see tb_top.v — we do NOT call $readmemh here; the TB does it via
// //  $readmemh on the path dut.u_input_image.input_mem)

// always @(posedge clk) begin
//     if (rst) begin
//         addr         <= 0;
//         m_axis_tdata <= 0;
//         m_axis_tlast <= 1'b0;
//     end 
//     else if (m_axis_tready) begin
//         // Present pixel at current addr this cycle; advance to next.
//         m_axis_tdata <= input_mem[addr];
//         m_axis_tlast <= (addr[RBITS-1:0] == SRC_W - 1);
//         addr         <= (addr == SRC_W*SRC_H - 1) ? 0 : addr + 1'b1;
//     end
// end

// endmodule
// module input_image #(
//     parameter NUM_CH = 1,
//     parameter CH_W   = 8,
//     parameter SRC_W  = 1920,
//     parameter SRC_H  = 1080
// )(
//     input  clk,
//     input  rst,
//     output wire [NUM_CH*CH_W-1:0] m_axis_tdata,
//     output wire                  m_axis_tvalid,
//     output wire                   m_axis_tlast,
//     input  wire                  m_axis_tready
// );

// localparam ABITS = $clog2(SRC_W*SRC_H);
// localparam RBITS = $clog2(SRC_W);

// // tvalid is always 1 — this is an infinite-ready memory source.
// // The consumer (stage2) gates flow via tready.
// assign m_axis_tvalid = 1'b1;

// reg [NUM_CH*CH_W-1:0] input_mem [0:SRC_W*SRC_H-1];
// reg [ABITS-1:0] addr;

// // NOTE: $readmemh is called from the testbench AFTER input.hex is written,
// // so input_mem is pre-loaded before simulation begins advancing.
// // (see tb_top.v — we do NOT call $readmemh here; the TB does it via
// //  $readmemh on the path dut.u_input_image.input_mem)

// // FIX: tdata/tlast used to be registered outputs of input_mem[addr],
// // lagging "addr" by one clock cycle -- but tvalid was hardwired to 1
// // starting immediately at reset deassertion, with no allowance for
// // that lag. Result: the very first accepted beat transmitted the
// // reset value (0) instead of input_mem[0], shifting every pixel in
// // the frame by one position (wrong pixel 0, and the last real pixel
// // of the frame never gets sent -> one-short at the end). Making
// // tdata/tlast combinational reads of the CURRENT addr removes the
// // extra register stage entirely, so what's presented always matches
// // what "addr" currently points to -- no lag, no dummy first beat.
// assign m_axis_tdata = input_mem[addr];
// assign m_axis_tlast = (addr[RBITS-1:0] == SRC_W - 1);

// always @(posedge clk) begin
//     if (rst) begin
//         addr <= 0;
//     end
//     else if (m_axis_tready) begin
//         addr <= (addr == SRC_W*SRC_H - 1) ? 0 : addr + 1'b1;
//     end
// end
// // input_image.v
// reg done;
// always @(posedge clk) begin
//     if (rst) done <= 0;
//     else if (m_axis_tready && addr == SRC_W*SRC_H-1) done <= 1;
// end
// assign m_axis_tvalid = !done;
// endmodule
module input_image #(
    parameter NUM_CH = 1,
    parameter CH_W   = 8,
    parameter SRC_W  = 1920,
    parameter SRC_H  = 1080
)(
    input  clk,
    input  rst,
    output wire [NUM_CH*CH_W-1:0] m_axis_tdata,
    output wire                   m_axis_tvalid,
    output wire                   m_axis_tlast,
    input  wire                   m_axis_tready
);

localparam ABITS = $clog2(SRC_W*SRC_H);
localparam RBITS = $clog2(SRC_W);

// tvalid is always 1 -- infinite-ready memory source, consumer gates via tready.
// Single driver only (previous version had a second conflicting
// `assign m_axis_tvalid = !done` further down -> driver contention / x).
assign m_axis_tvalid = 1'b1;

reg [NUM_CH*CH_W-1:0] input_mem [0:SRC_W*SRC_H-1];
reg [ABITS-1:0] addr;
reg [RBITS-1:0] col_cnt;   // dedicated column counter, wraps exactly at SRC_W.
                           // addr[RBITS-1:0] alone is WRONG whenever SRC_W is
                           // not a power of two (e.g. 480 -> RBITS=9 -> wraps
                           // at 512, drifting tlast by 32 pixels every row).

// Combinational read: tdata/tlast always reflect the CURRENT addr/col_cnt,
// so there's no extra register-stage lag between what "addr" points to
// and what's presented on the bus this cycle.
assign m_axis_tdata = input_mem[addr];
assign m_axis_tlast = (col_cnt == SRC_W - 1);

always @(posedge clk) begin
    if (rst) begin
        addr    <= 0;
        col_cnt <= 0;
    end
    else if (m_axis_tready) begin
        addr    <= (addr == SRC_W*SRC_H - 1) ? 0 : addr + 1'b1;
        col_cnt <= (col_cnt == SRC_W - 1) ? 0 : col_cnt + 1'b1;
    end
end

endmodule