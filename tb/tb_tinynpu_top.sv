`timescale 1ns/1ps

import tinynpu_pkg::*;

module tb_tinynpu_top;
  localparam logic [7:0] ADDR_CTRL   = 8'h00;
  localparam logic [7:0] ADDR_STATUS = 8'h04;
  localparam logic [7:0] ADDR_A_BASE = 8'h10;
  localparam logic [7:0] ADDR_B_BASE = 8'h50;
  localparam logic [7:0] ADDR_C_BASE = 8'h90;
  localparam int MAX_OPERATION_CYCLES = 200;

  logic        clk;
  logic        rst_n;
  logic        bus_valid;
  logic        bus_we;
  logic [7:0]  bus_addr;
  logic [31:0] bus_wdata;
  logic [31:0] bus_rdata;
  logic        bus_ready;

  int failures;
  int directed_tests_passed;
  int generated_tests_passed;
  int max_observed_latency;
  int current_latency_cycles;
  int last_latency_cycles;
  bit latency_pending;
  bit in_generated_tests;
  logic [DATA_W*MATRIX_ELEMS-1:0] active_a_values;
  logic [DATA_W*MATRIX_ELEMS-1:0] active_b_values;

  tinynpu_top dut (
    .clk       (clk),
    .rst_n     (rst_n),
    .bus_valid (bus_valid),
    .bus_we    (bus_we),
    .bus_addr  (bus_addr),
    .bus_wdata (bus_wdata),
    .bus_rdata (bus_rdata),
    .bus_ready (bus_ready)
  );

  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_latency_cycles <= 0;
    end else if (latency_pending) begin
      current_latency_cycles <= current_latency_cycles + 1;
    end
  end

  function automatic logic [31:0] pack_i8(input int value);
    begin
      pack_i8 = {{24{value[7]}}, value[7:0]};
    end
  endfunction

  function automatic logic [31:0] pack_i32(input int value);
    begin
      pack_i32 = value[31:0];
    end
  endfunction

  task automatic bus_write(input logic [7:0] addr, input logic [31:0] data);
    begin
      @(negedge clk);
      bus_valid <= 1'b1;
      bus_we    <= 1'b1;
      bus_addr  <= addr;
      bus_wdata <= data;
      @(posedge clk);
      while (!bus_ready) begin
        @(posedge clk);
      end
      bus_valid <= 1'b0;
      bus_we    <= 1'b0;
      bus_addr  <= '0;
      bus_wdata <= '0;
    end
  endtask

  task automatic bus_read(input logic [7:0] addr, output logic [31:0] data);
    begin
      @(negedge clk);
      bus_valid <= 1'b1;
      bus_we    <= 1'b0;
      bus_addr  <= addr;
      bus_wdata <= '0;
      @(posedge clk);
      while (!bus_ready) begin
        @(posedge clk);
      end
      #1;
      data = bus_rdata;
      bus_valid <= 1'b0;
      bus_addr  <= '0;
    end
  endtask

  task automatic clear_done;
    begin
      bus_write(ADDR_CTRL, 32'h2);
    end
  endtask

  task automatic start_accel;
    begin
      bus_write(ADDR_CTRL, 32'h1);
`ifdef TINYNPU_SIM_ASSERT
      #1;
      if (dut.debug_start_accepted) begin
        latency_pending = 1'b1;
        current_latency_cycles = 0;
      end
`else
      latency_pending = 1'b1;
      current_latency_cycles = 0;
`endif
    end
  endtask

  task automatic wait_done;
    logic [31:0] status;
    int timeout;
    begin
      last_latency_cycles = -1;
      if (latency_pending) begin
