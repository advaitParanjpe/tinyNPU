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
  logic        mem_valid;
  logic        mem_we;
  logic [31:0] mem_addr;
  logic [31:0] mem_wdata;
  logic [31:0] mem_rdata;
  logic        mem_ready;

  localparam int EXT_MEM_WORDS = 256;
  localparam int EXT_A0_BASE = 0;
  localparam int EXT_B0_BASE = 32;
  localparam int EXT_C0_BASE = 64;
  localparam int EXT_A1_BASE = 96;
  localparam int EXT_B1_BASE = 128;
  localparam int EXT_C1_BASE = 160;

  logic [31:0] ext_mem [0:EXT_MEM_WORDS-1];

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
    .pslverr (pslverr),
    .mem_valid (mem_valid),
    .mem_we    (mem_we),
    .mem_addr  (mem_addr),
    .mem_wdata (mem_wdata),
    .mem_rdata (mem_rdata),
    .mem_ready (mem_ready)
  );

  assign mem_ready = 1'b1;
  assign mem_rdata = (mem_addr < EXT_MEM_WORDS) ? ext_mem[mem_addr[7:0]] : 32'h0;

  always_ff @(posedge pclk) begin
    if (mem_valid && mem_we && mem_ready && (mem_addr < EXT_MEM_WORDS)) begin
      ext_mem[mem_addr[7:0]] <= mem_wdata;
    end
  end

  initial begin
    pclk = 1'b0;
    forever #5 pclk = ~pclk;
  end

  function automatic logic [31:0] pack_i8(input int value);
    begin
      pack_i8 = {{24{value[7]}}, value[7:0]};
    end
  endfunction

  function automatic int mixed_a(input int idx);
    begin
      case (idx)
        0: mixed_a = 3;    1: mixed_a = -2;   2: mixed_a = 7;    3: mixed_a = 1;
        4: mixed_a = -5;   5: mixed_a = 4;    6: mixed_a = 0;    7: mixed_a = 6;
        8: mixed_a = 9;    9: mixed_a = -8;   10: mixed_a = 2;   11: mixed_a = -1;
        12: mixed_a = 1;   13: mixed_a = 3;   14: mixed_a = -4;  15: mixed_a = 5;
        default: mixed_a = 0;
      endcase
    end
  endfunction

  function automatic int mixed_b(input int idx);
    begin
      case (idx)
        0: mixed_b = -1;   1: mixed_b = 2;    2: mixed_b = 0;    3: mixed_b = 5;
        4: mixed_b = 6;    5: mixed_b = -3;   6: mixed_b = 4;    7: mixed_b = 1;
        8: mixed_b = 2;    9: mixed_b = 7;    10: mixed_b = -6;  11: mixed_b = 3;
        12: mixed_b = 0;   13: mixed_b = -2;  14: mixed_b = 8;   15: mixed_b = -4;
        default: mixed_b = 0;
      endcase
    end
  endfunction

  function automatic int signed ext_i8(input int word_addr);
    begin
      ext_i8 = $signed(ext_mem[word_addr][7:0]);
    end
  endfunction

  function automatic int signed expected_c(input int a_base, input int b_base, input int elem_idx);
    int row;
    int col;
    int k;
    int signed sum;
    begin
      row = elem_idx / MATRIX_N;
      col = elem_idx % MATRIX_N;
      sum = 0;
      for (k = 0; k < MATRIX_N; k = k + 1) begin
        sum = sum + (ext_i8(a_base + (row * MATRIX_N) + k) *
                     ext_i8(b_base + (k * MATRIX_N) + col));
      end
      expected_c = sum;
    end
  endfunction

  task automatic clear_ext_mem(input logic [31:0] value);
    int i;
    begin
      for (i = 0; i < EXT_MEM_WORDS; i = i + 1) begin
        ext_mem[i] = value;
      end
    end
  endtask

  task automatic fill_identity_case(input int a_base, input int b_base);
    int i;
    begin
      for (i = 0; i < MATRIX_ELEMS; i = i + 1) begin
        ext_mem[a_base + i] = pack_i8(0);
        ext_mem[b_base + i] = pack_i8(i + 1);
      end
      for (i = 0; i < MATRIX_N; i = i + 1) begin
        ext_mem[a_base + (i * MATRIX_N) + i] = pack_i8(1);
      end
    end
  endtask

  task automatic fill_mixed_case(input int a_base, input int b_base);
    int i;
    begin
      for (i = 0; i < MATRIX_ELEMS; i = i + 1) begin
        ext_mem[a_base + i] = pack_i8(mixed_a(i));
        ext_mem[b_base + i] = pack_i8(mixed_b(i));
      end
    end
  endtask

  task automatic start_dma(input int a_base, input int b_base, input int c_base);
    begin
      apb_write(DMA_A_EXT_BASE, a_base);
      apb_write(DMA_B_EXT_BASE, b_base);
      apb_write(DMA_C_EXT_BASE, c_base);
      apb_write(DMA_CTRL, 32'h1);
    end
  endtask

  task automatic clear_dma_done;
    begin
      apb_write(DMA_CTRL, 32'h2);
    end
  endtask

  task automatic check_ext_c(input string test_name, input int a_base, input int b_base, input int c_base, output int local_failures);
    int i;
    int signed expected;
    int signed got;
    begin
      local_failures = 0;
      for (i = 0; i < MATRIX_ELEMS; i = i + 1) begin
        expected = expected_c(a_base, b_base, i);
        got = $signed(ext_mem[c_base + i]);
        if (got !== expected) begin
          $display("FAIL %s: C[%0d] expected %0d actual %0d", test_name, i, expected, got);
          local_failures = local_failures + 1;
        end
      end
    end
  endtask

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
      while ((status[1] !== 1'b1) && (timeout < 120)) begin
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

  task automatic load_core_identity;
    int i;
    begin
      for (i = 0; i < MATRIX_ELEMS; i = i + 1) begin
        apb_write(ADDR_A_BASE + (i * 4), 32'h0);
        apb_write(ADDR_B_BASE + (i * 4), pack_i8(i + 1));
      end
      for (i = 0; i < MATRIX_N; i = i + 1) begin
        apb_write(ADDR_A_BASE + (((i * MATRIX_N) + i) * 4), pack_i8(1));
      end
    end
  endtask

  task automatic check_core_identity(input string test_name, output int local_failures);
    int i;
    int signed got;
    logic [31:0] data;
    begin
      local_failures = 0;
      for (i = 0; i < MATRIX_ELEMS; i = i + 1) begin
        apb_read(ADDR_C_BASE + (i * 4), data);
        got = $signed(data);
        if (got !== (i + 1)) begin
          $display("FAIL %s: C[%0d] expected %0d actual %0d", test_name, i, i + 1, got);
          local_failures = local_failures + 1;
        end
      end
    end
  endtask

  task automatic run_desc_fsm_start_done;
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
        $display("PASS desc_fsm_start_done");
      end else begin
        failures = failures + local_failures;
      end
    end
  endtask

  task automatic run_desc_dma_identity;
    int local_failures;
    int c_failures;
    begin
      local_failures = 0;
      clear_ext_mem(32'h0);
      fill_identity_case(EXT_A0_BASE, EXT_B0_BASE);
      start_dma(EXT_A0_BASE, EXT_B0_BASE, EXT_C0_BASE);
      wait_desc_done();

      check_ext_c("desc_dma_identity", EXT_A0_BASE, EXT_B0_BASE, EXT_C0_BASE, c_failures);
      local_failures = local_failures + c_failures;

      if (local_failures == 0) begin
        tests_passed = tests_passed + 1;
        $display("PASS desc_dma_identity");
      end else begin
        failures = failures + local_failures;
      end
      clear_dma_done();
    end
  endtask

  task automatic run_desc_dma_mixed_signed;
    int local_failures;
    int c_failures;
    begin
      local_failures = 0;
      clear_ext_mem(32'h0);
      fill_mixed_case(EXT_A0_BASE, EXT_B0_BASE);
      start_dma(EXT_A0_BASE, EXT_B0_BASE, EXT_C0_BASE);
      wait_desc_done();

      check_ext_c("desc_dma_mixed_signed", EXT_A0_BASE, EXT_B0_BASE, EXT_C0_BASE, c_failures);
      local_failures = local_failures + c_failures;

      if (local_failures == 0) begin
        tests_passed = tests_passed + 1;
        $display("PASS desc_dma_mixed_signed");
      end else begin
        failures = failures + local_failures;
      end
      clear_dma_done();
    end
  endtask

  task automatic run_desc_dma_back_to_back;
    int local_failures;
    int c_failures;
    begin
      local_failures = 0;
      clear_ext_mem(32'h0);

      fill_identity_case(EXT_A0_BASE, EXT_B0_BASE);
      start_dma(EXT_A0_BASE, EXT_B0_BASE, EXT_C0_BASE);
      wait_desc_done();
      check_ext_c("desc_dma_back_to_back_first", EXT_A0_BASE, EXT_B0_BASE, EXT_C0_BASE, c_failures);
      local_failures = local_failures + c_failures;
      clear_dma_done();

      fill_mixed_case(EXT_A1_BASE, EXT_B1_BASE);
      start_dma(EXT_A1_BASE, EXT_B1_BASE, EXT_C1_BASE);
      wait_desc_done();
      check_ext_c("desc_dma_back_to_back_second", EXT_A1_BASE, EXT_B1_BASE, EXT_C1_BASE, c_failures);
      local_failures = local_failures + c_failures;

      if (local_failures == 0) begin
        tests_passed = tests_passed + 1;
        $display("PASS desc_dma_back_to_back");
      end else begin
        failures = failures + local_failures;
      end
      clear_dma_done();
    end
  endtask

  task automatic run_desc_dma_core_window_blocked_while_busy;
    int local_failures;
    logic [31:0] data;
    logic [31:0] status;
    begin
      local_failures = 0;
      clear_ext_mem(32'h0);
      fill_identity_case(EXT_A0_BASE, EXT_B0_BASE);
      apb_write(ADDR_A_BASE, pack_i8(5));
      start_dma(EXT_A0_BASE, EXT_B0_BASE, EXT_C0_BASE);
      apb_read(DMA_STATUS, status);
      if (status[0] !== 1'b1) begin
        $display("FAIL desc_dma_core_window_blocked_while_busy: busy not set status=0x%08x", status);
        local_failures = local_failures + 1;
      end

      apb_write(ADDR_A_BASE, pack_i8(99));
      apb_read(ADDR_A_BASE, data);
      if (data !== 32'h0) begin
        $display("FAIL desc_dma_core_window_blocked_while_busy: busy core read returned 0x%08x", data);
        local_failures = local_failures + 1;
      end

      wait_desc_done();

      if (local_failures == 0) begin
        tests_passed = tests_passed + 1;
        $display("PASS desc_dma_core_window_blocked_while_busy");
      end else begin
        failures = failures + local_failures;
      end
      clear_dma_done();
    end
  endtask

  task automatic run_desc_dma_memory_unchanged;
    int local_failures;
    int i;
    bit in_used_region;
    begin
      local_failures = 0;
      clear_ext_mem(32'h5a5a_a5a5);
      fill_identity_case(EXT_A0_BASE, EXT_B0_BASE);
      start_dma(EXT_A0_BASE, EXT_B0_BASE, EXT_C0_BASE);
      wait_desc_done();

      for (i = 0; i < EXT_MEM_WORDS; i = i + 1) begin
        in_used_region = ((i >= EXT_A0_BASE) && (i < EXT_A0_BASE + MATRIX_ELEMS)) ||
                         ((i >= EXT_B0_BASE) && (i < EXT_B0_BASE + MATRIX_ELEMS)) ||
                         ((i >= EXT_C0_BASE) && (i < EXT_C0_BASE + MATRIX_ELEMS));
        if (!in_used_region && (ext_mem[i] !== 32'h5a5a_a5a5)) begin
          $display("FAIL desc_dma_memory_unchanged: ext_mem[%0d] changed to 0x%08x", i, ext_mem[i]);
          local_failures = local_failures + 1;
        end
      end

      if (local_failures == 0) begin
        tests_passed = tests_passed + 1;
        $display("PASS desc_dma_memory_unchanged");
      end else begin
        failures = failures + local_failures;
      end
      clear_dma_done();
    end
  endtask

  task automatic run_desc_start_while_busy;
    int local_failures;
    logic [31:0] status;
    begin
      local_failures = 0;
      clear_ext_mem(32'h0);
      fill_identity_case(EXT_A0_BASE, EXT_B0_BASE);
      start_dma(EXT_A0_BASE, EXT_B0_BASE, EXT_C0_BASE);
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
    int local_failures;
    begin
      local_failures = 0;
      load_core_identity();

      apb_write(ADDR_CTRL, 32'h1);
      wait_core_done();

      check_core_identity("forwarded_core_identity", local_failures);

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
    clear_ext_mem(32'h0);

    repeat (5) @(posedge pclk);
    presetn = 1'b1;
    repeat (2) @(posedge pclk);

    run_desc_regs_read_write();
    run_desc_fsm_start_done();
    run_desc_start_while_busy();
    run_desc_invalid_access();
    run_forwarded_core_identity();
    run_forwarded_core_invalid_unaligned();
    run_desc_dma_identity();
    run_desc_dma_mixed_signed();
    run_desc_dma_back_to_back();
    run_desc_dma_core_window_blocked_while_busy();
    run_desc_dma_memory_unchanged();

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
