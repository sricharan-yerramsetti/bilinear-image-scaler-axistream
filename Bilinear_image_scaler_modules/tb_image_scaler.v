`timescale 1ns/1ps

module tb_top;

    localparam NUM_CH = 1;
    localparam CH_W = 8;
    localparam SRC_W = 480;
    localparam SRC_H = 451;
    localparam DST_W = 960;
    localparam DST_H = 500;
    localparam FRAC_BITS = 8;
    localparam ADDR_BITS = 11;

    reg clk = 0;
    reg rst = 1;
    reg start = 0;

    always #5 clk = ~clk;

    // ── source -> dut -> sink AXI-Stream wires ──────────────────
    wire [NUM_CH*CH_W-1:0] src_tdata;
    wire src_tvalid;
    wire src_tlast;
    wire src_tready;
    wire [NUM_CH*CH_W-1:0] dst_tdata;
    wire dst_tvalid;
    wire dst_tlast;
    wire dst_tready;

    input_image #(
        .NUM_CH(NUM_CH),
        .CH_W(CH_W),
        .SRC_W(SRC_W),
        .SRC_H(SRC_H)
    ) u_input_image (
        .clk(clk), .rst(rst),
        .m_axis_tdata (src_tdata),
        .m_axis_tvalid(src_tvalid),
        .m_axis_tlast (src_tlast),
        .m_axis_tready(src_tready)
    );

    scaler_top #(
        .NUM_CH(NUM_CH),
        .CH_W(CH_W),
        .SRC_W(SRC_W),
        .SRC_H(SRC_H),
        .DST_W(DST_W),
        .DST_H(DST_H),
        .FRAC_BITS(FRAC_BITS),
        .ADDR_BITS(ADDR_BITS)
    ) dut (
        .clk(clk), .rst(rst), .start(start),
        .s_axis_tdata (src_tdata),
        .s_axis_tvalid(src_tvalid),
        .s_axis_tlast (src_tlast),
        .s_axis_tready(src_tready),
        .m_axis_tdata (dst_tdata),
        .m_axis_tvalid(dst_tvalid),
        .m_axis_tlast (dst_tlast),
        .m_axis_tready(dst_tready)
    );

    output_image #(
        .NUM_CH(NUM_CH),
        .CH_W(CH_W),
        .DST_W(DST_W),
        .DST_H(DST_H)
    ) u_output_image (
        .clk(clk), .rst(rst),
        .s_axis_tdata (dst_tdata),
        .s_axis_tvalid(dst_tvalid),
        .s_axis_tlast (dst_tlast),
        .s_axis_tready(dst_tready)
    );

    // ── preload source frame from your real image ───────────────
    initial begin
        $readmemh("input.hex", u_input_image.input_mem);
    end

    // ── plain hex dump: one value per line, no comments/markers ─
    integer k, fd;
    task dump_output_hex;
        begin
            fd = $fopen("output.hex", "w");
            for (k = 0; k < DST_W*DST_H; k = k + 1)
                $fdisplay(fd, "%0h", u_output_image.output_mem[k]);
            $fclose(fd);
        end
    endtask

    integer in_cnt = 0;
    integer out_cnt = 0;
    always @(posedge clk) begin
        if (!rst && src_tvalid && src_tready)
            in_cnt <= in_cnt + 1;
        if (!rst && dst_tvalid && dst_tready)
            out_cnt <= out_cnt + 1;
    end

    // ── stimulus ─────────────────────────────────────────────────
    initial begin
        rst   = 1;
        start = 0;
        repeat (5) @(posedge clk);
        rst = 0;
        repeat (2) @(posedge clk);
        start = 1;
        @(posedge clk);
        start = 0;
    end

    // ── waveform dump ────────────────────────────────────────────
    initial begin
        $dumpfile("waves.vcd");
        $dumpvars(0, tb_top);
    end

    // ── row-level log only (NOT per-pixel) ───────────────────────
    // Fires only on: a source row finishing its write (wr_row_last),
    // stage1 finishing a dest row (row_done), or bram_valid changing.
    // This keeps the log to ~1 line per row instead of 1 per pixel.
    wire wr_fire     = dut.stage2_inst.wr_fire;
    wire wr_row_last = dut.stage2_inst.wr_row_last;

    reg bram_valid_prev0, bram_valid_prev1, bram_valid_prev2;
    always @(posedge clk) begin
        if (rst) begin
            bram_valid_prev0 <= 0; bram_valid_prev1 <= 0; bram_valid_prev2 <= 0;
        end else begin
            if (wr_row_last)
                $display("%8t WR_ROW_DONE  wr_row=%4d -> slot=%0d  in_cnt=%6d",
                    $time, dut.stage2_inst.wr_row, dut.stage2_inst.wr_slot, in_cnt);

            if (dut.s1_ready && dut.row_done)
                $display("%8t ROW_DONE=1   row_top=%4d row_bot=%4d  out_cnt=%6d",
                    $time, dut.row_top, dut.row_bot, out_cnt);

            if (dut.stage2_inst.bram_valid[0] !== bram_valid_prev0)
                $display("%8t bram_valid[0] -> %b", $time, dut.stage2_inst.bram_valid[0]);
            if (dut.stage2_inst.bram_valid[1] !== bram_valid_prev1)
                $display("%8t bram_valid[1] -> %b", $time, dut.stage2_inst.bram_valid[1]);
            if (dut.stage2_inst.bram_valid[2] !== bram_valid_prev2)
                $display("%8t bram_valid[2] -> %b", $time, dut.stage2_inst.bram_valid[2]);

            bram_valid_prev0 <= dut.stage2_inst.bram_valid[0];
            bram_valid_prev1 <= dut.stage2_inst.bram_valid[1];
            bram_valid_prev2 <= dut.stage2_inst.bram_valid[2];
        end
    end

    // ── stall detector: flags if NEITHER input nor output moves
    //    for many cycles in a row -> tells you it's stuck, and when ──
    integer stall_cycles = 0;
    always @(posedge clk) begin
        if (!rst) begin
            if ((src_tvalid && src_tready) || (dst_tvalid && dst_tready))
                stall_cycles <= 0;
            else
                stall_cycles <= stall_cycles + 1;

            if (stall_cycles == 200)
                $display(">>> STALL DETECTED at time %0t: no input or output handshake for 200 cycles. in_cnt=%0d out_cnt=%0d s1_valid=%b s1_ready=%b s2_valid=%b s2_ready=%b s3_valid=%b s3_ready=%b m_valid=%b m_ready=%b",
                    $time, in_cnt, out_cnt,
                    dut.s1_valid, dut.s1_ready, dut.s2_valid, dut.s2_ready,
                    dut.s3_valid, dut.s3_ready, dst_tvalid, dst_tready);
        end
    end

    // ── progress heartbeat ───────────────────────────────────────
    always @(posedge clk)
        if (!rst && out_cnt != 0 && out_cnt % 50000 == 0 && dst_tvalid && dst_tready)
            $display("[%0t] out_cnt=%0d wr_slot=%0d wr_col=%0d", $time, out_cnt,
                dut.stage2_inst.wr_slot, dut.stage2_inst.wr_col);

    // ── finish once full destination frame has been produced ───
    initial begin
        wait (out_cnt == DST_W*DST_H);
        repeat (5) @(posedge clk);
        $display("PASS: received %0d pixels (%0dx%0d)", out_cnt, DST_W, DST_H);
        dump_output_hex;
        $display("Sample TL pixel  out[0]      = %0d", u_output_image.output_mem[0]);
        $display("Sample mid pixel out[%0d] = %0d", (DST_H/2)*DST_W + DST_W/2,
                  u_output_image.output_mem[(DST_H/2)*DST_W + DST_W/2]);
        $finish;
    end

    // ── watchdog ────────────────────────────────────────────────
    initial begin
        #200_000_00;
        $display("TIMEOUT: only %0d/%0d pixels received", out_cnt, DST_W*DST_H);
        dump_output_hex;
        $finish;
    end

endmodule