`ifdef TINYNPU_SIM_ASSERT
        while ((dut.done_q !== 1'b1) && (current_latency_cycles <= MAX_OPERATION_CYCLES)) begin
          @(posedge clk);
        end
`else
        int cycles;
        cycles = 0;
        bus_read(ADDR_STATUS, status);
        while ((status[1] !== 1'b1) && (cycles <= MAX_OPERATION_CYCLES)) begin
          cycles = cycles + 1;
          bus_read(ADDR_STATUS, status);
        end
        current_latency_cycles = cycles;
`endif
        last_latency_cycles = current_latency_cycles;
        if (current_latency_cycles > max_observed_latency) begin
          max_observed_latency = current_latency_cycles;
        end
        if (current_latency_cycles > MAX_OPERATION_CYCLES) begin
          $display("FAIL wait_done: operation exceeded %0d cycles", MAX_OPERATION_CYCLES);
          failures = failures + 1;
        end
        latency_pending = 1'b0;
      end

      timeout = 0;
      bus_read(ADDR_STATUS, status);
      while ((status[1] !== 1'b1) && (timeout <= 200)) begin
        timeout = timeout + 1;
        bus_read(ADDR_STATUS, status);
      end
      if (status[1] !== 1'b1) begin
        $display("FAIL wait_done: timed out, status=0x%08x", status);
        failures = failures + 1;
      end
    end
  endtask

  task automatic wait_busy;
    logic [31:0] status;
    int timeout;
    begin
      timeout = 0;
      bus_read(ADDR_STATUS, status);
      while ((status[0] !== 1'b1) && (timeout <= 20)) begin
        timeout = timeout + 1;
        bus_read(ADDR_STATUS, status);
      end
      if (status[0] !== 1'b1) begin
        $display("FAIL wait_busy: timed out, status=0x%08x", status);
        failures = failures + 1;
      end
    end
  endtask

  function automatic int signed get_i8_from_flat(
    input logic [DATA_W*MATRIX_ELEMS-1:0] values,
    input int idx
  );
    begin
      get_i8_from_flat = $signed(values[idx*DATA_W +: DATA_W]);
    end
  endfunction

  task automatic print_flat_i8(
    input string label_text,
    input logic [DATA_W*MATRIX_ELEMS-1:0] values
  );
    int i;
    begin
      $write("%s:", label_text);
      for (i = 0; i < MATRIX_ELEMS; i = i + 1) begin
        $write(" %0d", get_i8_from_flat(values, i));
      end
      $write("\n");
    end
  endtask

  task automatic write_matrix_a(input logic [DATA_W*MATRIX_ELEMS-1:0] values);
    int i;
    begin
      for (i = 0; i < MATRIX_ELEMS; i = i + 1) begin
        bus_write(ADDR_A_BASE + (i * 4), pack_i8($signed(values[i*DATA_W +: DATA_W])));
      end
    end
  endtask

  task automatic write_matrix_b(input logic [DATA_W*MATRIX_ELEMS-1:0] values);
    int i;
    begin
      for (i = 0; i < MATRIX_ELEMS; i = i + 1) begin
        bus_write(ADDR_B_BASE + (i * 4), pack_i8($signed(values[i*DATA_W +: DATA_W])));
      end
    end
  endtask

  task automatic read_and_check_c(
    input string test_name,
    input logic [C_FLAT_W-1:0] expected
  );
    int i;
    int test_failures;
    int signed got;
    int signed exp;
    logic [31:0] data;
    begin
      test_failures = 0;
      for (i = 0; i < MATRIX_ELEMS; i = i + 1) begin
        bus_read(ADDR_C_BASE + (i * 4), data);
        got = $signed(data);
        exp = $signed(expected[i*ACC_W +: ACC_W]);
        if (got !== exp) begin
          $display("FAIL %s: C[%0d] expected %0d actual %0d", test_name, i, exp, got);
          if (test_failures == 0) begin
            print_flat_i8("  A_flat", active_a_values);
            print_flat_i8("  B_flat", active_b_values);
          end
          failures = failures + 1;
          test_failures = test_failures + 1;
        end
      end

      if (test_failures == 0) begin
        if (in_generated_tests) begin
          generated_tests_passed = generated_tests_passed + 1;
          $display("PASS %s", test_name);
        end else begin
          directed_tests_passed = directed_tests_passed + 1;
          if (last_latency_cycles >= 0) begin
            $display("PASS %s latency=%0d cycles", test_name, last_latency_cycles);
          end else begin
            $display("PASS %s", test_name);
          end
        end
      end
    end
  endtask

  task automatic run_accel_and_check(
    input string test_name,
    input logic [DATA_W*MATRIX_ELEMS-1:0] a_values,
    input logic [DATA_W*MATRIX_ELEMS-1:0] b_values,
    input logic [C_FLAT_W-1:0] expected
  );
    begin
      active_a_values = a_values;
      active_b_values = b_values;
      write_matrix_a(a_values);
      write_matrix_b(b_values);
      start_accel();
      wait_done();
      read_and_check_c(test_name, expected);
      clear_done();
    end
  endtask

  task automatic set_i8(
    inout logic [DATA_W*MATRIX_ELEMS-1:0] values,
    input int idx,
    input int value
  );
    begin
      values[idx*DATA_W +: DATA_W] = value[DATA_W-1:0];
    end
  endtask

  task automatic set_i32(
    inout logic [C_FLAT_W-1:0] values,
    input int idx,
    input int value
  );
    begin
      values[idx*ACC_W +: ACC_W] = pack_i32(value);
    end
  endtask

  `include "tests/test_vectors/generated_matmul_tests.svh"

  task automatic run_identity_test;
    logic [DATA_W*MATRIX_ELEMS-1:0] a_values;
    logic [DATA_W*MATRIX_ELEMS-1:0] b_values;
    logic [C_FLAT_W-1:0] expected;
    int i;
    begin
      a_values = '0;
      b_values = '0;
      expected = '0;
      for (i = 0; i < MATRIX_N; i = i + 1) begin
        set_i8(a_values, i*MATRIX_N + i, 1);
      end
      for (i = 0; i < MATRIX_ELEMS; i = i + 1) begin
        set_i8(b_values, i, i + 1);
        set_i32(expected, i, i + 1);
      end
      run_accel_and_check("identity", a_values, b_values, expected);
    end
  endtask

  task automatic run_zero_test;
    logic [DATA_W*MATRIX_ELEMS-1:0] a_values;
    logic [DATA_W*MATRIX_ELEMS-1:0] b_values;
    logic [C_FLAT_W-1:0] expected;
    int i;
    begin
      a_values = '0;
      b_values = '0;
      expected = '0;
      for (i = 0; i < MATRIX_ELEMS; i = i + 1) begin
        set_i8(b_values, i, i - 8);
      end
      run_accel_and_check("all_zeros", a_values, b_values, expected);
    end
  endtask

  task automatic run_ones_test;
    logic [DATA_W*MATRIX_ELEMS-1:0] a_values;
    logic [DATA_W*MATRIX_ELEMS-1:0] b_values;
    logic [C_FLAT_W-1:0] expected;
    int i;
    begin
      a_values = '0;
      b_values = '0;
      expected = '0;
      for (i = 0; i < MATRIX_ELEMS; i = i + 1) begin
        set_i8(a_values, i, 1);
        set_i8(b_values, i, 1);
        set_i32(expected, i, 4);
      end
      run_accel_and_check("all_ones", a_values, b_values, expected);
    end
  endtask

  task automatic run_mixed_test;
    logic [DATA_W*MATRIX_ELEMS-1:0] a_values;
    logic [DATA_W*MATRIX_ELEMS-1:0] b_values;
    logic [C_FLAT_W-1:0] expected;
    begin
      build_mixed(a_values, b_values, expected);
      run_accel_and_check("mixed_signed", a_values, b_values, expected);
    end
  endtask

  task automatic build_mixed(
    output logic [DATA_W*MATRIX_ELEMS-1:0] a_values,
    output logic [DATA_W*MATRIX_ELEMS-1:0] b_values,
    output logic [C_FLAT_W-1:0] expected
  );
    begin
      a_values = '0;
      b_values = '0;
      expected = '0;

      set_i8(a_values, 0,   1); set_i8(a_values, 1,  -2);
      set_i8(a_values, 2,   3); set_i8(a_values, 3,  -4);
      set_i8(a_values, 4,   5); set_i8(a_values, 5,   6);
      set_i8(a_values, 6,  -7); set_i8(a_values, 7,   8);
      set_i8(a_values, 8,  -9); set_i8(a_values, 9,  10);
      set_i8(a_values, 10, 11); set_i8(a_values, 11, -12);
      set_i8(a_values, 12, 13); set_i8(a_values, 13, -14);
      set_i8(a_values, 14, 15); set_i8(a_values, 15,  16);

      set_i8(b_values, 0,  -1); set_i8(b_values, 1,   2);
      set_i8(b_values, 2,  -3); set_i8(b_values, 3,   4);
      set_i8(b_values, 4,   5); set_i8(b_values, 5,  -6);
      set_i8(b_values, 6,   7); set_i8(b_values, 7,  -8);
      set_i8(b_values, 8,   9); set_i8(b_values, 9,  10);
      set_i8(b_values, 10, -11); set_i8(b_values, 11, 12);
      set_i8(b_values, 12, -13); set_i8(b_values, 13, 14);
      set_i8(b_values, 14, 15); set_i8(b_values, 15, -16);

      set_i32(expected, 0,   68); set_i32(expected, 1,  -12);
      set_i32(expected, 2,  -110); set_i32(expected, 3,  120);
      set_i32(expected, 4,  -142); set_i32(expected, 5,   16);
      set_i32(expected, 6,   224); set_i32(expected, 7, -240);
      set_i32(expected, 8,   314); set_i32(expected, 9, -136);
      set_i32(expected, 10, -204); set_i32(expected, 11, 208);
      set_i32(expected, 12, -156); set_i32(expected, 13, 484);
      set_i32(expected, 14,  -62); set_i32(expected, 15,  88);
    end
  endtask

  task automatic build_identity(
    output logic [DATA_W*MATRIX_ELEMS-1:0] a_values,
    output logic [DATA_W*MATRIX_ELEMS-1:0] b_values,
    output logic [C_FLAT_W-1:0] expected
  );
    int i;
    begin
      a_values = '0;
      b_values = '0;
      expected = '0;
      for (i = 0; i < MATRIX_N; i = i + 1) begin
        set_i8(a_values, i*MATRIX_N + i, 1);
      end
      for (i = 0; i < MATRIX_ELEMS; i = i + 1) begin
        set_i8(b_values, i, i + 1);
        set_i32(expected, i, i + 1);
      end
    end
  endtask

  task automatic run_max_positive_test;
    logic [DATA_W*MATRIX_ELEMS-1:0] a_values;
    logic [DATA_W*MATRIX_ELEMS-1:0] b_values;
    logic [C_FLAT_W-1:0] expected;
    int i;
    begin
      a_values = '0;
      b_values = '0;
      expected = '0;
      for (i = 0; i < MATRIX_ELEMS; i = i + 1) begin
        set_i8(a_values, i, 127);
        set_i8(b_values, i, 127);
        set_i32(expected, i, 64516);
      end
      run_accel_and_check("max_positive", a_values, b_values, expected);
    end
  endtask

  task automatic run_min_negative_times_positive_test;
    logic [DATA_W*MATRIX_ELEMS-1:0] a_values;
    logic [DATA_W*MATRIX_ELEMS-1:0] b_values;
    logic [C_FLAT_W-1:0] expected;
    int i;
    begin
      a_values = '0;
      b_values = '0;
      expected = '0;
      for (i = 0; i < MATRIX_ELEMS; i = i + 1) begin
        set_i8(a_values, i, -128);
        set_i8(b_values, i, 127);
        set_i32(expected, i, -65024);
      end
      run_accel_and_check("min_negative_times_positive", a_values, b_values, expected);
    end
  endtask

  task automatic run_alternating_extremes_test;
    logic [DATA_W*MATRIX_ELEMS-1:0] a_values;
    logic [DATA_W*MATRIX_ELEMS-1:0] b_values;
    logic [C_FLAT_W-1:0] expected;
    int i;
    begin
      a_values = '0;
      b_values = '0;
      expected = '0;
      for (i = 0; i < MATRIX_ELEMS; i = i + 1) begin
        if ((i % 2) == 0) begin
          set_i8(a_values, i, 127);
          set_i8(b_values, i, 127);
          set_i32(expected, i, -254);
        end else begin
          set_i8(a_values, i, -128);
          set_i8(b_values, i, -128);
          set_i32(expected, i, 256);
        end
      end
      run_accel_and_check("alternating_extremes", a_values, b_values, expected);
    end
  endtask

  task automatic run_sparse_single_nonzero_test;
    logic [DATA_W*MATRIX_ELEMS-1:0] a_values;
    logic [DATA_W*MATRIX_ELEMS-1:0] b_values;
    logic [C_FLAT_W-1:0] expected;
    begin
      a_values = '0;
      b_values = '0;
      expected = '0;
      set_i8(a_values, 6, -128);
      set_i8(b_values, 11, 127);
      set_i32(expected, 7, -16256);
      run_accel_and_check("sparse_single_nonzero", a_values, b_values, expected);
    end
  endtask

  task automatic run_back_to_back_test;
    logic [DATA_W*MATRIX_ELEMS-1:0] a_identity;
    logic [DATA_W*MATRIX_ELEMS-1:0] b_identity;
    logic [C_FLAT_W-1:0] expected_identity;
    logic [DATA_W*MATRIX_ELEMS-1:0] a_mixed;
    logic [DATA_W*MATRIX_ELEMS-1:0] b_mixed;
    logic [C_FLAT_W-1:0] expected_mixed;
    int i;
    begin
      a_identity = '0;
      b_identity = '0;
      expected_identity = '0;
      for (i = 0; i < MATRIX_N; i = i + 1) begin
        set_i8(a_identity, i*MATRIX_N + i, 1);
      end
      for (i = 0; i < MATRIX_ELEMS; i = i + 1) begin
        set_i8(b_identity, i, i + 1);
        set_i32(expected_identity, i, i + 1);
      end

      build_mixed(a_mixed, b_mixed, expected_mixed);

      write_matrix_a(a_identity);
      write_matrix_b(b_identity);
      start_accel();
      wait_done();
      read_and_check_c("back_to_back_first", expected_identity);
      clear_done();

      write_matrix_a(a_mixed);
      write_matrix_b(b_mixed);
      start_accel();
      wait_done();
      read_and_check_c("back_to_back_second", expected_mixed);
      clear_done();
    end
  endtask

  task automatic run_start_while_busy_test;
    logic [DATA_W*MATRIX_ELEMS-1:0] a_values;
    logic [DATA_W*MATRIX_ELEMS-1:0] b_values;
    logic [C_FLAT_W-1:0] expected;
    begin
      build_mixed(a_values, b_values, expected);
      active_a_values = a_values;
      active_b_values = b_values;
      write_matrix_a(a_values);
      write_matrix_b(b_values);
      start_accel();
      wait_busy();
      start_accel();
      wait_done();
      read_and_check_c("start_while_busy", expected);
      clear_done();
    end
  endtask

  task automatic run_done_sticky_clear_test;
    logic [DATA_W*MATRIX_ELEMS-1:0] a_values;
    logic [DATA_W*MATRIX_ELEMS-1:0] b_values;
    logic [C_FLAT_W-1:0] expected;
    logic [31:0] status;
    int local_failures;
    int i;
    begin
      local_failures = 0;
      build_identity(a_values, b_values, expected);
      write_matrix_a(a_values);
      write_matrix_b(b_values);
      start_accel();
      wait_done();

      for (i = 0; i < 4; i = i + 1) begin
        bus_read(ADDR_STATUS, status);
        if (status[1] !== 1'b1) begin
          $display("FAIL done_sticky_clear: done dropped before clear, status=0x%08x", status);
          failures = failures + 1;
          local_failures = local_failures + 1;
        end
      end

      clear_done();
      bus_read(ADDR_STATUS, status);
      if (status[1] !== 1'b0) begin
        $display("FAIL done_sticky_clear: done stayed high after clear, status=0x%08x", status);
        failures = failures + 1;
        local_failures = local_failures + 1;
      end

      if (local_failures == 0) begin
        directed_tests_passed = directed_tests_passed + 1;
        if (last_latency_cycles >= 0) begin
          $display("PASS done_sticky_clear latency=%0d cycles", last_latency_cycles);
        end else begin
          $display("PASS done_sticky_clear");
        end
      end
    end
  endtask

  task automatic run_new_start_after_done_test;
    logic [DATA_W*MATRIX_ELEMS-1:0] a_first;
    logic [DATA_W*MATRIX_ELEMS-1:0] b_first;
    logic [C_FLAT_W-1:0] expected_first;
    logic [DATA_W*MATRIX_ELEMS-1:0] a_second;
    logic [DATA_W*MATRIX_ELEMS-1:0] b_second;
    logic [C_FLAT_W-1:0] expected_second;
    logic [31:0] status;
    int local_failures;
    begin
      local_failures = 0;
      build_identity(a_first, b_first, expected_first);
      build_mixed(a_second, b_second, expected_second);

      write_matrix_a(a_first);
      write_matrix_b(b_first);
      start_accel();
      wait_done();

      write_matrix_a(a_second);
      write_matrix_b(b_second);
      active_a_values = a_second;
      active_b_values = b_second;
      start_accel();
      bus_read(ADDR_STATUS, status);
      if (status[1] !== 1'b0) begin
        $display("FAIL new_start_after_done: done did not clear on new start, status=0x%08x", status);
        failures = failures + 1;
        local_failures = local_failures + 1;
      end

      wait_done();
      read_and_check_c("new_start_after_done", expected_second);
      clear_done();
    end
  endtask

  task automatic run_reset_mid_operation_test;
    logic [DATA_W*MATRIX_ELEMS-1:0] a_values;
    logic [DATA_W*MATRIX_ELEMS-1:0] b_values;
    logic [C_FLAT_W-1:0] expected;
    logic [31:0] status;
    int local_failures;
    begin
      local_failures = 0;
      build_mixed(a_values, b_values, expected);
      write_matrix_a(a_values);
      write_matrix_b(b_values);
      start_accel();
      wait_busy();

      @(negedge clk);
      rst_n <= 1'b0;
      bus_valid <= 1'b0;
      bus_we <= 1'b0;
      bus_addr <= '0;
      bus_wdata <= '0;
      repeat (4) @(posedge clk);
      @(negedge clk);
      rst_n <= 1'b1;
      repeat (2) @(posedge clk);

      bus_read(ADDR_STATUS, status);
      if (status[0] !== 1'b0 || status[1] !== 1'b0) begin
        $display("FAIL reset_mid_operation: expected busy=0 done=0 after reset, status=0x%08x", status);
        failures = failures + 1;
        local_failures = local_failures + 1;
      end

      build_identity(a_values, b_values, expected);
      write_matrix_a(a_values);
      write_matrix_b(b_values);
      start_accel();
      wait_done();
      active_a_values = a_values;
      active_b_values = b_values;
      read_and_check_c("reset_mid_operation", expected);
      clear_done();
    end
  endtask

  task automatic run_invalid_bus_access_test;
    logic [DATA_W*MATRIX_ELEMS-1:0] a_values;
    logic [DATA_W*MATRIX_ELEMS-1:0] b_values;
    logic [C_FLAT_W-1:0] expected;
    logic [31:0] data;
    int local_failures;
    begin
      local_failures = 0;
      bus_read(8'h08, data);
      if (data !== 32'h0) begin
        $display("FAIL invalid_bus_access: read 0x08 returned 0x%08x expected 0", data);
        failures = failures + 1;
        local_failures = local_failures + 1;
      end
      bus_read(8'hd0, data);
      if (data !== 32'h0) begin
        $display("FAIL invalid_bus_access: read 0xd0 returned 0x%08x expected 0", data);
        failures = failures + 1;
        local_failures = local_failures + 1;
      end

      bus_write(8'h08, 32'hdead_beef);
      bus_write(8'hd0, 32'h1234_5678);

      build_identity(a_values, b_values, expected);
      active_a_values = a_values;
      active_b_values = b_values;
      write_matrix_a(a_values);
      write_matrix_b(b_values);
      bus_write(8'h08, 32'hffff_ffff);
      start_accel();
      wait_done();
      read_and_check_c("invalid_bus_access", expected);
      clear_done();
    end
  endtask

  task automatic run_generated_tests;
    logic [DATA_W*MATRIX_ELEMS-1:0] a_values;
    logic [DATA_W*MATRIX_ELEMS-1:0] b_values;
    logic [C_FLAT_W-1:0] expected;
    string test_name;
    int i;
    begin
      in_generated_tests = 1'b1;
      for (i = 0; i < NUM_GENERATED_TESTS; i = i + 1) begin
        load_generated_test(i, a_values, b_values, expected);
        test_name = $sformatf("generated_random_%0d", i);
        run_accel_and_check(test_name, a_values, b_values, expected);
      end
      in_generated_tests = 1'b0;
      $display("Generated random tests run: %0d", NUM_GENERATED_TESTS);
    end
  endtask

  initial begin
    $dumpfile("build/tinynpu_top.vcd");
    $dumpvars(0, tb_tinynpu_top);

    failures = 0;
    directed_tests_passed = 0;
    generated_tests_passed = 0;
    max_observed_latency = 0;
    current_latency_cycles = 0;
    last_latency_cycles = -1;
    latency_pending = 1'b0;
    in_generated_tests = 1'b0;
    rst_n = 1'b0;
    bus_valid = 1'b0;
    bus_we = 1'b0;
    bus_addr = '0;
    bus_wdata = '0;

    repeat (4) @(posedge clk);
    rst_n = 1'b1;
    repeat (2) @(posedge clk);

    run_identity_test();
    run_zero_test();
    run_ones_test();
    run_mixed_test();
    run_max_positive_test();
    run_min_negative_times_positive_test();
    run_alternating_extremes_test();
    run_sparse_single_nonzero_test();
    run_back_to_back_test();
    run_start_while_busy_test();
    run_done_sticky_clear_test();
    run_new_start_after_done_test();
    run_reset_mid_operation_test();
    run_invalid_bus_access_test();
    run_generated_tests();

    if (failures == 0) begin
      $display("Directed tests passed: %0d", directed_tests_passed);
      $display("Generated random tests passed: %0d", generated_tests_passed);
      $display("Max observed latency: %0d cycles", max_observed_latency);
      $display("Assertions/checkers: enabled");
      $display("tinyNPU SIM PASS");
      $finish;
    end else begin
      $display("tinyNPU SIM FAIL: %0d mismatches", failures);
      $fatal(1);
    end
  end
endmodule
