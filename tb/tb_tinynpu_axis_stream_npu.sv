`timescale 1ns/1ps

`include "tinynpu_defs.svh"

module tb_tinynpu_axis_stream_npu;
  localparam int MAX_WAIT_CYCLES = 1000;
  localparam int MAX_TILES = 16;

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
  logic frame_error;

  int cycle_count;
  int failures;
  int tests_passed;
  int single_tile_latency;
  int steady_state_cycles_per_tile;
  int max_input_acceptance_cycles_per_tile;
  bit overlap_observed;
  bit output_overlap_observed;
  bit input_ready_block_observed;

  logic [`A_FLAT_W-1:0] a_tiles [0:MAX_TILES-1];
  logic [`B_FLAT_W-1:0] b_tiles [0:MAX_TILES-1];
  logic [`C_FLAT_W-1:0] expected_tiles [0:MAX_TILES-1];
  int first_input_cycle [0:MAX_TILES-1];
  int last_input_cycle [0:MAX_TILES-1];
  int first_output_cycle [0:MAX_TILES-1];
  int last_output_cycle [0:MAX_TILES-1];

  tinynpu_axis_stream_npu dut (
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
    .frame_error   (frame_error)
  );

  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cycle_count <= 0;
    end else begin
      cycle_count <= cycle_count + 1;
    end
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

  task automatic prepare_identity_tile(input int tile_idx);
    int i;
    begin
      make_identity(a_tiles[tile_idx]);
      b_tiles[tile_idx] = '0;
      for (i = 0; i < `MATRIX_ELEMS; i = i + 1) begin
        set_i8(b_tiles[tile_idx], i, i - 8 + tile_idx);
      end
      compute_expected(a_tiles[tile_idx], b_tiles[tile_idx], expected_tiles[tile_idx]);
    end
  endtask

  task automatic prepare_random_tile(input int tile_idx);
    begin
      make_random(a_tiles[tile_idx]);
      make_random(b_tiles[tile_idx]);
      compute_expected(a_tiles[tile_idx], b_tiles[tile_idx], expected_tiles[tile_idx]);
    end
  endtask

  task automatic prepare_edge_tile(input int tile_idx);
    int i;
    begin
      make_identity(a_tiles[tile_idx]);
      b_tiles[tile_idx] = '0;
      for (i = 0; i < `MATRIX_ELEMS; i = i + 1) begin
        case (i % 4)
          0: set_i8(b_tiles[tile_idx], i, 127);
          1: set_i8(b_tiles[tile_idx], i, -128);
          2: set_i8(b_tiles[tile_idx], i, 1);
          default: set_i8(b_tiles[tile_idx], i, -1);
        endcase
      end
      compute_expected(a_tiles[tile_idx], b_tiles[tile_idx], expected_tiles[tile_idx]);
    end
  endtask

  task automatic send_beat(
    input logic [7:0] data,
    input logic last,
    input int stall_cycles,
    output int accepted_cycle
  );
    int timeout;
    begin
      repeat (stall_cycles) @(posedge clk);
      @(negedge clk);
      s_axis_tvalid <= 1'b1;
      s_axis_tdata <= data;
      s_axis_tlast <= last;
      timeout = 0;
      @(posedge clk);
      while (!s_axis_tready && timeout < MAX_WAIT_CYCLES) begin
        input_ready_block_observed = 1'b1;
        timeout = timeout + 1;
        @(posedge clk);
      end
      if (!s_axis_tready) begin
        $display("FAIL send_beat: timed out waiting for input ready");
        failures = failures + 1;
      end
      accepted_cycle = cycle_count;
      @(negedge clk);
      s_axis_tvalid <= 1'b0;
      s_axis_tdata <= '0;
      s_axis_tlast <= 1'b0;
    end
  endtask

  task automatic send_tile(input int tile_idx, input bit add_input_stalls);
    int i;
    int accepted_cycle;
    int stall;
    begin
      for (i = 0; i < `MATRIX_ELEMS; i = i + 1) begin
        stall = add_input_stalls ? ((tile_idx + i) % 3) : 0;
        send_beat(get_i8(a_tiles[tile_idx], i), 1'b0, stall, accepted_cycle);
        if (i == 0) begin
          first_input_cycle[tile_idx] = accepted_cycle;
        end
      end
      for (i = 0; i < `MATRIX_ELEMS; i = i + 1) begin
        stall = add_input_stalls ? ((tile_idx + i + 1) % 2) : 0;
        send_beat(get_i8(b_tiles[tile_idx], i), (i == `MATRIX_ELEMS-1), stall, accepted_cycle);
        if (i == `MATRIX_ELEMS-1) begin
          last_input_cycle[tile_idx] = accepted_cycle;
        end
      end
    end
  endtask

  task automatic send_tiles(input int num_tiles, input bit add_input_stalls);
    int tile;
    begin
      for (tile = 0; tile < num_tiles; tile = tile + 1) begin
        send_tile(tile, add_input_stalls);
      end
    end
  endtask

  task automatic receive_tile(input int tile_idx, input bit add_output_backpressure);
    int i;
    int timeout;
    int signed got;
    int signed exp;
    begin
      for (i = 0; i < `MATRIX_ELEMS; i = i + 1) begin
        timeout = 0;
        if (add_output_backpressure && (((i % 5) == 2) || (i == `MATRIX_ELEMS-1))) begin
          logic [31:0] held_data;
          logic held_last;
          @(negedge clk);
          m_axis_tready <= 1'b0;
          @(posedge clk);
          while (!m_axis_tvalid && timeout < MAX_WAIT_CYCLES) begin
            timeout = timeout + 1;
            @(posedge clk);
          end
          #1;
          held_data = m_axis_tdata;
          held_last = m_axis_tlast;
          repeat (4) @(posedge clk);
          #1;
          if ((m_axis_tvalid !== 1'b1) || (m_axis_tdata !== held_data) || (m_axis_tlast !== held_last)) begin
            $display("FAIL tile%0d: output changed while backpressured at index %0d", tile_idx, i);
            failures = failures + 1;
          end
          timeout = 0;
        end

        @(posedge clk);
        while (!m_axis_tvalid && timeout < MAX_WAIT_CYCLES) begin
          timeout = timeout + 1;
          @(posedge clk);
        end
        if (!m_axis_tvalid) begin
          $display("FAIL tile%0d: timed out waiting for output %0d", tile_idx, i);
          failures = failures + 1;
        end else begin
          #1;
          got = $signed(m_axis_tdata);
          exp = get_i32(expected_tiles[tile_idx], i);
          if (got !== exp) begin
            $display("FAIL tile%0d: C[%0d] expected %0d actual %0d", tile_idx, i, exp, got);
            failures = failures + 1;
          end
          if (m_axis_tlast !== (i == `MATRIX_ELEMS-1)) begin
            $display("FAIL tile%0d: output tlast mismatch at index %0d", tile_idx, i);
            failures = failures + 1;
          end
          if (i == 0) begin
            first_output_cycle[tile_idx] = cycle_count;
          end
          if (i == `MATRIX_ELEMS-1) begin
            last_output_cycle[tile_idx] = cycle_count;
          end
        end
        @(negedge clk);
        m_axis_tready <= 1'b1;
        @(posedge clk);
        @(negedge clk);
        m_axis_tready <= 1'b0;
      end
    end
  endtask

  task automatic receive_tiles(input int num_tiles, input bit add_output_backpressure);
    int tile;
    begin
      for (tile = 0; tile < num_tiles; tile = tile + 1) begin
        receive_tile(tile, add_output_backpressure);
      end
    end
  endtask

  task automatic run_stream_test(
    input string test_name,
    input int num_tiles,
    input bit add_input_stalls,
    input bit add_output_backpressure
  );
    int before_failures;
    begin
      before_failures = failures;
      input_ready_block_observed = 1'b0;
      fork
        send_tiles(num_tiles, add_input_stalls);
        receive_tiles(num_tiles, add_output_backpressure);
      join
      repeat (2) @(posedge clk);
      while (busy) begin
        @(posedge clk);
      end

      if (num_tiles > 1) begin
        for (int tile = 1; tile < num_tiles; tile = tile + 1) begin
          if (first_input_cycle[tile] < last_output_cycle[tile-1]) begin
            overlap_observed = 1'b1;
          end
        end
      end

      if (num_tiles > 0 && first_input_cycle[num_tiles-1] < last_output_cycle[0]) begin
        output_overlap_observed = 1'b1;
      end

      if (failures == before_failures) begin
        tests_passed = tests_passed + 1;
        $display("PASS %s", test_name);
      end
    end
  endtask

  task automatic reset_during_load_test;
    int accepted_cycle;
    begin
      send_beat(8'h11, 1'b0, 0, accepted_cycle);
      send_beat(8'h22, 1'b0, 0, accepted_cycle);
      @(negedge clk);
      rst_n <= 1'b0;
      s_axis_tvalid <= 1'b0;
      m_axis_tready <= 1'b0;
      repeat (3) @(posedge clk);
      if ((m_axis_tvalid !== 1'b0) || (busy !== 1'b0) || (frame_error !== 1'b0)) begin
        $display("FAIL reset_during_load: reset did not clear state");
        failures = failures + 1;
      end else begin
        tests_passed = tests_passed + 1;
        $display("PASS reset_during_load");
      end
      rst_n <= 1'b1;
      repeat (2) @(posedge clk);
    end
  endtask

  task automatic input_buffer_full_backpressure_test;
    int timeout;
    bit saw_block;
    begin
      reset_dut();
      for (int tile = 0; tile < 5; tile = tile + 1) begin
        prepare_identity_tile(tile);
      end
      m_axis_tready <= 1'b0;

      send_tile(0, 1'b0);
      send_tile(1, 1'b0);
      send_tile(2, 1'b0);
      send_tile(3, 1'b0);

      @(negedge clk);
      s_axis_tvalid <= 1'b1;
      s_axis_tdata <= get_i8(a_tiles[4], 0);
      s_axis_tlast <= 1'b0;
      saw_block = 1'b0;
      timeout = 0;
      while (!s_axis_tready && timeout < MAX_WAIT_CYCLES) begin
        saw_block = 1'b1;
        timeout = timeout + 1;
        @(posedge clk);
      end
      if (!saw_block) begin
        $display("FAIL input_buffer_full_backpressure: third tile was not blocked");
        failures = failures + 1;
      end else begin
        input_ready_block_observed = 1'b1;
        tests_passed = tests_passed + 1;
        $display("PASS input_buffer_full_backpressure");
      end
      @(negedge clk);
      s_axis_tvalid <= 1'b0;
      s_axis_tdata <= '0;
      s_axis_tlast <= 1'b0;
      reset_dut();
    end
  endtask

  task automatic reset_during_compute_test;
    begin
      prepare_identity_tile(0);
      send_tile(0, 1'b0);
      while (!busy || m_axis_tvalid) begin
        @(posedge clk);
      end
      repeat (5) @(posedge clk);
      @(negedge clk);
      rst_n <= 1'b0;
      repeat (3) @(posedge clk);
      if ((m_axis_tvalid !== 1'b0) || (busy !== 1'b0) || (frame_error !== 1'b0)) begin
        $display("FAIL reset_during_compute: reset did not clear state");
        failures = failures + 1;
      end else begin
        tests_passed = tests_passed + 1;
        $display("PASS reset_during_compute");
      end
      rst_n <= 1'b1;
      repeat (2) @(posedge clk);
    end
  endtask

  task automatic reset_during_output_test;
    begin
      prepare_identity_tile(0);
      send_tile(0, 1'b0);
      m_axis_tready <= 1'b0;
      while (!m_axis_tvalid) begin
        @(posedge clk);
      end
      @(negedge clk);
      rst_n <= 1'b0;
      repeat (3) @(posedge clk);
      if ((m_axis_tvalid !== 1'b0) || (busy !== 1'b0) || (frame_error !== 1'b0)) begin
        $display("FAIL reset_during_output: reset did not clear state");
        failures = failures + 1;
      end else begin
        tests_passed = tests_passed + 1;
        $display("PASS reset_during_output");
      end
      rst_n <= 1'b1;
      repeat (2) @(posedge clk);
    end
  endtask

  initial begin
    failures = 0;
    tests_passed = 0;
    single_tile_latency = 0;
    steady_state_cycles_per_tile = 0;
    max_input_acceptance_cycles_per_tile = 0;
    overlap_observed = 1'b0;
    output_overlap_observed = 1'b0;
    reset_dut();

    prepare_identity_tile(0);
    run_stream_test("single_tile_identity", 1, 1'b0, 1'b0);
    single_tile_latency = last_output_cycle[0] - first_input_cycle[0] + 1;

    prepare_identity_tile(0);
    prepare_identity_tile(1);
    run_stream_test("two_back_to_back_tiles", 2, 1'b0, 1'b0);

    for (int tile = 0; tile < 8; tile = tile + 1) begin
      prepare_random_tile(tile);
    end
    run_stream_test("many_back_to_back_random_tiles", 8, 1'b0, 1'b0);
    steady_state_cycles_per_tile = (last_output_cycle[7] - last_output_cycle[0]) / 7;
    max_input_acceptance_cycles_per_tile = (last_input_cycle[7] - first_input_cycle[0] + 1) / 8;

    for (int tile = 0; tile < 4; tile = tile + 1) begin
      prepare_random_tile(tile);
    end
    run_stream_test("input_stalls", 4, 1'b1, 1'b0);

    for (int tile = 0; tile < 4; tile = tile + 1) begin
      prepare_random_tile(tile);
    end
    run_stream_test("output_backpressure", 4, 1'b0, 1'b1);

    for (int tile = 0; tile < 4; tile = tile + 1) begin
      prepare_random_tile(tile);
    end
    run_stream_test("simultaneous_input_output_backpressure", 4, 1'b1, 1'b1);

    reset_dut();
    prepare_edge_tile(0);
    prepare_identity_tile(1);
    run_stream_test("signed_edges_and_no_data_mixing", 2, 1'b0, 1'b1);

    input_buffer_full_backpressure_test();
    reset_during_load_test();
    reset_during_compute_test();
    reset_during_output_test();

    if (!overlap_observed) begin
      $display("FAIL overlap: no input/output tile overlap observed");
      failures = failures + 1;
    end
    if (!output_overlap_observed) begin
      $display("FAIL overlap: compute/output overlap was not observed");
      failures = failures + 1;
    end
    if (!input_ready_block_observed) begin
      $display("FAIL backpressure: input ready never blocked when buffers filled");
      failures = failures + 1;
    end

    $display("METRIC single_tile_latency_cycles=%0d", single_tile_latency);
    $display("METRIC steady_state_cycles_per_tile=%0d", steady_state_cycles_per_tile);
    $display("METRIC max_input_acceptance_cycles_per_tile=%0d", max_input_acceptance_cycles_per_tile);
    $display("METRIC load_compute_output_overlap_observed=%0d", overlap_observed && output_overlap_observed);

    if (failures == 0) begin
      $display("AXIS stream NPU tests passed: %0d", tests_passed);
      $display("tinyNPU AXIS STREAM NPU SIM PASS");
      $finish;
    end

    $display("tinyNPU AXIS STREAM NPU SIM FAIL: failures=%0d", failures);
    $finish;
  end

endmodule
