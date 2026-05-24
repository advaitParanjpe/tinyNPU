`timescale 1ns/1ps

import tinynpu_pkg::*;

module tinynpu_mac_full16 (
  input  logic                  clk,
  input  logic                  rst_n,
  input  logic                  start,
  input  logic [A_FLAT_W-1:0]   a_flat,
  input  logic [B_FLAT_W-1:0]   b_flat,
  output logic                  busy,
  output logic                  done,
  output logic [C_FLAT_W-1:0]   c_flat
);

  typedef enum logic [2:0] {
    S_IDLE,
    S_INIT,
    S_MAC,
    S_WRITE,
    S_DONE
  } state_t;

  state_t state_q;
  logic [1:0] k_q;
  logic signed [ACC_W-1:0] acc_q [0:MATRIX_ELEMS-1];

  function automatic logic signed [DATA_W-1:0] get_a(input logic [1:0] row, input logic [1:0] col);
    int idx;
    begin
      idx = (row * MATRIX_N) + col;
      get_a = a_flat[idx*DATA_W +: DATA_W];
    end
  endfunction

  function automatic logic signed [DATA_W-1:0] get_b(input logic [1:0] row, input logic [1:0] col);
    int idx;
    begin
      idx = (row * MATRIX_N) + col;
      get_b = b_flat[idx*DATA_W +: DATA_W];
    end
  endfunction

  function automatic logic signed [ACC_W-1:0] product_at(
    input logic signed [DATA_W-1:0] a_value,
    input logic signed [DATA_W-1:0] b_value
  );
    begin
      product_at = $signed(a_value) * $signed(b_value);
    end
  endfunction

  assign busy = (state_q != S_IDLE) && (state_q != S_DONE);
  assign done = (state_q == S_DONE);

  always_ff @(posedge clk or negedge rst_n) begin
    int row;
    int col;
    int idx;

    if (!rst_n) begin
      state_q <= S_IDLE;
      k_q     <= '0;
      c_flat  <= '0;
      for (idx = 0; idx < MATRIX_ELEMS; idx = idx + 1) begin
        acc_q[idx] <= '0;
      end
    end else begin
      case (state_q)
        S_IDLE: begin
          if (start) begin
            state_q <= S_INIT;
            k_q     <= '0;
            c_flat  <= '0;
          end
        end

        S_INIT: begin
          for (idx = 0; idx < MATRIX_ELEMS; idx = idx + 1) begin
            acc_q[idx] <= '0;
          end
          k_q     <= '0;
          state_q <= S_MAC;
        end

        S_MAC: begin
          for (row = 0; row < MATRIX_N; row = row + 1) begin
            for (col = 0; col < MATRIX_N; col = col + 1) begin
              idx = (row * MATRIX_N) + col;
              acc_q[idx] <= acc_q[idx] + product_at(get_a(row[1:0], k_q), get_b(k_q, col[1:0]));
            end
          end

          if (k_q == MATRIX_N-1) begin
            state_q <= S_WRITE;
          end else begin
            k_q <= k_q + 1'b1;
          end
        end

        S_WRITE: begin
          for (idx = 0; idx < MATRIX_ELEMS; idx = idx + 1) begin
            c_flat[idx*ACC_W +: ACC_W] <= acc_q[idx];
          end
          state_q <= S_DONE;
        end

        S_DONE: begin
          // done is a one-cycle pulse. c_flat remains valid until the next start.
          state_q <= S_IDLE;
        end

        default: begin
          state_q <= S_IDLE;
        end
      endcase
    end
  end

endmodule
