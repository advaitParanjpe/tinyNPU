`timescale 1ns/1ps

import tinynpu_pkg::*;

module tb_tinynpu_dma_descriptor_wrapper;
  localparam logic [11:0] ADDR_CTRL   = 12'h000;
  localparam logic [11:0] ADDR_STATUS = 12'h004;
  localparam logic [11:0] ADDR_A_BASE = 12'h010;
  localparam logic [11:0] ADDR_B_BASE = 12'h050;
  localparam logic [11:0] ADDR_C_BASE = 12'h090;

  localparam logic [11:0] DMA_CTRL       = 12'h100;
  localparam logic [11:0] DMA_STATUS     = 12'h104;
  localparam logic [11:0] DMA_A_EXT_BASE = 12'h108;
  localparam logic [11:0] DMA_B_EXT_BASE = 12'h10c;
  localparam logic [11:0] DMA_C_EXT_BASE = 12'h110;
  localparam logic [11:0] DMA_CONFIG     = 12'h114;

  logic        pclk;
  logic        presetn;
  logic        psel;
  logic        penable;
  logic        pwrite;
  logic [11:0] paddr;
  logic [31:0] pwdata;
  logic [31:0] prdata;
  logic        pready;
  logic        pslverr;

  int failures;
  int tests_passed;

  tinynpu_dma_descriptor_wrapper dut (
    .pclk    (pclk),
    .presetn (presetn),
    .psel    (psel),
    .penable (penable),
    .pwrite  (pwrite),
    .paddr   (paddr),
    .pwdata  (pwdata),
    .prdata  (prdata),
    .pready  (pready),
    .pslverr (pslverr)
  );

  initial begin
    pclk = 1'b0;
    forever #5 pclk = ~pclk;
  end

  function automatic logic [31:0] pack_i8(input int value);
    begin
      pack_i8 = {{24{value[7]}}, value[7:0]};
    end
  endfunction

  task automatic apb_write(input logic [11:0] addr, input logic [31:0] data);
    begin
      @(negedge pclk);
      psel    <= 1'b1;
      penable <= 1'b0;
      pwrite  <= 1'b1;
      paddr   <= addr;
      pwdata  <= data;
      @(negedge pclk);
      penable <= 1'b1;
      @(posedge pclk);
      while (!pready) begin
        @(posedge pclk);
      end
      if (pslverr !== 1'b0) begin
        $display("FAIL apb_write: pslverr asserted addr=0x%03x", addr);
        failures = failures + 1;
      end
      @(negedge pclk);
      psel    <= 1'b0;
      penable <= 1'b0;
      pwrite  <= 1'b0;
      paddr   <= '0;
      pwdata  <= '0;
    end
  endtask

  task automatic apb_read(input logic [11:0] addr, output logic [31:0] data);
    begin
      @(negedge pclk);
      psel    <= 1'b1;
      penable <= 1'b0;
      pwrite  <= 1'b0;
      paddr   <= addr;
      pwdata  <= '0;
      @(negedge pclk);
      penable <= 1'b1;
      @(posedge pclk);
      while (!pready) begin
        @(posedge pclk);
      end
      if (pslverr !== 1'b0) begin
        $display("FAIL apb_read: pslverr asserted addr=0x%03x", addr);
        failures = failures + 1;
      end
      #1;
      data = prdata;
      @(negedge pclk);
      psel    <= 1'b0;
      penable <= 1'b0;
      paddr   <= '0;
    end
  endtask

  task automatic wait_desc_done;
    logic [31:0] status;
    int timeout;
    begin
      timeout = 0;
      apb_read(DMA_STATUS, status);
      while ((status[1] !== 1'b1) && (timeout < 20)) begin
        timeout = timeout + 1;
        apb_read(DMA_STATUS, status);
      end
      if (status[1] !== 1'b1) begin
        $display("FAIL wait_desc_done: timed out status=0x%08x", status);
        failures = failures + 1;
      end
    end
  endtask

  task automatic wait_core_done;
    logic [31:0] status;
    int timeout;
    begin
      timeout = 0;
      apb_read(ADDR_STATUS, status);
      while ((status[1] !== 1'b1) && (timeout < 200)) begin
        timeout = timeout + 1;
        apb_read(ADDR_STATUS, status);
      end
      if (status[1] !== 1'b1) begin
        $display("FAIL wait_core_done: timed out status=0x%08x", status);
        failures = failures + 1;
      end
    end
  endtask

  task automatic run_desc_regs_read_write;
    int local_failures;
    logic [31:0] data;
    begin
      local_failures = 0;
      apb_write(DMA_A_EXT_BASE, 32'h0000_0010);
      apb_write(DMA_B_EXT_BASE, 32'h0000_0020);
      apb_write(DMA_C_EXT_BASE, 32'h0000_0030);
      apb_write(DMA_CONFIG,     32'h0000_0040);

      apb_read(DMA_A_EXT_BASE, data);
      if (data !== 32'h0000_0010) local_failures = local_failures + 1;
      apb_read(DMA_B_EXT_BASE, data);
      if (data !== 32'h0000_0020) local_failures = local_failures + 1;
      apb_read(DMA_C_EXT_BASE, data);
      if (data !== 32'h0000_0030) local_failures = local_failures + 1;
      apb_read(DMA_CONFIG, data);
      if (data !== 32'h0000_0040) local_failures = local_failures + 1;

      if (local_failures == 0) begin
        tests_passed = tests_passed + 1;
        $display("PASS desc_regs_read_write");
      end else begin
        failures = failures + local_failures;
        $display("FAIL desc_regs_read_write");
      end
    end
  endtask

  task automatic run_desc_start_done_clear;
    int local_failures;
    logic [31:0] status;
    begin
      local_failures = 0;
      apb_write(DMA_CTRL, 32'h1);
      apb_read(DMA_STATUS, status);
      if (status[0] !== 1'b1) begin
        $display("FAIL desc_start_done_clear: busy did not assert status=0x%08x", status);
        local_failures = local_failures + 1;
      end
      wait_desc_done();
      apb_read(DMA_STATUS, status);
      if (status[1] !== 1'b1 || status[0] !== 1'b0) begin
        $display("FAIL desc_start_done_clear: done/busy mismatch status=0x%08x", status);
        local_failures = local_failures + 1;
      end
      apb_write(DMA_CTRL, 32'h2);
      apb_read(DMA_STATUS, status);
      if (status[1] !== 1'b0) begin
        $display("FAIL desc_start_done_clear: done did not clear status=0x%08x", status);
        local_failures = local_failures + 1;
      end

      if (local_failures == 0) begin
        tests_passed = tests_passed + 1;
        $display("PASS desc_start_done_clear");
      end else begin
        failures = failures + local_failures;
      end
    end
  endtask

  task automatic run_desc_start_while_busy;
    int local_failures;
    logic [31:0] status;
    begin
      local_failures = 0;
      apb_write(DMA_CTRL, 32'h1);
      apb_write(DMA_CTRL, 32'h1);
      apb_read(DMA_STATUS, status);
      if (status[2] !== 1'b0) begin
        $display("FAIL desc_start_while_busy: error set status=0x%08x", status);
        local_failures = local_failures + 1;
      end
      wait_desc_done();
      apb_read(DMA_STATUS, status);
      if (status[1] !== 1'b1 || status[2] !== 1'b0) begin
        $display("FAIL desc_start_while_busy: final status=0x%08x", status);
        local_failures = local_failures + 1;
      end
      apb_write(DMA_CTRL, 32'h2);

      if (local_failures == 0) begin
        tests_passed = tests_passed + 1;
        $display("PASS desc_start_while_busy");
      end else begin
        failures = failures + local_failures;
      end
    end
  endtask

  task automatic run_desc_invalid_access;
    int local_failures;
    logic [31:0] data;
    begin
      local_failures = 0;
      apb_write(DMA_A_EXT_BASE, 32'h1234_5678);
      apb_write(12'h118, 32'hffff_ffff);
      apb_read(12'h118, data);
      if (data !== 32'h0) begin
        $display("FAIL desc_invalid_access: invalid descriptor read=0x%08x", data);
        local_failures = local_failures + 1;
      end
      apb_read(DMA_A_EXT_BASE, data);
      if (data !== 32'h1234_5678) begin
        $display("FAIL desc_invalid_access: descriptor register corrupted=0x%08x", data);
        local_failures = local_failures + 1;
      end
      apb_read(12'h200, data);
      if (data !== 32'h0) begin
        $display("FAIL desc_invalid_access: outside range read=0x%08x", data);
        local_failures = local_failures + 1;
      end

      if (local_failures == 0) begin
        tests_passed = tests_passed + 1;
        $display("PASS desc_invalid_access");
      end else begin
        failures = failures + local_failures;
      end
    end
  endtask

  task automatic run_forwarded_core_identity;
    int i;
    int local_failures;
    int signed got;
    logic [31:0] data;
    begin
      local_failures = 0;
      for (i = 0; i < MATRIX_ELEMS; i = i + 1) begin
        apb_write(ADDR_A_BASE + (i * 4), 32'h0);
        apb_write(ADDR_B_BASE + (i * 4), pack_i8(i + 1));
      end
      for (i = 0; i < MATRIX_N; i = i + 1) begin
        apb_write(ADDR_A_BASE + (((i * MATRIX_N) + i) * 4), pack_i8(1));
      end

      apb_write(ADDR_CTRL, 32'h1);
      wait_core_done();

      for (i = 0; i < MATRIX_ELEMS; i = i + 1) begin
        apb_read(ADDR_C_BASE + (i * 4), data);
        got = $signed(data);
        if (got !== (i + 1)) begin
          $display("FAIL forwarded_core_identity: C[%0d] expected %0d actual %0d", i, i + 1, got);
          local_failures = local_failures + 1;
        end
      end

      if (local_failures == 0) begin
        tests_passed = tests_passed + 1;
        $display("PASS forwarded_core_identity");
      end else begin
        failures = failures + local_failures;
      end
    end
  endtask

  task automatic run_forwarded_core_invalid_unaligned;
    int local_failures;
    logic [31:0] data;
    begin
      local_failures = 0;
      apb_read(12'h011, data);
      if (data !== 32'h0) begin
        $display("FAIL forwarded_core_invalid_unaligned: unaligned read=0x%08x", data);
        local_failures = local_failures + 1;
      end
      apb_write(12'h011, 32'hffff_ffff);
      apb_read(12'h0f0, data);
      if (data !== 32'h0) begin
        $display("FAIL forwarded_core_invalid_unaligned: invalid read=0x%08x", data);
        local_failures = local_failures + 1;
      end

      if (local_failures == 0) begin
        tests_passed = tests_passed + 1;
        $display("PASS forwarded_core_invalid_unaligned");
      end else begin
        failures = failures + local_failures;
      end
    end
  endtask

  initial begin
    $dumpfile("build/sim/dma_desc_wrapper/tinynpu_dma_descriptor_wrapper.vcd");
    $dumpvars(0, tb_tinynpu_dma_descriptor_wrapper);

    failures = 0;
    tests_passed = 0;

    psel    = 1'b0;
    penable = 1'b0;
    pwrite  = 1'b0;
    paddr   = '0;
    pwdata  = '0;
    presetn = 1'b0;

    repeat (5) @(posedge pclk);
    presetn = 1'b1;
    repeat (2) @(posedge pclk);

    run_desc_regs_read_write();
    run_desc_start_done_clear();
    run_desc_start_while_busy();
    run_desc_invalid_access();
    run_forwarded_core_identity();
    run_forwarded_core_invalid_unaligned();

    $display("DMA descriptor-wrapper tests passed: %0d", tests_passed);
    if (failures == 0) begin
      $display("tinyNPU DMA descriptor-wrapper SIM PASS");
      $finish;
    end else begin
      $display("tinyNPU DMA descriptor-wrapper SIM FAIL failures=%0d", failures);
      $fatal(1);
    end
  end
endmodule
