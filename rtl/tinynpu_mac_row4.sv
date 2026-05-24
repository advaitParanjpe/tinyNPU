`timescale 1ns/1ps

import tinynpu_pkg::*;

module tinynpu_mac_row4 (
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
    S_INIT_ROW,
    S_MAC_ROW,
    S_WRITE_ROW,
    S_DONE
  } state_t;

  state_t state_q;
  logic [1:0] row_q;
  logic [1:0] k_q;
  logic signed [ACC_W-1:0] acc0_q;
  logic signed [ACC_W-1:0] acc1_q;
  logic signed [ACC_W-1:0] acc2_q;
  logic signed [ACC_W-1:0] acc3_q;

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
    logic signed [DATA_W-1:0] a_val;

    if (!rst_n) begin
      state_q <= S_IDLE;
      row_q   <= '0;
      k_q     <= '0;
      acc0_q  <= '0;
      acc1_q  <= '0;
      acc2_q  <= '0;
      acc3_q  <= '0;
      c_flat  <= '0;
    end else begin
      case (state_q)
        S_IDLE: begin
          if (start) begin
            state_q <= S_INIT_ROW;
            row_q   <= '0;
            k_q     <= '0;
            acc0_q  <= '0;
            acc1_q  <= '0;
            acc2_q  <= '0;
            acc3_q  <= '0;
            c_flat  <= '0;
          end
        end

        S_INIT_ROW: begin
          acc0_q  <= '0;
          acc1_q  <= '0;
          acc2_q  <= '0;
          acc3_q  <= '0;
          k_q     <= '0;
          state_q <= S_MAC_ROW;
        end

        S_MAC_ROW: begin
          a_val  = get_a(row_q, k_q);
          acc0_q <= acc0_q + product_at(a_val, get_b(k_q, 2'd0));
          acc1_q <= acc1_q + product_at(a_val, get_b(k_q, 2'd1));
          acc2_q <= acc2_q + product_at(a_val, get_b(k_q, 2'd2));
          acc3_q <= acc3_q + product_at(a_val, get_b(k_q, 2'd3));

          if (k_q == MATRIX_N-1) begin
            state_q <= S_WRITE_ROW;
          end else begin
            k_q <= k_q + 1'b1;
          end
        end

        S_WRITE_ROW: begin
          c_flat[((row_q * MATRIX_N) + 0)*ACC_W +: ACC_W] <= acc0_q;
          c_flat[((row_q * MATRIX_N) + 1)*ACC_W +: ACC_W] <= acc1_q;
          c_flat[((row_q * MATRIX_N) + 2)*ACC_W +: ACC_W] <= acc2_q;
          c_flat[((row_q * MATRIX_N) + 3)*ACC_W +: ACC_W] <= acc3_q;

          if (row_q == MATRIX_N-1) begin
            state_q <= S_DONE;
          end else begin
            row_q   <= row_q + 1'b1;
            state_q <= S_INIT_ROW;
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
