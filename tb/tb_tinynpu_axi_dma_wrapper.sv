`timescale 1ns/1ps

import tinynpu_pkg::*;

module tb_tinynpu_axi_dma_wrapper;
  localparam logic [11:0] DMA_CTRL       = 12'h100;
  localparam logic [11:0] DMA_STATUS     = 12'h104;
  localparam logic [11:0] DMA_A_EXT_BASE = 12'h108;
  localparam logic [11:0] DMA_B_EXT_BASE = 12'h10c;
  localparam logic [11:0] DMA_C_EXT_BASE = 12'h110;
  localparam logic [11:0] DMA_CONFIG     = 12'h114;
  localparam logic [11:0] DMA_ERROR_CODE = 12'h118;
  localparam logic [11:0] DMA_IRQ_ENABLE = 12'h11c;
  localparam logic [11:0] DMA_IRQ_STATUS = 12'h120;

  localparam int EXT_MEM_WORDS = 256;
  localparam int EXT_A0_BASE = 0;
  localparam int EXT_B0_BASE = 32;
  localparam int EXT_C0_BASE = 64;
  localparam int EXT_A1_BASE = 96;
  localparam int EXT_B1_BASE = 128;
  localparam int EXT_C1_BASE = 160;

  localparam int READ_MODE_NORMAL = 0;
  localparam int READ_MODE_AR_BACKPRESSURE = 1;
  localparam int READ_MODE_RVALID_DELAY = 2;
  localparam int READ_MODE_RRESP_ERROR = 3;
  localparam int READ_MODE_TIMEOUT = 4;
  localparam int WRITE_MODE_NORMAL = 0;
  localparam int WRITE_MODE_AW_BACKPRESSURE = 1;
  localparam int WRITE_MODE_W_BACKPRESSURE = 2;
  localparam int WRITE_MODE_BVALID_DELAY = 3;
  localparam int WRITE_MODE_BRESP_ERROR = 4;
  localparam int WRITE_MODE_TIMEOUT = 5;

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
  logic [31:0] m_axi_araddr;
  logic [7:0]  m_axi_arlen;
  logic [2:0]  m_axi_arsize;
  logic [1:0]  m_axi_arburst;
  logic        m_axi_arvalid;
  logic        m_axi_arready;
  logic [31:0] m_axi_rdata;
  logic [1:0]  m_axi_rresp;
  logic        m_axi_rvalid;
  logic        m_axi_rready;
  logic        m_axi_rlast;
  logic [31:0] m_axi_awaddr;
  logic [7:0]  m_axi_awlen;
  logic [2:0]  m_axi_awsize;
  logic [1:0]  m_axi_awburst;
  logic        m_axi_awvalid;
  logic        m_axi_awready;
  logic [31:0] m_axi_wdata;
  logic [3:0]  m_axi_wstrb;
  logic        m_axi_wlast;
  logic        m_axi_wvalid;
  logic        m_axi_wready;
  logic [1:0]  m_axi_bresp;
  logic        m_axi_bvalid;
  logic        m_axi_bready;
  logic        irq;

  logic [31:0] ext_mem [0:EXT_MEM_WORDS-1];
  int failures;
  int tests_passed;
  int read_mode;
  int read_count;
  int ar_wait_count;
  int r_wait_count;
  int write_mode;
  int write_count;
  int aw_wait_count;
  int w_wait_count;
  int b_wait_count;
  logic [31:0] pending_araddr;
  logic [31:0] pending_awaddr;
  logic [31:0] pending_wdata;
  logic        read_pending;
  logic        write_addr_pending;
  logic        write_data_pending;
  logic        write_response_pending;
  logic        inject_error_used;
  logic        inject_write_error_used;

  tinynpu_axi_dma_wrapper dut (
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
    .m_axi_araddr  (m_axi_araddr),
    .m_axi_arlen   (m_axi_arlen),
    .m_axi_arsize  (m_axi_arsize),
    .m_axi_arburst (m_axi_arburst),
    .m_axi_arvalid (m_axi_arvalid),
    .m_axi_arready (m_axi_arready),
    .m_axi_rdata   (m_axi_rdata),
    .m_axi_rresp   (m_axi_rresp),
    .m_axi_rvalid  (m_axi_rvalid),
    .m_axi_rready  (m_axi_rready),
    .m_axi_rlast   (m_axi_rlast),
    .m_axi_awaddr  (m_axi_awaddr),
    .m_axi_awlen   (m_axi_awlen),
    .m_axi_awsize  (m_axi_awsize),
    .m_axi_awburst (m_axi_awburst),
    .m_axi_awvalid (m_axi_awvalid),
    .m_axi_awready (m_axi_awready),
    .m_axi_wdata   (m_axi_wdata),
    .m_axi_wstrb   (m_axi_wstrb),
    .m_axi_wlast   (m_axi_wlast),
    .m_axi_wvalid  (m_axi_wvalid),
    .m_axi_wready  (m_axi_wready),
    .m_axi_bresp   (m_axi_bresp),
    .m_axi_bvalid  (m_axi_bvalid),
    .m_axi_bready  (m_axi_bready),
    .irq           (irq)
  );

  initial begin
    aclk = 1'b0;
    forever #5 aclk = ~aclk;
  end

  always_ff @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
      m_axi_arready <= 1'b0;
      m_axi_rvalid <= 1'b0;
      m_axi_rdata <= 32'h0;
      m_axi_rresp <= 2'b00;
      m_axi_rlast <= 1'b0;
      read_count <= 0;
      ar_wait_count <= 0;
      r_wait_count <= 0;
      pending_araddr <= 32'h0;
      read_pending <= 1'b0;
      inject_error_used <= 1'b0;
    end else begin
      m_axi_arready <= 1'b0;
      if (m_axi_rvalid && m_axi_rready) begin
        m_axi_rvalid <= 1'b0;
        m_axi_rlast <= 1'b0;
        read_pending <= 1'b0;
        read_count <= read_count + 1;
      end

      if (m_axi_arvalid && !read_pending) begin
        if (read_mode == READ_MODE_TIMEOUT) begin
          m_axi_arready <= 1'b0;
        end else if ((read_mode == READ_MODE_AR_BACKPRESSURE) && (ar_wait_count < 3)) begin
          ar_wait_count <= ar_wait_count + 1;
        end else begin
          m_axi_arready <= 1'b1;
          pending_araddr <= m_axi_araddr;
          read_pending <= 1'b1;
          ar_wait_count <= 0;
          r_wait_count <= 0;
        end
      end

      if (read_pending && !m_axi_rvalid) begin
        if ((read_mode == READ_MODE_RVALID_DELAY) && (r_wait_count < 4)) begin
          r_wait_count <= r_wait_count + 1;
        end else begin
          m_axi_rvalid <= 1'b1;
          m_axi_rdata <= ext_mem[pending_araddr[9:2]];
          m_axi_rlast <= 1'b1;
          if ((read_mode == READ_MODE_RRESP_ERROR) && !inject_error_used && (read_count == 3)) begin
            m_axi_rresp <= 2'b10;
            inject_error_used <= 1'b1;
          end else begin
            m_axi_rresp <= 2'b00;
          end
        end
      end
    end
  end

  always_ff @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
      m_axi_awready <= 1'b0;
      m_axi_wready <= 1'b0;
      m_axi_bvalid <= 1'b0;
      m_axi_bresp <= 2'b00;
      write_count <= 0;
      aw_wait_count <= 0;
      w_wait_count <= 0;
      b_wait_count <= 0;
      pending_awaddr <= 32'h0;
      pending_wdata <= 32'h0;
      write_addr_pending <= 1'b0;
      write_data_pending <= 1'b0;
      write_response_pending <= 1'b0;
      inject_write_error_used <= 1'b0;
    end else begin
      m_axi_awready <= 1'b0;
      m_axi_wready <= 1'b0;

      if (m_axi_bvalid && m_axi_bready) begin
        m_axi_bvalid <= 1'b0;
        write_response_pending <= 1'b0;
        write_count <= write_count + 1;
      end

      if (m_axi_awvalid && !write_addr_pending && !write_response_pending) begin
        if (write_mode == WRITE_MODE_TIMEOUT) begin
          m_axi_awready <= 1'b0;
        end else if ((write_mode == WRITE_MODE_AW_BACKPRESSURE) && (aw_wait_count < 3)) begin
          aw_wait_count <= aw_wait_count + 1;
        end else begin
          m_axi_awready <= 1'b1;
          pending_awaddr <= m_axi_awaddr;
          write_addr_pending <= 1'b1;
          aw_wait_count <= 0;
        end
      end

      if (m_axi_wvalid && !write_data_pending && !write_response_pending) begin
        if (write_mode == WRITE_MODE_TIMEOUT) begin
          m_axi_wready <= 1'b0;
        end else if ((write_mode == WRITE_MODE_W_BACKPRESSURE) && (w_wait_count < 3)) begin
          w_wait_count <= w_wait_count + 1;
        end else begin
          m_axi_wready <= 1'b1;
          pending_wdata <= m_axi_wdata;
          write_data_pending <= 1'b1;
          w_wait_count <= 0;
        end
      end

      if (write_addr_pending && write_data_pending && !m_axi_bvalid) begin
        if ((write_mode == WRITE_MODE_BVALID_DELAY) && (b_wait_count < 4)) begin
          b_wait_count <= b_wait_count + 1;
        end else begin
          if (pending_awaddr[9:2] < EXT_MEM_WORDS) begin
            ext_mem[pending_awaddr[9:2]] <= pending_wdata;
          end
          m_axi_bvalid <= 1'b1;
          if ((write_mode == WRITE_MODE_BRESP_ERROR) && !inject_write_error_used && (write_count == 3)) begin
            m_axi_bresp <= 2'b10;
            inject_write_error_used <= 1'b1;
          end else begin
            m_axi_bresp <= 2'b00;
          end
          write_addr_pending <= 1'b0;
          write_data_pending <= 1'b0;
          write_response_pending <= 1'b1;
          b_wait_count <= 0;
        end
      end
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
      for (i = 0; i < EXT_MEM_WORDS; i = i + 1) ext_mem[i] = value;
    end
  endtask

  task automatic set_read_mode(input int mode);
    begin
      @(negedge aclk);
      read_mode = mode;
      read_count = 0;
      ar_wait_count = 0;
      r_wait_count = 0;
      read_pending = 1'b0;
      inject_error_used = 1'b0;
      repeat (2) @(posedge aclk);
    end
  endtask

  task automatic set_write_mode(input int mode);
    begin
      @(negedge aclk);
      write_mode = mode;
      write_count = 0;
      aw_wait_count = 0;
      w_wait_count = 0;
      b_wait_count = 0;
      write_addr_pending = 1'b0;
      write_data_pending = 1'b0;
      write_response_pending = 1'b0;
      inject_write_error_used = 1'b0;
      repeat (2) @(posedge aclk);
    end
  endtask

  task automatic axi_write(input logic [11:0] addr, input logic [31:0] data);
    begin
      @(negedge aclk);
      s_axi_awaddr <= addr;
      s_axi_awvalid <= 1'b1;
      s_axi_wdata <= data;
      s_axi_wstrb <= 4'hf;
      s_axi_wvalid <= 1'b1;
      @(posedge aclk);
      while (!s_axi_awready || !s_axi_wready) @(posedge aclk);
      @(negedge aclk);
      s_axi_awvalid <= 1'b0;
      s_axi_wvalid <= 1'b0;
      s_axi_awaddr <= '0;
      s_axi_wdata <= '0;
      s_axi_wstrb <= 4'h0;
      s_axi_bready <= 1'b1;
      @(posedge aclk);
      while (!s_axi_bvalid) @(posedge aclk);
      @(negedge aclk);
      s_axi_bready <= 1'b0;
    end
  endtask

  task automatic axi_read(input logic [11:0] addr, output logic [31:0] data);
    begin
      @(negedge aclk);
      s_axi_araddr <= addr;
      s_axi_arvalid <= 1'b1;
      @(posedge aclk);
      while (!s_axi_arready) @(posedge aclk);
      @(negedge aclk);
      s_axi_arvalid <= 1'b0;
      s_axi_araddr <= '0;
      s_axi_rready <= 1'b1;
      @(posedge aclk);
      while (!s_axi_rvalid) @(posedge aclk);
      #1;
      data = s_axi_rdata;
      @(negedge aclk);
      s_axi_rready <= 1'b0;
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

  task automatic wait_dma_done;
    logic [31:0] status;
    int timeout;
    begin
      timeout = 0;
      axi_read(DMA_STATUS, status);
      while ((status[1] !== 1'b1) && (timeout < 1500)) begin
        timeout = timeout + 1;
        axi_read(DMA_STATUS, status);
      end
      if (status[1] !== 1'b1) begin
        $display("FAIL wait_dma_done: status=0x%08x", status);
        failures++;
      end
    end
  endtask

  task automatic wait_dma_error;
    logic [31:0] status;
    int timeout;
    begin
      timeout = 0;
      axi_read(DMA_STATUS, status);
      while (((status[1] !== 1'b1) || (status[2] !== 1'b1)) && (timeout < 1500)) begin
        timeout = timeout + 1;
        axi_read(DMA_STATUS, status);
      end
      if ((status[1] !== 1'b1) || (status[2] !== 1'b1)) begin
        $display("FAIL wait_dma_error: status=0x%08x", status);
        failures++;
      end
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
          local_failures++;
        end
      end
    end
  endtask

  task automatic pass_or_fail(input string name, input int local_failures);
    begin
      if (local_failures == 0) begin
        tests_passed++;
        $display("PASS %s", name);
      end else begin
        failures += local_failures;
        $display("FAIL %s", name);
      end
      axi_write(DMA_CTRL, 32'h6);
      axi_write(DMA_IRQ_ENABLE, 32'h0);
      axi_write(DMA_CONFIG, 32'h0);
      set_read_mode(READ_MODE_NORMAL);
      set_write_mode(WRITE_MODE_NORMAL);
    end
  endtask

  task automatic run_success_case(input string name, input int read_mode_arg, input int write_mode_arg, input bit mixed);
    int local_failures;
    int c_failures;
    begin
      local_failures = 0;
      set_read_mode(read_mode_arg);
      set_write_mode(write_mode_arg);
      clear_ext_mem(32'h0);
      if (mixed) fill_mixed_case(EXT_A0_BASE, EXT_B0_BASE);
      else fill_identity_case(EXT_A0_BASE, EXT_B0_BASE);
      start_dma(EXT_A0_BASE, EXT_B0_BASE, EXT_C0_BASE);
      wait_dma_done();
      check_ext_c(name, EXT_A0_BASE, EXT_B0_BASE, EXT_C0_BASE, c_failures);
      local_failures += c_failures;
      pass_or_fail(name, local_failures);
    end
  endtask

  task automatic run_axi_dma_bresp_error;
    int local_failures;
    logic [31:0] status;
    logic [31:0] code;
    begin
      local_failures = 0;
      set_read_mode(READ_MODE_NORMAL);
      set_write_mode(WRITE_MODE_BRESP_ERROR);
      axi_write(DMA_IRQ_ENABLE, 32'h2);
      clear_ext_mem(32'h0);
      fill_identity_case(EXT_A0_BASE, EXT_B0_BASE);
      start_dma(EXT_A0_BASE, EXT_B0_BASE, EXT_C0_BASE);
      wait_dma_error();
      axi_read(DMA_STATUS, status);
      axi_read(DMA_ERROR_CODE, code);
      if (status[2] !== 1'b1 || code !== 32'd4 || irq !== 1'b1) local_failures++;
      pass_or_fail("axi_dma_bresp_error", local_failures);
    end
  endtask

  task automatic run_axi_dma_rresp_error;
    int local_failures;
    logic [31:0] status;
    logic [31:0] code;
    begin
      local_failures = 0;
      set_read_mode(READ_MODE_RRESP_ERROR);
      set_write_mode(WRITE_MODE_NORMAL);
      axi_write(DMA_IRQ_ENABLE, 32'h2);
      clear_ext_mem(32'h0);
      fill_identity_case(EXT_A0_BASE, EXT_B0_BASE);
      start_dma(EXT_A0_BASE, EXT_B0_BASE, EXT_C0_BASE);
      wait_dma_error();
      axi_read(DMA_STATUS, status);
      axi_read(DMA_ERROR_CODE, code);
      if (status[2] !== 1'b1 || code !== 32'd3 || irq !== 1'b1) local_failures++;
      pass_or_fail("axi_dma_rresp_error", local_failures);
    end
  endtask

  task automatic run_axi_dma_read_timeout;
    int local_failures;
    logic [31:0] status;
    logic [31:0] code;
    begin
      local_failures = 0;
      set_read_mode(READ_MODE_TIMEOUT);
      set_write_mode(WRITE_MODE_NORMAL);
      axi_write(DMA_CONFIG, 32'h0000_0008);
      clear_ext_mem(32'h0);
      fill_identity_case(EXT_A0_BASE, EXT_B0_BASE);
      start_dma(EXT_A0_BASE, EXT_B0_BASE, EXT_C0_BASE);
      wait_dma_error();
      axi_read(DMA_STATUS, status);
      axi_read(DMA_ERROR_CODE, code);
      if (status[2] !== 1'b1 || code !== 32'd1) local_failures++;
      pass_or_fail("axi_dma_read_timeout", local_failures);
    end
  endtask

  task automatic run_axi_dma_write_timeout;
    int local_failures;
    logic [31:0] status;
    logic [31:0] code;
    begin
      local_failures = 0;
      set_read_mode(READ_MODE_NORMAL);
      set_write_mode(WRITE_MODE_TIMEOUT);
      axi_write(DMA_CONFIG, 32'h0000_0008);
      clear_ext_mem(32'h0);
      fill_identity_case(EXT_A0_BASE, EXT_B0_BASE);
      start_dma(EXT_A0_BASE, EXT_B0_BASE, EXT_C0_BASE);
      wait_dma_error();
      axi_read(DMA_STATUS, status);
      axi_read(DMA_ERROR_CODE, code);
      if (status[2] !== 1'b1 || code !== 32'd1) local_failures++;
      pass_or_fail("axi_dma_write_timeout", local_failures);
    end
  endtask

  task automatic run_axi_dma_irq_done;
    int local_failures;
    logic [31:0] irq_status;
    begin
      local_failures = 0;
      set_read_mode(READ_MODE_NORMAL);
      set_write_mode(WRITE_MODE_NORMAL);
      axi_write(DMA_IRQ_ENABLE, 32'h1);
      clear_ext_mem(32'h0);
      fill_identity_case(EXT_A0_BASE, EXT_B0_BASE);
      start_dma(EXT_A0_BASE, EXT_B0_BASE, EXT_C0_BASE);
      wait_dma_done();
      axi_read(DMA_IRQ_STATUS, irq_status);
      if (irq !== 1'b1 || irq_status[0] !== 1'b1) local_failures++;
      axi_write(DMA_CTRL, 32'h2);
      if (irq !== 1'b0) local_failures++;
      pass_or_fail("axi_dma_irq_done", local_failures);
    end
  endtask

  initial begin
    $dumpfile("build/sim/axi_dma/tinynpu_axi_dma_wrapper.vcd");
    $dumpvars(0, tb_tinynpu_axi_dma_wrapper);
    failures = 0;
    tests_passed = 0;
    read_mode = READ_MODE_NORMAL;
    read_count = 0;
    ar_wait_count = 0;
    r_wait_count = 0;
    write_mode = WRITE_MODE_NORMAL;
    write_count = 0;
    aw_wait_count = 0;
    w_wait_count = 0;
    b_wait_count = 0;
    pending_araddr = 32'h0;
    pending_awaddr = 32'h0;
    pending_wdata = 32'h0;
    read_pending = 1'b0;
    write_addr_pending = 1'b0;
    write_data_pending = 1'b0;
    write_response_pending = 1'b0;
    inject_error_used = 1'b0;
    inject_write_error_used = 1'b0;
    m_axi_arready = 1'b0;
    m_axi_rvalid = 1'b0;
    m_axi_rdata = 32'h0;
    m_axi_rresp = 2'b00;
    m_axi_rlast = 1'b0;
    m_axi_awready = 1'b0;
    m_axi_wready = 1'b0;
    m_axi_bresp = 2'b00;
    m_axi_bvalid = 1'b0;
    s_axi_awaddr = '0;
    s_axi_awvalid = 1'b0;
    s_axi_wdata = '0;
    s_axi_wstrb = 4'h0;
    s_axi_wvalid = 1'b0;
    s_axi_bready = 1'b0;
    s_axi_araddr = '0;
    s_axi_arvalid = 1'b0;
    s_axi_rready = 1'b0;
    aresetn = 1'b0;
    clear_ext_mem(32'h0);
    repeat (5) @(posedge aclk);
    aresetn = 1'b1;
    repeat (2) @(posedge aclk);

    run_success_case("axi_dma_identity", READ_MODE_NORMAL, WRITE_MODE_NORMAL, 1'b0);
    run_success_case("axi_dma_mixed_signed", READ_MODE_NORMAL, WRITE_MODE_NORMAL, 1'b1);
    run_success_case("axi_dma_ar_backpressure", READ_MODE_AR_BACKPRESSURE, WRITE_MODE_NORMAL, 1'b0);
    run_success_case("axi_dma_rvalid_delay", READ_MODE_RVALID_DELAY, WRITE_MODE_NORMAL, 1'b1);
    run_success_case("axi_dma_aw_backpressure", READ_MODE_NORMAL, WRITE_MODE_AW_BACKPRESSURE, 1'b0);
    run_success_case("axi_dma_w_backpressure", READ_MODE_NORMAL, WRITE_MODE_W_BACKPRESSURE, 1'b1);
    run_success_case("axi_dma_bvalid_delay", READ_MODE_NORMAL, WRITE_MODE_BVALID_DELAY, 1'b0);
    run_axi_dma_rresp_error();
    run_axi_dma_read_timeout();
    run_axi_dma_bresp_error();
    run_axi_dma_write_timeout();
    run_axi_dma_irq_done();

    $display("AXI DMA tests passed: %0d", tests_passed);
    if (failures == 0) begin
      $display("tinyNPU AXI DMA wrapper SIM PASS");
      $finish;
    end else begin
      $display("tinyNPU AXI DMA wrapper SIM FAIL failures=%0d", failures);
      $fatal(1);
    end
  end
endmodule
