`timescale 1ns/1ps

import tinynpu_pkg::*;

module tb_tinynpu_axi_lite_wrapper;
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

  localparam int EXT_MEM_WORDS = 256;
  localparam int EXT_A0_BASE = 0;
  localparam int EXT_B0_BASE = 32;
  localparam int EXT_C0_BASE = 64;
  localparam int EXT_A1_BASE = 96;
  localparam int EXT_B1_BASE = 128;
  localparam int EXT_C1_BASE = 160;

  logic        aclk;
  logic        aresetn;
  logic [11:0] s_axi_awaddr;
  logic        s_axi_awvalid;
  logic        s_axi_awready;
  logic [31:0] s_axi_wdata;
  logic [3:0]  s_axi_wstrb;
  logic        s_axi_wvalid;
  logic        s_axi_wready;
  logic [1:0]  s_axi_bresp;
  logic        s_axi_bvalid;
  logic        s_axi_bready;
  logic [11:0] s_axi_araddr;
  logic        s_axi_arvalid;
  logic        s_axi_arready;
  logic [31:0] s_axi_rdata;
  logic [1:0]  s_axi_rresp;
  logic        s_axi_rvalid;
  logic        s_axi_rready;
  logic        mem_valid;
  logic        mem_we;
  logic [31:0] mem_addr;
  logic [31:0] mem_wdata;
  logic [31:0] mem_rdata;
  logic        mem_ready;
  logic        mem_ready_q;

  logic [31:0] ext_mem [0:EXT_MEM_WORDS-1];
  int failures;
  int tests_passed;
  int mem_wait_count;
  int mem_transaction_count;

  tinynpu_axi_lite_wrapper dut (
    .aclk          (aclk),
    .aresetn       (aresetn),
    .s_axi_awaddr  (s_axi_awaddr),
    .s_axi_awvalid (s_axi_awvalid),
    .s_axi_awready (s_axi_awready),
    .s_axi_wdata   (s_axi_wdata),
    .s_axi_wstrb   (s_axi_wstrb),
    .s_axi_wvalid  (s_axi_wvalid),
    .s_axi_wready  (s_axi_wready),
    .s_axi_bresp   (s_axi_bresp),
    .s_axi_bvalid  (s_axi_bvalid),
    .s_axi_bready  (s_axi_bready),
    .s_axi_araddr  (s_axi_araddr),
    .s_axi_arvalid (s_axi_arvalid),
    .s_axi_arready (s_axi_arready),
    .s_axi_rdata   (s_axi_rdata),
    .s_axi_rresp   (s_axi_rresp),
    .s_axi_rvalid  (s_axi_rvalid),
    .s_axi_rready  (s_axi_rready),
    .mem_valid     (mem_valid),
    .mem_we        (mem_we),
    .mem_addr      (mem_addr),
    .mem_wdata     (mem_wdata),
    .mem_rdata     (mem_rdata),
    .mem_ready     (mem_ready)
  );

  tinynpu_mem_port_assertions u_mem_port_assertions (
    .clk       (aclk),
    .rst_n     (aresetn),
    .mem_valid (mem_valid),
    .mem_we    (mem_we),
    .mem_addr  (mem_addr),
    .mem_wdata (mem_wdata),
    .mem_rdata (mem_rdata),
    .mem_ready (mem_ready)
  );

  assign mem_ready = mem_ready_q;
  assign mem_rdata = (mem_addr < EXT_MEM_WORDS) ? ext_mem[mem_addr[7:0]] : 32'h0;

  initial begin
    aclk = 1'b0;
    forever #5 aclk = ~aclk;
  end

  always_ff @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
      mem_ready_q <= 1'b0;
      mem_wait_count <= 0;
      mem_transaction_count <= 0;
    end else if (!mem_valid) begin
      mem_ready_q <= 1'b0;
      mem_wait_count <= 0;
    end else if (mem_ready_q) begin
      mem_ready_q <= 1'b0;
      mem_transaction_count <= mem_transaction_count + 1;
      mem_wait_count <= 0;
    end else if (mem_wait_count >= ((mem_transaction_count * 3) % 4)) begin
      mem_ready_q <= 1'b1;
    end else begin
      mem_wait_count <= mem_wait_count + 1;
    end
  end

  always_ff @(posedge aclk) begin
    if (mem_valid && mem_we && mem_ready && (mem_addr < EXT_MEM_WORDS)) begin
      ext_mem[mem_addr[7:0]] <= mem_wdata;
    end
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

  task automatic axi_write_stall(
    input logic [11:0] addr,
    input logic [31:0] data,
    input logic [3:0]  strb,
    input int aw_delay,
    input int w_delay,
    input int bready_delay
  );
    begin
      fork
        begin
          repeat (aw_delay) @(posedge aclk);
          @(negedge aclk);
          s_axi_awaddr  <= addr;
          s_axi_awvalid <= 1'b1;
          @(posedge aclk);
          while (!s_axi_awready) @(posedge aclk);
          @(negedge aclk);
          s_axi_awvalid <= 1'b0;
          s_axi_awaddr  <= '0;
        end
        begin
          repeat (w_delay) @(posedge aclk);
          @(negedge aclk);
          s_axi_wdata  <= data;
          s_axi_wstrb  <= strb;
          s_axi_wvalid <= 1'b1;
          @(posedge aclk);
          while (!s_axi_wready) @(posedge aclk);
          @(negedge aclk);
          s_axi_wvalid <= 1'b0;
          s_axi_wdata  <= '0;
          s_axi_wstrb  <= 4'h0;
        end
      join

      repeat (bready_delay) @(posedge aclk);
      @(negedge aclk);
      s_axi_bready <= 1'b1;
      @(posedge aclk);
      while (!s_axi_bvalid) @(posedge aclk);
      if (s_axi_bresp !== 2'b00) begin
        $display("FAIL axi_write: BRESP not OKAY addr=0x%03x resp=%0d", addr, s_axi_bresp);
        failures = failures + 1;
      end
      @(negedge aclk);
      s_axi_bready <= 1'b0;
    end
  endtask

  task automatic axi_write(input logic [11:0] addr, input logic [31:0] data);
    begin
      axi_write_stall(addr, data, 4'hf, 0, 0, 0);
    end
  endtask

  task automatic axi_write_strb(input logic [11:0] addr, input logic [31:0] data, input logic [3:0] strb);
    begin
      axi_write_stall(addr, data, strb, 0, 0, 0);
    end
  endtask

  task automatic axi_read_stall(input logic [11:0] addr, output logic [31:0] data, input int ar_delay, input int rready_delay);
    begin
      repeat (ar_delay) @(posedge aclk);
      @(negedge aclk);
      s_axi_araddr  <= addr;
      s_axi_arvalid <= 1'b1;
      @(posedge aclk);
      while (!s_axi_arready) @(posedge aclk);
      @(negedge aclk);
      s_axi_arvalid <= 1'b0;
      s_axi_araddr  <= '0;

      repeat (rready_delay) @(posedge aclk);
      @(negedge aclk);
      s_axi_rready <= 1'b1;
      @(posedge aclk);
      while (!s_axi_rvalid) @(posedge aclk);
      if (s_axi_rresp !== 2'b00) begin
        $display("FAIL axi_read: RRESP not OKAY addr=0x%03x resp=%0d", addr, s_axi_rresp);
        failures = failures + 1;
      end
      data = s_axi_rdata;
      @(negedge aclk);
      s_axi_rready <= 1'b0;
    end
  endtask

  task automatic axi_read(input logic [11:0] addr, output logic [31:0] data);
    begin
      axi_read_stall(addr, data, 0, 0);
    end
  endtask

  task automatic wait_dma_done;
    logic [31:0] status;
    int timeout;
    begin
      timeout = 0;
      axi_read(DMA_STATUS, status);
      while ((status[1] !== 1'b1) && (timeout < 1200)) begin
        timeout = timeout + 1;
        axi_read(DMA_STATUS, status);
      end
      if (status[1] !== 1'b1) begin
        $display("FAIL axi_wait_dma_done: timed out status=0x%08x", status);
        failures = failures + 1;
      end
    end
  endtask

  task automatic clear_dma_done_error;
    begin
      axi_write(DMA_CTRL, 32'h6);
    end
  endtask

  task automatic wait_core_done;
    logic [31:0] status;
    int timeout;
    begin
      timeout = 0;
      axi_read(ADDR_STATUS, status);
      while ((status[1] !== 1'b1) && (timeout < 200)) begin
        timeout = timeout + 1;
        axi_read(ADDR_STATUS, status);
      end
      if (status[1] !== 1'b1) begin
        $display("FAIL wait_core_done: timed out status=0x%08x", status);
        failures = failures + 1;
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
      axi_write(DMA_A_EXT_BASE, a_base);
      axi_write(DMA_B_EXT_BASE, b_base);
      axi_write(DMA_C_EXT_BASE, c_base);
      axi_write(DMA_CTRL, 32'h1);
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

  task automatic load_core_identity;
    int i;
    begin
      for (i = 0; i < MATRIX_ELEMS; i = i + 1) begin
        axi_write(ADDR_A_BASE + (i * 4), 32'h0);
        axi_write(ADDR_B_BASE + (i * 4), pack_i8(i + 1));
      end
      for (i = 0; i < MATRIX_N; i = i + 1) begin
        axi_write(ADDR_A_BASE + (((i * MATRIX_N) + i) * 4), pack_i8(1));
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
        axi_read(ADDR_C_BASE + (i * 4), data);
        got = $signed(data);
        if (got !== (i + 1)) begin
          $display("FAIL %s: C[%0d] expected %0d actual %0d", test_name, i, i + 1, got);
          local_failures = local_failures + 1;
        end
      end
    end
  endtask

  task automatic pass_or_fail(input string name, input int local_failures);
    begin
      if (local_failures == 0) begin
        tests_passed = tests_passed + 1;
        $display("PASS %s", name);
      end else begin
        failures = failures + local_failures;
        $display("FAIL %s", name);
      end
    end
  endtask

  task automatic run_axi_lite_desc_regs_read_write;
    int local_failures;
    logic [31:0] data;
    begin
      local_failures = 0;
      axi_write(DMA_A_EXT_BASE, 32'h0000_0010);
      axi_write(DMA_B_EXT_BASE, 32'h0000_0020);
      axi_write(DMA_C_EXT_BASE, 32'h0000_0030);
      axi_write(DMA_CONFIG,     32'h0000_0040);
      axi_read(DMA_A_EXT_BASE, data);
      if (data !== 32'h0000_0010) begin
        $display("FAIL axi_lite_desc_regs_read_write: A base expected 0x00000010 actual 0x%08x", data);
        local_failures = local_failures + 1;
      end
      axi_read(DMA_B_EXT_BASE, data);
      if (data !== 32'h0000_0020) begin
        $display("FAIL axi_lite_desc_regs_read_write: B base expected 0x00000020 actual 0x%08x", data);
        local_failures = local_failures + 1;
      end
      axi_read(DMA_C_EXT_BASE, data);
      if (data !== 32'h0000_0030) begin
        $display("FAIL axi_lite_desc_regs_read_write: C base expected 0x00000030 actual 0x%08x", data);
        local_failures = local_failures + 1;
      end
      axi_read(DMA_CONFIG, data);
      if (data !== 32'h0000_0040) begin
        $display("FAIL axi_lite_desc_regs_read_write: config expected 0x00000040 actual 0x%08x", data);
        local_failures = local_failures + 1;
      end
      pass_or_fail("axi_lite_desc_regs_read_write", local_failures);
    end
  endtask

  task automatic run_axi_lite_forwarded_core_identity;
    int local_failures;
    begin
      load_core_identity();
      axi_write(ADDR_CTRL, 32'h1);
      wait_core_done();
      check_core_identity("axi_lite_forwarded_core_identity", local_failures);
      pass_or_fail("axi_lite_forwarded_core_identity", local_failures);
    end
  endtask

  task automatic run_axi_lite_dma_identity;
    int local_failures;
    int c_failures;
    begin
      local_failures = 0;
      clear_ext_mem(32'h0);
      fill_identity_case(EXT_A0_BASE, EXT_B0_BASE);
      start_dma(EXT_A0_BASE, EXT_B0_BASE, EXT_C0_BASE);
      wait_dma_done();
      check_ext_c("axi_lite_dma_identity", EXT_A0_BASE, EXT_B0_BASE, EXT_C0_BASE, c_failures);
      local_failures += c_failures;
      clear_dma_done_error();
      pass_or_fail("axi_lite_dma_identity", local_failures);
    end
  endtask

  task automatic run_axi_lite_dma_mixed_signed;
    int local_failures;
    int c_failures;
    begin
      local_failures = 0;
      clear_ext_mem(32'h0);
      fill_mixed_case(EXT_A1_BASE, EXT_B1_BASE);
      start_dma(EXT_A1_BASE, EXT_B1_BASE, EXT_C1_BASE);
      wait_dma_done();
      check_ext_c("axi_lite_dma_mixed_signed", EXT_A1_BASE, EXT_B1_BASE, EXT_C1_BASE, c_failures);
      local_failures += c_failures;
      clear_dma_done_error();
      pass_or_fail("axi_lite_dma_mixed_signed", local_failures);
    end
  endtask

  task automatic run_axi_lite_backpressure;
    int local_failures;
    logic [31:0] data;
    begin
      local_failures = 0;
      axi_write_stall(DMA_A_EXT_BASE, 32'h0000_0055, 4'hf, 3, 0, 5);
      axi_write_stall(DMA_B_EXT_BASE, 32'h0000_0066, 4'hf, 0, 4, 2);
      axi_read_stall(DMA_A_EXT_BASE, data, 3, 4);
      if (data !== 32'h0000_0055) local_failures++;
      axi_read_stall(DMA_B_EXT_BASE, data, 0, 5);
      if (data !== 32'h0000_0066) local_failures++;
      pass_or_fail("axi_lite_backpressure", local_failures);
    end
  endtask

  task automatic run_axi_lite_invalid_unaligned;
    int local_failures;
    logic [31:0] data;
    begin
      local_failures = 0;
      axi_write(DMA_A_EXT_BASE, 32'h1234_5678);
      axi_write(12'h118, 32'hffff_ffff);
      axi_read(12'h118, data);
      if (data !== 32'h0) local_failures++;
      axi_read(DMA_A_EXT_BASE, data);
      if (data !== 32'h1234_5678) local_failures++;
      axi_read(12'h011, data);
      if (data !== 32'h0) local_failures++;
      axi_write(12'h011, 32'hffff_ffff);
      axi_read(12'h200, data);
      if (data !== 32'h0) local_failures++;
      pass_or_fail("axi_lite_invalid_unaligned", local_failures);
    end
  endtask

  task automatic run_axi_lite_wstrb_behavior;
    int local_failures;
    logic [31:0] data;
    begin
      local_failures = 0;
      axi_write(DMA_CONFIG, 32'h1122_3344);
      axi_write_strb(DMA_CONFIG, 32'haabb_ccdd, 4'b0011);
      axi_read(DMA_CONFIG, data);
      if (data !== 32'h1122_3344) begin
        $display("FAIL axi_lite_wstrb_behavior: partial write changed register to 0x%08x", data);
        local_failures++;
      end
      axi_write_strb(DMA_CONFIG, 32'haabb_ccdd, 4'b1111);
      axi_read(DMA_CONFIG, data);
      if (data !== 32'haabb_ccdd) begin
        $display("FAIL axi_lite_wstrb_behavior: full write did not update register data=0x%08x", data);
        local_failures++;
      end
      pass_or_fail("axi_lite_wstrb_behavior", local_failures);
    end
  endtask

  initial begin
    $dumpfile("build/sim/axi_lite/tinynpu_axi_lite_wrapper.vcd");
    $dumpvars(0, tb_tinynpu_axi_lite_wrapper);

    failures = 0;
    tests_passed = 0;
    mem_wait_count = 0;
    mem_transaction_count = 0;
    mem_ready_q = 1'b0;

`ifdef TINYNPU_SIM_ASSERT
    $display("Memory-port assertions: enabled");
