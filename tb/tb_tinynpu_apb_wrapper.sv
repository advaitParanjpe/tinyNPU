`timescale 1ns/1ps

import tinynpu_pkg::*;

module tb_tinynpu_apb_wrapper;
  localparam logic [7:0] ADDR_CTRL   = 8'h00;
  localparam logic [7:0] ADDR_STATUS = 8'h04;
  localparam logic [7:0] ADDR_A_BASE = 8'h10;
  localparam logic [7:0] ADDR_B_BASE = 8'h50;
  localparam logic [7:0] ADDR_C_BASE = 8'h90;

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

  function automatic logic [31:0] pack_i32(input int value);
    begin
      pack_i32 = value[31:0];
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

  task automatic write_matrix_a(input logic [DATA_W*MATRIX_ELEMS-1:0] values);
    int i;
    begin
      for (i = 0; i < MATRIX_ELEMS; i = i + 1) begin
        apb_write(ADDR_A_BASE + (i * 4), pack_i8($signed(values[i*DATA_W +: DATA_W])));
      end
    end
  endtask

  task automatic write_matrix_b(input logic [DATA_W*MATRIX_ELEMS-1:0] values);
    int i;
    begin
      for (i = 0; i < MATRIX_ELEMS; i = i + 1) begin
        apb_write(ADDR_B_BASE + (i * 4), pack_i8($signed(values[i*DATA_W +: DATA_W])));
      end
    end
  endtask

  task automatic apb_start;
    begin
      apb_write(ADDR_CTRL, 32'h1);
    end
  endtask

  task automatic apb_clear_done;
    begin
      apb_write(ADDR_CTRL, 32'h2);
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

  task automatic apb_wait_busy;
    logic [31:0] status;
    int timeout;
    begin
      timeout = 0;
      apb_read(ADDR_STATUS, status);
      while ((status[0] !== 1'b1) && (timeout < 20)) begin
        timeout = timeout + 1;
        apb_read(ADDR_STATUS, status);
      end
      if (status[0] !== 1'b1) begin
        $display("FAIL apb_wait_busy: timed out status=0x%08x", status);
        failures = failures + 1;
      end
    end
  endtask

  task automatic read_and_check_c(input string test_name, input logic [C_FLAT_W-1:0] expected);
    int i;
    int local_failures;
    int signed got;
    int signed exp;
    logic [31:0] data;
    begin
      local_failures = 0;
      for (i = 0; i < MATRIX_ELEMS; i = i + 1) begin
        apb_read(ADDR_C_BASE + (i * 4), data);
        got = $signed(data);
        exp = $signed(expected[i*ACC_W +: ACC_W]);
        if (got !== exp) begin
          $display("FAIL %s: C[%0d] expected %0d actual %0d", test_name, i, exp, got);
          failures = failures + 1;
          local_failures = local_failures + 1;
        end
      end
      if (local_failures == 0) begin
        tests_passed = tests_passed + 1;
        $display("PASS %s", test_name);
      end
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

  task automatic run_matmul_case(
    input string test_name,
    input logic [DATA_W*MATRIX_ELEMS-1:0] a_values,
    input logic [DATA_W*MATRIX_ELEMS-1:0] b_values,
    input logic [C_FLAT_W-1:0] expected
  );
    begin
      write_matrix_a(a_values);
      write_matrix_b(b_values);
      apb_start();
      apb_wait_done();
      read_and_check_c(test_name, expected);
      apb_clear_done();
    end
  endtask

  task automatic run_identity_test;
    logic [DATA_W*MATRIX_ELEMS-1:0] a_values;
    logic [DATA_W*MATRIX_ELEMS-1:0] b_values;
    logic [C_FLAT_W-1:0] expected;
    begin
      build_identity(a_values, b_values, expected);
      run_matmul_case("apb_identity", a_values, b_values, expected);
    end
  endtask

  task automatic run_mixed_test;
    logic [DATA_W*MATRIX_ELEMS-1:0] a_values;
    logic [DATA_W*MATRIX_ELEMS-1:0] b_values;
    logic [C_FLAT_W-1:0] expected;
    begin
      build_mixed(a_values, b_values, expected);
      run_matmul_case("apb_mixed_signed", a_values, b_values, expected);
    end
  endtask

  task automatic run_invalid_unaligned_test;
    logic [31:0] data;
    int local_failures;
    begin
      local_failures = 0;
      apb_read(8'h08, data);
      if (data !== 32'h0) begin
        $display("FAIL apb_invalid_unaligned: invalid read returned 0x%08x", data);
        failures = failures + 1;
        local_failures = local_failures + 1;
      end
      apb_write(ADDR_A_BASE, pack_i8(-5));
      apb_write(ADDR_A_BASE + 8'h1, pack_i8(99));
      apb_read(ADDR_A_BASE + 8'h1, data);
      if (data !== 32'h0) begin
        $display("FAIL apb_invalid_unaligned: unaligned read returned 0x%08x", data);
        failures = failures + 1;
        local_failures = local_failures + 1;
      end
      apb_read(ADDR_A_BASE, data);
      if ($signed(data) !== -5) begin
        $display("FAIL apb_invalid_unaligned: unaligned write changed A[0], data=0x%08x", data);
        failures = failures + 1;
        local_failures = local_failures + 1;
      end
      if (local_failures == 0) begin
        tests_passed = tests_passed + 1;
        $display("PASS apb_invalid_unaligned");
      end
    end
  endtask

  task automatic run_c_read_only_test;
    logic [DATA_W*MATRIX_ELEMS-1:0] a_values;
    logic [DATA_W*MATRIX_ELEMS-1:0] b_values;
    logic [C_FLAT_W-1:0] expected;
    logic [31:0] before_data;
    logic [31:0] after_data;
    int local_failures;
    begin
      local_failures = 0;
      build_identity(a_values, b_values, expected);
      write_matrix_a(a_values);
      write_matrix_b(b_values);
      apb_start();
      apb_wait_done();
      apb_read(ADDR_C_BASE, before_data);
      apb_write(ADDR_C_BASE, 32'hffff_ffff);
      apb_read(ADDR_C_BASE, after_data);
      if (after_data !== before_data) begin
        $display("FAIL apb_c_read_only: C[0] changed before=0x%08x after=0x%08x", before_data, after_data);
        failures = failures + 1;
        local_failures = local_failures + 1;
      end
      apb_clear_done();
      if (local_failures == 0) begin
        tests_passed = tests_passed + 1;
        $display("PASS apb_c_read_only");
      end
    end
  endtask

  task automatic run_start_while_busy_test;
    logic [DATA_W*MATRIX_ELEMS-1:0] a_values;
    logic [DATA_W*MATRIX_ELEMS-1:0] b_values;
    logic [C_FLAT_W-1:0] expected;
    begin
      build_mixed(a_values, b_values, expected);
      write_matrix_a(a_values);
      write_matrix_b(b_values);
      apb_start();
      apb_wait_busy();
      apb_start();
      apb_wait_done();
      read_and_check_c("apb_start_while_busy", expected);
      apb_clear_done();
    end
  endtask

  task automatic run_reset_test;
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
      apb_start();
      apb_wait_busy();
      @(negedge pclk);
      presetn <= 1'b0;
      psel <= 1'b0;
      penable <= 1'b0;
      pwrite <= 1'b0;
      paddr <= '0;
      pwdata <= '0;
      repeat (4) @(posedge pclk);
      @(negedge pclk);
      presetn <= 1'b1;
      repeat (2) @(posedge pclk);
      apb_read(ADDR_STATUS, status);
      if (status[1:0] !== 2'b00) begin
        $display("FAIL apb_reset: status after reset=0x%08x", status);
        failures = failures + 1;
        local_failures = local_failures + 1;
      end
      if (local_failures == 0) begin
        tests_passed = tests_passed + 1;
        $display("PASS apb_reset");
      end
    end
  endtask

  initial begin
    $dumpfile("build/sim/apb/tinynpu_apb_wrapper.vcd");
    $dumpvars(0, tb_tinynpu_apb_wrapper);

    failures = 0;
    tests_passed = 0;
    presetn = 1'b0;
    psel = 1'b0;
    penable = 1'b0;
    pwrite = 1'b0;
    paddr = '0;
    pwdata = '0;

    repeat (4) @(posedge pclk);
    presetn = 1'b1;
    repeat (2) @(posedge pclk);

    run_identity_test();
    run_mixed_test();
    run_invalid_unaligned_test();
    run_c_read_only_test();
    run_start_while_busy_test();
    run_reset_test();

    if (failures == 0) begin
      $display("APB tests passed: %0d", tests_passed);
      $display("tinyNPU APB SIM PASS");
      $finish;
    end else begin
      $display("tinyNPU APB SIM FAIL: %0d failures", failures);
      $fatal(1);
    end
  end
endmodule
