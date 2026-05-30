`timescale 1ns/1ps

`include "tinynpu_defs.svh"

module tinynpu_assertions (
  input logic                clk,
  input logic                rst_n,
  input logic                busy,
  input logic                done,
  input logic                start_accepted,
  input logic                start_while_busy,
  input logic [`C_FLAT_W-1:0] c_flat
);

`ifdef TINYNPU_SIM_ASSERT
  localparam int MAX_OPERATION_CYCLES = 200;

  logic operation_pending;
  int   operation_cycles;
  logic prev_done;
  logic [`C_FLAT_W-1:0] prev_c_flat;

  always @(negedge rst_n) begin
    #1;
    if (busy !== 1'b0 || done !== 1'b0) begin
      $display("ASSERT FAIL reset_clears_status: busy=%0b done=%0b", busy, done);
      $fatal(1);
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      operation_pending <= 1'b0;
      operation_cycles  <= 0;
      prev_done         <= 1'b0;
      prev_c_flat       <= '0;
    end else begin
      #1;

      if (busy && done) begin
        $display("ASSERT FAIL busy_done_mutex: busy and done both asserted");
        $fatal(1);
      end

      if (start_while_busy && start_accepted) begin
        $display("ASSERT FAIL start_while_busy_accepted: busy start was accepted");
        $fatal(1);
      end

      if (prev_done && done && !start_accepted && (c_flat !== prev_c_flat)) begin
        $display("ASSERT FAIL c_stable_after_done: C changed while done stayed high");
        $fatal(1);
      end

      if (start_accepted) begin
        operation_pending <= 1'b1;
        operation_cycles  <= 0;
      end else if (operation_pending && done) begin
        operation_pending <= 1'b0;
      end else if (operation_pending) begin
        operation_cycles <= operation_cycles + 1;
        if (operation_cycles > MAX_OPERATION_CYCLES) begin
          $display("ASSERT FAIL done_eventually: no done within %0d cycles", MAX_OPERATION_CYCLES);
          $fatal(1);
        end
      end

      prev_done   <= done;
      prev_c_flat <= c_flat;
    end
  end
`endif

endmodule