`else
    $display("Memory-port assertions: disabled");
`endif

    s_axi_awaddr  = '0;
    s_axi_awvalid = 1'b0;
    s_axi_wdata   = '0;
    s_axi_wstrb   = 4'h0;
    s_axi_wvalid  = 1'b0;
    s_axi_bready  = 1'b0;
    s_axi_araddr  = '0;
    s_axi_arvalid = 1'b0;
    s_axi_rready  = 1'b0;
    aresetn       = 1'b0;
    clear_ext_mem(32'h0);

    repeat (5) @(posedge aclk);
    aresetn = 1'b1;
    repeat (2) @(posedge aclk);

    run_axi_lite_desc_regs_read_write();
    run_axi_lite_forwarded_core_identity();
    run_axi_lite_dma_identity();
    run_axi_lite_dma_mixed_signed();
    run_axi_lite_backpressure();
    run_axi_lite_invalid_unaligned();
    run_axi_lite_wstrb_behavior();

    $display("AXI-Lite wrapper tests passed: %0d", tests_passed);
    if (failures == 0) begin
      $display("tinyNPU AXI-Lite wrapper SIM PASS");
      $finish;
    end else begin
      $display("tinyNPU AXI-Lite wrapper SIM FAIL failures=%0d", failures);
      $fatal(1);
    end
  end
endmodule
