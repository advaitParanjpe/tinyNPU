`timescale 1ns/1ps

`include "tinynpu_defs.svh"

module tinynpu_mac_serial (
  input  logic                  clk,
  input  logic                  rst_n,
  input  logic                  start,
  input  logic [`A_FLAT_W-1:0]   a_flat,
  input  logic [`B_FLAT_W-1:0]   b_flat,
  output logic                  busy,
  output logic                  done,
  output logic [`C_FLAT_W-1:0]   c_flat
);

  typedef enum logic [1:0] {
    S_IDLE,
    S_CALC,
    S_DONE
  } state_t;

  state_t state_q;
  logic [1:0] row_q;
  logic [1:0] col_q;
  logic [1:0] k_q;
  logic signed [`ACC_W-1:0] acc_q;

  function automatic logic signed [`DATA_W-1:0] get_a(input logic [1:0] row, input logic [1:0] col);
    int idx;
    begin
      idx = (row * `MATRIX_N) + col;
      get_a = a_flat[idx*`DATA_W +: `DATA_W];
    end
  endfunction

  function automatic logic signed [`DATA_W-1:0] get_b(input logic [1:0] row, input logic [1:0] col);
    int idx;
    begin
      idx = (row * `MATRIX_N) + col;
      get_b = b_flat[idx*`DATA_W +: `DATA_W];
    end
  endfunction

  function automatic logic signed [`ACC_W-1:0] product_at(
    input logic signed [`DATA_W-1:0] a_value,
    input logic signed [`DATA_W-1:0] b_value
  );
    begin
      product_at = $signed(a_value) * $signed(b_value);
    end
  endfunction

  assign busy = (state_q == S_CALC);
  assign done = (state_q == S_DONE);

  always_ff @(posedge clk or negedge rst_n) begin
    logic signed [`ACC_W-1:0] partial_sum;
    int c_idx;

    if (!rst_n) begin
      state_q <= S_IDLE;
      row_q   <= '0;
      col_q   <= '0;
      k_q     <= '0;
      acc_q   <= '0;
      c_flat  <= '0;
    end else begin
      case (state_q)
        S_IDLE: begin
          if (start) begin
            state_q <= S_CALC;
            row_q   <= '0;
            col_q   <= '0;
            k_q     <= '0;
            acc_q   <= '0;
            c_flat  <= '0;
          end
        end

        S_CALC: begin
          partial_sum = acc_q + product_at(get_a(row_q, k_q), get_b(k_q, col_q));

          if (k_q == `MATRIX_N-1) begin
            c_idx = (row_q * `MATRIX_N) + col_q;
            c_flat[c_idx*`ACC_W +: `ACC_W] <= partial_sum;
            acc_q <= '0;
            k_q   <= '0;

            if ((row_q == `MATRIX_N-1) && (col_q == `MATRIX_N-1)) begin
              state_q <= S_DONE;
            end else if (col_q == `MATRIX_N-1) begin
              row_q <= row_q + 1'b1;
              col_q <= '0;
            end else begin
              col_q <= col_q + 1'b1;
            end
          end else begin
            acc_q <= partial_sum;
            k_q   <= k_q + 1'b1;
          end
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
