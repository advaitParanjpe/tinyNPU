`timescale 1ns/1ps

`include "tinynpu_defs.svh"

module tb_tinynpu_axis_stream_tile_core;
  localparam int MAX_WAIT_CYCLES = 300;

  logic clk;
  logic rst_n;
  logic s_axis_tvalid;
  logic s_axis_tready;
  logic [7:0] s_axis_tdata;
  logic s_axis_tlast;
  logic m_axis_tvalid;
  logic m_axis_tready;
  logic [31:0] m_axis_tdata;
  logic m_axis_tlast;
  logic busy;
  logic done;
  logic frame_error;

  int failures;
  int tests_passed;

  tinynpu_axis_stream_tile_core dut (
    .clk           (clk),
    .rst_n         (rst_n),
    .s_axis_tvalid (s_axis_tvalid),
    .s_axis_tready (s_axis_tready),
    .s_axis_tdata  (s_axis_tdata),
    .s_axis_tlast  (s_axis_tlast),
    .m_axis_tvalid (m_axis_tvalid),
    .m_axis_tready (m_axis_tready),
    .m_axis_tdata  (m_axis_tdata),
    .m_axis_tlast  (m_axis_tlast),
    .busy          (busy),
    .done          (done),
    .frame_error   (frame_error)
  );

  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
  end

  function automatic logic signed [`DATA_W-1:0] get_i8(
    input logic [`A_FLAT_W-1:0] flat,
    input int idx
  );
    begin
      get_i8 = flat[idx*`DATA_W +: `DATA_W];
    end
  endfunction

  function automatic logic signed [`ACC_W-1:0] get_i32(
    input logic [`C_FLAT_W-1:0] flat,
    input int idx
  );
    begin
      get_i32 = flat[idx*`ACC_W +: `ACC_W];
    end
  endfunction

  task automatic set_i8(
    inout logic [`A_FLAT_W-1:0] flat,
    input int idx,
    input int value
  );
    begin
      flat[idx*`DATA_W +: `DATA_W] = value[7:0];
    end
  endtask

  task automatic set_i32(
    inout logic [`C_FLAT_W-1:0] flat,
    input int idx,
    input int value
  );
    begin
      flat[idx*`ACC_W +: `ACC_W] = value[31:0];
    end
  endtask

  task automatic compute_expected(
    input logic [`A_FLAT_W-1:0] a_flat,
    input logic [`B_FLAT_W-1:0] b_flat,
    output logic [`C_FLAT_W-1:0] c_flat
  );
    int row;
    int col;
    int k;
    int signed sum;
    int signed a_value;
    int signed b_value;
    begin
      c_flat = '0;
      for (row = 0; row < `MATRIX_N; row = row + 1) begin
        for (col = 0; col < `MATRIX_N; col = col + 1) begin
          sum = 0;
          for (k = 0; k < `MATRIX_N; k = k + 1) begin
            a_value = get_i8(a_flat, (row * `MATRIX_N) + k);
            b_value = get_i8(b_flat, (k * `MATRIX_N) + col);
            sum = sum + (a_value * b_value);
          end
          set_i32(c_flat, (row * `MATRIX_N) + col, sum);
        end
      end
    end
  endtask

  task automatic reset_dut;
    begin
      rst_n = 1'b0;
      s_axis_tvalid = 1'b0;
      s_axis_tdata = '0;
      s_axis_tlast = 1'b0;
      m_axis_tready = 1'b0;
      repeat (5) @(posedge clk);
      rst_n = 1'b1;
      repeat (2) @(posedge clk);
    end
  endtask

  task automatic send_beat(
    input logic [7:0] data,
    input logic last,
    input int stall_cycles
  );
    int timeout;
    begin
      repeat (stall_cycles) @(posedge clk);
      @(negedge clk);
      s_axis_tvalid <= 1'b1;
      s_axis_tdata  <= data;
      s_axis_tlast  <= last;
      timeout = 0;
      @(posedge clk);
      while (!s_axis_tready && timeout < MAX_WAIT_CYCLES) begin
        timeout = timeout + 1;
        @(posedge clk);
      end
      if (!s_axis_tready) begin
        $display("FAIL send_beat: timed out waiting for tready");
        failures = failures + 1;
      end
      @(negedge clk);
      s_axis_tvalid <= 1'b0;
      s_axis_tdata  <= '0;
      s_axis_tlast  <= 1'b0;
    end
  endtask

  task automatic send_tile(
    input logic [`A_FLAT_W-1:0] a_flat,
    input logic [`B_FLAT_W-1:0] b_flat,
    input bit add_input_stalls
  );
    int i;
    int stall;
    begin
      for (i = 0; i < `MATRIX_ELEMS; i = i + 1) begin
        stall = add_input_stalls ? (i % 3) : 0;
        send_beat(get_i8(a_flat, i), 1'b0, stall);
      end
      for (i = 0; i < `MATRIX_ELEMS; i = i + 1) begin
        stall = add_input_stalls ? ((i + 1) % 2) : 0;
        send_beat(get_i8(b_flat, i), (i == `MATRIX_ELEMS-1), stall);
      end
    end
  endtask

  task automatic receive_and_check(
    input string test_name,
    input logic [`C_FLAT_W-1:0] expected,
    input bit add_output_backpressure
  );
    int i;
    int timeout;
    int signed got;
    int signed exp;
    int local_failures;
    begin
      local_failures = 0;
      for (i = 0; i < `MATRIX_ELEMS; i = i + 1) begin
        timeout = 0;
        if (add_output_backpressure && ((i % 4) == 1)) begin
          @(negedge clk);
          m_axis_tready <= 1'b0;
          repeat (1) @(posedge clk);
          if (m_axis_tvalid && s_axis_tready) begin
            $display("FAIL %s: input ready asserted while output was backpressured", test_name);
            failures = failures + 1;
            local_failures = local_failures + 1;
          end
          repeat (3) @(posedge clk);
        end

        @(posedge clk);
        while (!m_axis_tvalid && timeout < MAX_WAIT_CYCLES) begin
          timeout = timeout + 1;
          @(posedge clk);
        end

        #1;
        if (!m_axis_tvalid) begin
          $display("FAIL %s: timed out waiting for output %0d", test_name, i);
          failures = failures + 1;
          local_failures = local_failures + 1;
        end else begin
          got = $signed(m_axis_tdata);
          exp = get_i32(expected, i);
          if (got !== exp) begin
            $display("FAIL %s: C[%0d] expected %0d actual %0d", test_name, i, exp, got);
            failures = failures + 1;
            local_failures = local_failures + 1;
          end
          if (m_axis_tlast !== (i == `MATRIX_ELEMS-1)) begin
            $display("FAIL %s: tlast mismatch at output %0d", test_name, i);
            failures = failures + 1;
            local_failures = local_failures + 1;
          end
        end

        @(negedge clk);
        m_axis_tready <= 1'b1;
        @(posedge clk);
        if (i == `MATRIX_ELEMS-1) begin
          #1;
          if (done !== 1'b1) begin
            $display("FAIL %s: done did not pulse after final output", test_name);
            failures = failures + 1;
            local_failures = local_failures + 1;
          end
        end
        @(negedge clk);
        m_axis_tready <= 1'b0;
      end

      if (local_failures == 0) begin
        tests_passed = tests_passed + 1;
        $display("PASS %s", test_name);
      end
    end
  endtask

  task automatic run_tile_test(
    input string test_name,
    input logic [`A_FLAT_W-1:0] a_flat,
    input logic [`B_FLAT_W-1:0] b_flat,
    input bit add_input_stalls,
    input bit add_output_backpressure
  );
    logic [`C_FLAT_W-1:0] expected;
    begin
      compute_expected(a_flat, b_flat, expected);
      send_tile(a_flat, b_flat, add_input_stalls);
      receive_and_check(test_name, expected, add_output_backpressure);
    end
  endtask

  task automatic make_identity(output logic [`A_FLAT_W-1:0] flat);
    int row;
    int col;
    begin
      flat = '0;
      for (row = 0; row < `MATRIX_N; row = row + 1) begin
        for (col = 0; col < `MATRIX_N; col = col + 1) begin
          set_i8(flat, (row * `MATRIX_N) + col, (row == col) ? 1 : 0);
        end
      end
    end
  endtask

  task automatic make_random(output logic [`A_FLAT_W-1:0] flat);
    int i;
    int value;
    begin
      flat = '0;
      for (i = 0; i < `MATRIX_ELEMS; i = i + 1) begin
        value = $urandom_range(0, 255) - 128;
        set_i8(flat, i, value);
      end
    end
  endtask

  task automatic test_framing_error;
    logic [`A_FLAT_W-1:0] a_flat;
    logic [`B_FLAT_W-1:0] b_flat;
    int i;
    begin
      send_beat(8'h01, 1'b1, 0);
      repeat (2) @(posedge clk);
      if (frame_error !== 1'b1) begin
        $display("FAIL early_tlast_error: early tlast was not reported");
        failures = failures + 1;
      end else if ((m_axis_tvalid !== 1'b0) || (busy !== 1'b0)) begin
        $display("FAIL early_tlast_error: core started after bad frame");
        failures = failures + 1;
      end else begin
        tests_passed = tests_passed + 1;
        $display("PASS early_tlast_error");
      end

      a_flat = '0;
      b_flat = '0;
      for (i = 0; i < `MATRIX_ELEMS; i = i + 1) begin
        set_i8(a_flat, i, i);
        set_i8(b_flat, i, -i);
      end
      for (i = 0; i < `MATRIX_ELEMS; i = i + 1) begin
        send_beat(get_i8(a_flat, i), 1'b0, 0);
      end
      for (i = 0; i < `MATRIX_ELEMS; i = i + 1) begin
        send_beat(get_i8(b_flat, i), 1'b0, 0);
      end
      repeat (2) @(posedge clk);
      if (frame_error !== 1'b1) begin
        $display("FAIL missing_tlast_error: missing final tlast was not reported");
        failures = failures + 1;
      end else if ((m_axis_tvalid !== 1'b0) || (busy !== 1'b0)) begin
        $display("FAIL missing_tlast_error: core started after bad frame");
        failures = failures + 1;
      end else begin
        tests_passed = tests_passed + 1;
        $display("PASS missing_tlast_error");
      end
    end
  endtask

  initial begin
    logic [`A_FLAT_W-1:0] a_flat;
    logic [`B_FLAT_W-1:0] b_flat;
    int i;

    failures = 0;
    tests_passed = 0;
    reset_dut();

    make_identity(a_flat);
    b_flat = '0;
    for (i = 0; i < `MATRIX_ELEMS; i = i + 1) begin
      set_i8(b_flat, i, i - 8);
    end
    run_tile_test("identity", a_flat, b_flat, 1'b0, 1'b0);

    a_flat = '0;
    b_flat = '0;
    run_tile_test("zeros", a_flat, b_flat, 1'b0, 1'b0);

    for (i = 0; i < `MATRIX_ELEMS; i = i + 1) begin
      set_i8(a_flat, i, (i % 2) ? -3 : 4);
      set_i8(b_flat, i, i - 7);
    end
    run_tile_test("mixed_signed", a_flat, b_flat, 1'b1, 1'b0);

    make_random(a_flat);
    make_random(b_flat);
    run_tile_test("random_tile", a_flat, b_flat, 1'b1, 1'b1);

    test_framing_error();

    if (failures == 0) begin
      $display("AXIS stream tests passed: %0d", tests_passed);
      $display("tinyNPU AXIS STREAM SIM PASS");
      $finish;
    end

    $display("tinyNPU AXIS STREAM SIM FAIL: failures=%0d", failures);
    $finish;
  end

endmodule
