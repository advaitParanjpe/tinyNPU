`timescale 1ns/1ps

import tinynpu_pkg::*;

module tb_tinynpu_apb_dma_model;
  localparam logic [7:0] ADDR_CTRL   = 8'h00;
  localparam logic [7:0] ADDR_STATUS = 8'h04;
  localparam logic [7:0] ADDR_A_BASE = 8'h10;
  localparam logic [7:0] ADDR_B_BASE = 8'h50;
  localparam logic [7:0] ADDR_C_BASE = 8'h90;

  localparam int DMA_CTRL       = 12'h100;
  localparam int DMA_STATUS     = 12'h104;
  localparam int DMA_A_EXT_BASE = 12'h108;
  localparam int DMA_B_EXT_BASE = 12'h10c;
  localparam int DMA_C_EXT_BASE = 12'h110;
  localparam int DMA_CONFIG     = 12'h114;

  localparam int EXT_MEM_WORDS = 256;

  localparam int EXT_A0_BASE = 0;
  localparam int EXT_B0_BASE = 16;
  localparam int EXT_C0_BASE = 32;
  localparam int EXT_A1_BASE = 64;
  localparam int EXT_B1_BASE = 80;
  localparam int EXT_C1_BASE = 96;
  localparam int EXT_SENTINEL_BASE = 180;

  logic        pclk;
  logic        presetn;
  logic        psel;
  logic        penable;
  logic        pwrite;
  logic [7:0]  paddr;
  logic [31:0] pwdata;
  logic [31:0] prdata;
  logic        pready;
  logic        pslverr;

  logic signed [31:0] ext_mem [0:EXT_MEM_WORDS-1];

  logic        dma_busy;
  logic        dma_done;
  logic        dma_error;
  logic [31:0] desc_a_base;
  logic [31:0] desc_b_base;
  logic [31:0] desc_c_base;
  logic [31:0] desc_config;

  event dma_start_event;

  int failures;
  int tests_passed;

  tinynpu_apb_wrapper dut (
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

  function automatic int signed ext_i8(input int word_idx);
    logic signed [7:0] value;
    begin
      value = ext_mem[word_idx][7:0];
      ext_i8 = value;
    end
  endfunction

  task automatic apb_write(input logic [7:0] addr, input logic [31:0] data);
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
      @(negedge pclk);
      psel    <= 1'b0;
      penable <= 1'b0;
      pwrite  <= 1'b0;
      paddr   <= '0;
      pwdata  <= '0;
    end
  endtask

  task automatic apb_read(input logic [7:0] addr, output logic [31:0] data);
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
      #1;
      data = prdata;
      @(negedge pclk);
      psel    <= 1'b0;
      penable <= 1'b0;
      paddr   <= '0;
    end
  endtask

  task automatic apb_start;
    begin
      apb_write(ADDR_CTRL, 32'h1);
    end
  endtask

  task automatic apb_wait_done;
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
        $display("FAIL apb_wait_done: timed out status=0x%08x", status);
        failures = failures + 1;
      end
    end
  endtask

  task automatic dma_load_a_from_ext(input int base_word_addr);
    int i;
    begin
      for (i = 0; i < MATRIX_ELEMS; i = i + 1) begin
        apb_write(ADDR_A_BASE + (i * 4), pack_i8(ext_i8(base_word_addr + i)));
      end
    end
  endtask

  task automatic dma_load_b_from_ext(input int base_word_addr);
    int i;
    begin
      for (i = 0; i < MATRIX_ELEMS; i = i + 1) begin
        apb_write(ADDR_B_BASE + (i * 4), pack_i8(ext_i8(base_word_addr + i)));
      end
    end
  endtask

  task automatic dma_store_c_to_ext(input int base_word_addr);
    int i;
    logic [31:0] data;
    begin
      for (i = 0; i < MATRIX_ELEMS; i = i + 1) begin
        apb_read(ADDR_C_BASE + (i * 4), data);
        ext_mem[base_word_addr + i] = $signed(data);
      end
    end
  endtask

  task automatic dma_descriptor_worker;
    int a_base;
    int b_base;
    int c_base;
    begin
      a_base = desc_a_base;
      b_base = desc_b_base;
      c_base = desc_c_base;

      dma_load_a_from_ext(a_base);
      dma_load_b_from_ext(b_base);
      apb_start();
      apb_wait_done();
      dma_store_c_to_ext(c_base);

      dma_busy = 1'b0;
      dma_done = 1'b1;
    end
  endtask

  task automatic reset_desc_model;
    begin
      dma_busy = 1'b0;
      dma_done = 1'b0;
      dma_error = 1'b0;
      desc_a_base = '0;
      desc_b_base = '0;
      desc_c_base = '0;
      desc_config = '0;
    end
  endtask

  task automatic desc_write(input int addr, input logic [31:0] data);
    begin
      @(posedge pclk);
      case (addr)
        DMA_CTRL: begin
          if (data[1]) begin
            dma_done = 1'b0;
            dma_error = 1'b0;
          end
          if (data[0] && !dma_busy) begin
            dma_busy = 1'b1;
            dma_done = 1'b0;
            dma_error = 1'b0;
            -> dma_start_event;
          end
        end
        DMA_A_EXT_BASE: desc_a_base = data;
        DMA_B_EXT_BASE: desc_b_base = data;
        DMA_C_EXT_BASE: desc_c_base = data;
        DMA_CONFIG:     desc_config = data;
        default: begin
        end
      endcase
    end
  endtask

  task automatic desc_read(input int addr, output logic [31:0] data);
    begin
      @(posedge pclk);
      case (addr)
        DMA_CTRL:       data = 32'h0;
        DMA_STATUS:     data = {29'h0, dma_error, dma_done, dma_busy};
        DMA_A_EXT_BASE: data = desc_a_base;
        DMA_B_EXT_BASE: data = desc_b_base;
        DMA_C_EXT_BASE: data = desc_c_base;
        DMA_CONFIG:     data = desc_config;
        default:        data = 32'h0;
      endcase
    end
  endtask

  task automatic desc_start;
    begin
      desc_write(DMA_CTRL, 32'h1);
    end
  endtask

  task automatic desc_clear_done;
    begin
      desc_write(DMA_CTRL, 32'h2);
    end
  endtask

  task automatic desc_wait_busy;
    logic [31:0] status;
    int timeout;
    begin
      timeout = 0;
      desc_read(DMA_STATUS, status);
      while ((status[0] !== 1'b1) && (timeout < 20)) begin
        timeout = timeout + 1;
        desc_read(DMA_STATUS, status);
      end
      if (status[0] !== 1'b1) begin
        $display("FAIL desc_wait_busy: timed out status=0x%08x", status);
        failures = failures + 1;
      end
    end
  endtask

  task automatic desc_wait_done;
    logic [31:0] status;
    int timeout;
    begin
      timeout = 0;
      desc_read(DMA_STATUS, status);
      while ((status[1] !== 1'b1) && (timeout < 300)) begin
        timeout = timeout + 1;
        desc_read(DMA_STATUS, status);
      end
      if (status[1] !== 1'b1) begin
        $display("FAIL desc_wait_done: timed out status=0x%08x", status);
        failures = failures + 1;
      end
    end
  endtask

  task automatic desc_program_and_start(input int a_base, input int b_base, input int c_base);
    begin
      desc_write(DMA_A_EXT_BASE, a_base);
      desc_write(DMA_B_EXT_BASE, b_base);
      desc_write(DMA_C_EXT_BASE, c_base);
      desc_start();
    end
  endtask

  task automatic clear_ext_mem;
    int i;
    begin
      for (i = 0; i < EXT_MEM_WORDS; i = i + 1) begin
        ext_mem[i] = '0;
      end
    end
  endtask

  task automatic init_identity_case(input int a_base, input int b_base);
    int i;
    begin
      for (i = 0; i < MATRIX_ELEMS; i = i + 1) begin
        ext_mem[a_base + i] = '0;
        ext_mem[b_base + i] = i + 1;
      end
      for (i = 0; i < MATRIX_N; i = i + 1) begin
        ext_mem[a_base + (i * MATRIX_N) + i] = 1;
      end
    end
  endtask

  task automatic init_mixed_case(input int a_base, input int b_base);
    begin
      ext_mem[a_base + 0]  =   1; ext_mem[a_base + 1]  =  -2;
      ext_mem[a_base + 2]  =   3; ext_mem[a_base + 3]  =  -4;
      ext_mem[a_base + 4]  =   5; ext_mem[a_base + 5]  =   6;
      ext_mem[a_base + 6]  =  -7; ext_mem[a_base + 7]  =   8;
      ext_mem[a_base + 8]  =  -9; ext_mem[a_base + 9]  =  10;
      ext_mem[a_base + 10] =  11; ext_mem[a_base + 11] = -12;
      ext_mem[a_base + 12] =  13; ext_mem[a_base + 13] = -14;
      ext_mem[a_base + 14] =  15; ext_mem[a_base + 15] =  16;

      ext_mem[b_base + 0]  =  -1; ext_mem[b_base + 1]  =   2;
      ext_mem[b_base + 2]  =  -3; ext_mem[b_base + 3]  =   4;
      ext_mem[b_base + 4]  =   5; ext_mem[b_base + 5]  =  -6;
      ext_mem[b_base + 6]  =   7; ext_mem[b_base + 7]  =  -8;
      ext_mem[b_base + 8]  =   9; ext_mem[b_base + 9]  =  10;
      ext_mem[b_base + 10] = -11; ext_mem[b_base + 11] =  12;
      ext_mem[b_base + 12] = -13; ext_mem[b_base + 13] =  14;
      ext_mem[b_base + 14] =  15; ext_mem[b_base + 15] = -16;
    end
  endtask

  task automatic check_c_region(
    input string test_name,
    input int a_base,
    input int b_base,
    input int c_base,
    output int local_failures
  );
    int row;
    int col;
    int k;
    int idx;
    int signed expected;
    int signed got;
    begin
      local_failures = 0;
      for (row = 0; row < MATRIX_N; row = row + 1) begin
        for (col = 0; col < MATRIX_N; col = col + 1) begin
          expected = 0;
          for (k = 0; k < MATRIX_N; k = k + 1) begin
            expected = expected + (ext_i8(a_base + (row * MATRIX_N) + k) *
                                   ext_i8(b_base + (k * MATRIX_N) + col));
          end
          idx = (row * MATRIX_N) + col;
          got = ext_mem[c_base + idx];
          if (got !== expected) begin
            $display("FAIL %s: C[%0d] expected %0d actual %0d", test_name, idx, expected, got);
            failures = failures + 1;
            local_failures = local_failures + 1;
          end
        end
      end
    end
  endtask

  task automatic run_dma_desc_case(input string test_name, input int a_base, input int b_base, input int c_base);
    int local_failures;
    begin
      desc_program_and_start(a_base, b_base, c_base);
      desc_wait_done();
      check_c_region(test_name, a_base, b_base, c_base, local_failures);
      if (local_failures == 0) begin
        tests_passed = tests_passed + 1;
        $display("PASS %s", test_name);
      end
    end
  endtask

  task automatic run_dma_desc_back_to_back;
    int local_failures0;
    int local_failures1;
    begin
      init_identity_case(EXT_A0_BASE, EXT_B0_BASE);
      init_mixed_case(EXT_A1_BASE, EXT_B1_BASE);

      desc_program_and_start(EXT_A0_BASE, EXT_B0_BASE, EXT_C0_BASE);
      desc_wait_done();
      desc_clear_done();

      desc_program_and_start(EXT_A1_BASE, EXT_B1_BASE, EXT_C1_BASE);
      desc_wait_done();

      check_c_region("dma_desc_back_to_back_first", EXT_A0_BASE, EXT_B0_BASE, EXT_C0_BASE, local_failures0);
      check_c_region("dma_desc_back_to_back_second", EXT_A1_BASE, EXT_B1_BASE, EXT_C1_BASE, local_failures1);
      if ((local_failures0 == 0) && (local_failures1 == 0)) begin
        tests_passed = tests_passed + 1;
        $display("PASS dma_desc_back_to_back");
      end
    end
  endtask

  task automatic run_dma_desc_start_while_busy;
    int local_failures;
    logic [31:0] status;
    begin
      init_mixed_case(EXT_A0_BASE, EXT_B0_BASE);
      desc_program_and_start(EXT_A0_BASE, EXT_B0_BASE, EXT_C0_BASE);
      desc_wait_busy();
      desc_start();
      desc_read(DMA_STATUS, status);
      if (status[2] !== 1'b0) begin
        $display("FAIL dma_desc_start_while_busy: unexpected error status=0x%08x", status);
        failures = failures + 1;
      end
      desc_wait_done();
      check_c_region("dma_desc_start_while_busy", EXT_A0_BASE, EXT_B0_BASE, EXT_C0_BASE, local_failures);
      if (local_failures == 0) begin
        tests_passed = tests_passed + 1;
        $display("PASS dma_desc_start_while_busy");
      end
    end
  endtask

  task automatic run_dma_desc_invalid_access;
    int local_failures;
    logic [31:0] data;
    begin
      local_failures = 0;
      desc_write(DMA_A_EXT_BASE, EXT_A0_BASE);
      desc_write(12'h1f0, 32'hffff_ffff);
      desc_read(12'h1f0, data);
      if (data !== 32'h0) begin
        $display("FAIL dma_desc_invalid_access: invalid read returned 0x%08x", data);
        failures = failures + 1;
        local_failures = local_failures + 1;
      end
      desc_read(DMA_A_EXT_BASE, data);
      if (data !== EXT_A0_BASE) begin
        $display("FAIL dma_desc_invalid_access: valid register corrupted, got 0x%08x", data);
        failures = failures + 1;
        local_failures = local_failures + 1;
      end
      if (local_failures == 0) begin
        tests_passed = tests_passed + 1;
        $display("PASS dma_desc_invalid_access");
      end
    end
  endtask

  task automatic run_dma_desc_external_memory_unchanged;
    int i;
    int local_failures;
    begin
      local_failures = 0;
      for (i = 0; i < 8; i = i + 1) begin
        ext_mem[EXT_SENTINEL_BASE + i] = 32'sh1357_0000 + i;
      end

      init_identity_case(EXT_A0_BASE, EXT_B0_BASE);
      desc_program_and_start(EXT_A0_BASE, EXT_B0_BASE, EXT_C0_BASE);
      desc_wait_done();

      for (i = 0; i < 8; i = i + 1) begin
        if (ext_mem[EXT_SENTINEL_BASE + i] !== (32'sh1357_0000 + i)) begin
          $display("FAIL dma_desc_external_memory_unchanged: ext_mem[%0d] changed to 0x%08x",
                   EXT_SENTINEL_BASE + i, ext_mem[EXT_SENTINEL_BASE + i]);
          failures = failures + 1;
          local_failures = local_failures + 1;
        end
      end

      if (local_failures == 0) begin
        tests_passed = tests_passed + 1;
        $display("PASS dma_desc_external_memory_unchanged");
      end
    end
  endtask

  initial begin
    forever begin
      @dma_start_event;
      dma_descriptor_worker();
    end
  end

  initial begin
    $dumpfile("build/sim/apb_dma/tinynpu_apb_dma_model.vcd");
    $dumpvars(0, tb_tinynpu_apb_dma_model);

    failures = 0;
    tests_passed = 0;
    clear_ext_mem();
    reset_desc_model();

    psel    = 1'b0;
    penable = 1'b0;
    pwrite  = 1'b0;
    paddr   = '0;
    pwdata  = '0;
    presetn = 1'b0;

    repeat (5) @(posedge pclk);
    presetn = 1'b1;
    repeat (2) @(posedge pclk);

    init_identity_case(EXT_A0_BASE, EXT_B0_BASE);
    run_dma_desc_case("dma_desc_identity", EXT_A0_BASE, EXT_B0_BASE, EXT_C0_BASE);
    desc_clear_done();

    init_mixed_case(EXT_A0_BASE, EXT_B0_BASE);
    run_dma_desc_case("dma_desc_mixed_signed", EXT_A0_BASE, EXT_B0_BASE, EXT_C0_BASE);
    desc_clear_done();

    clear_ext_mem();
    run_dma_desc_back_to_back();
    desc_clear_done();

    clear_ext_mem();
    run_dma_desc_start_while_busy();
    desc_clear_done();

    run_dma_desc_invalid_access();

    clear_ext_mem();
    run_dma_desc_external_memory_unchanged();

    $display("DMA descriptor-model tests passed: %0d", tests_passed);
    if (failures == 0) begin
      $display("tinyNPU APB DMA descriptor-model SIM PASS");
      $finish;
    end else begin
      $display("tinyNPU APB DMA descriptor-model SIM FAIL failures=%0d", failures);
      $fatal(1);
    end
  end
endmodule
