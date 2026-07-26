`timescale 1ns/1ps

`include "tinynpu_defs.svh"

// Output-stationary processing element. A advances right, B advances down,
// and each PE keeps one C accumulator. Splitting the signed 8x8 multiply into
// registered low/high-nibble partial products keeps multiplication and
// accumulation out of the same timing stage.
module tinynpu_systolic_pe #(
  parameter int DATA_W = `DATA_W,
  parameter int ACC_W  = `ACC_W
) (
  input  logic                     clk,
  input  logic                     rst_n,
  input  logic                     clear,

  input  logic signed [DATA_W-1:0] a_in,
  input  logic                     a_valid_in,
  output logic signed [DATA_W-1:0] a_out,
  output logic                     a_valid_out,

  input  logic signed [DATA_W-1:0] b_in,
  input  logic                     b_valid_in,
  output logic signed [DATA_W-1:0] b_out,
  output logic                     b_valid_out,

  output logic signed [ACC_W-1:0]  acc_out
);

  localparam int PROD_W = DATA_W * 2;
  localparam int PART_W = DATA_W + (DATA_W / 2) + 1;

  logic signed [PART_W-1:0] product_lo_q;
  logic signed [PART_W-1:0] product_hi_q;
  logic                     partial_valid_q;
  logic signed [PROD_W-1:0] product_q;
  logic                     product_valid_q;

  function automatic logic signed [PROD_W-1:0] combine_product_parts(
    input logic signed [PART_W-1:0] lo_part,
    input logic signed [PART_W-1:0] hi_part
  );
    logic signed [PROD_W-1:0] lo_ext;
    logic signed [PROD_W-1:0] hi_ext;
    begin
      lo_ext = {{(PROD_W-PART_W){lo_part[PART_W-1]}}, lo_part};
      hi_ext = {{(PROD_W-PART_W){hi_part[PART_W-1]}}, hi_part};
      combine_product_parts = lo_ext + (hi_ext <<< (DATA_W / 2));
    end
  endfunction

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      a_out           <= '0;
      a_valid_out     <= 1'b0;
      b_out           <= '0;
      b_valid_out     <= 1'b0;
      product_lo_q    <= '0;
      product_hi_q    <= '0;
      partial_valid_q <= 1'b0;
      product_q       <= '0;
      product_valid_q <= 1'b0;
      acc_out         <= '0;
    end else if (clear) begin
      a_out           <= '0;
      a_valid_out     <= 1'b0;
      b_out           <= '0;
      b_valid_out     <= 1'b0;
      product_lo_q    <= '0;
      product_hi_q    <= '0;
      partial_valid_q <= 1'b0;
      product_q       <= '0;
      product_valid_q <= 1'b0;
      acc_out         <= '0;
    end else begin
      a_out       <= a_in;
      a_valid_out <= a_valid_in;
      b_out       <= b_in;
      b_valid_out <= b_valid_in;

      partial_valid_q <= a_valid_in && b_valid_in;
      if (a_valid_in && b_valid_in) begin
        product_lo_q <=
          $signed(a_in) * $signed({1'b0, b_in[(DATA_W/2)-1:0]});
        product_hi_q <=
          $signed(a_in) * $signed(b_in[DATA_W-1:DATA_W/2]);
      end

      product_valid_q <= partial_valid_q;
      if (partial_valid_q) begin
        product_q <= combine_product_parts(product_lo_q, product_hi_q);
      end

      if (product_valid_q) begin
        acc_out <= acc_out +
                   {{(ACC_W-PROD_W){product_q[PROD_W-1]}}, product_q};
      end
    end
  end

endmodule

// Fixed 4x4 wavefront controller around the PE mesh. Edge injection is skewed
// so A[row][k] and B[k][col] meet at PE[row][col] on the same cycle.
module tinynpu_mac_systolic4x4 (
  input  logic                  clk,
  input  logic                  rst_n,
  input  logic                  start,
  input  logic [`A_FLAT_W-1:0]   a_flat,
  input  logic [`B_FLAT_W-1:0]   b_flat,
  output logic                  busy,
  output logic                  done,
  output logic [`C_FLAT_W-1:0]   c_flat
);

  localparam int ARRAY_N  = `MATRIX_N;
  localparam int LAST_STEP = (3 * ARRAY_N) - 3;

  typedef enum logic [2:0] {
    S_IDLE,
    S_CLEAR,
    S_RUN,
    S_FLUSH_PARTIAL,
    S_FLUSH_PRODUCT,
    S_FLUSH_ACC,
    S_CAPTURE,
    S_DONE
  } state_t;

  state_t state_q;
  logic [$clog2(LAST_STEP+1)-1:0] step_q;

  logic signed [`DATA_W-1:0] a_inject_q [0:ARRAY_N-1];
  logic signed [`DATA_W-1:0] b_inject_q [0:ARRAY_N-1];
  logic                      a_inject_valid_q [0:ARRAY_N-1];
  logic                      b_inject_valid_q [0:ARRAY_N-1];

  logic signed [`DATA_W-1:0] a_link [0:ARRAY_N-1][0:ARRAY_N];
  logic signed [`DATA_W-1:0] b_link [0:ARRAY_N][0:ARRAY_N-1];
  logic                      a_valid_link [0:ARRAY_N-1][0:ARRAY_N];
  logic                      b_valid_link [0:ARRAY_N][0:ARRAY_N-1];
  logic signed [`ACC_W-1:0]  pe_acc [0:ARRAY_N-1][0:ARRAY_N-1];

  wire pe_clear = (state_q == S_CLEAR);

  assign busy = (state_q != S_IDLE) && (state_q != S_DONE);
  assign done = (state_q == S_DONE);

  genvar gr;
  genvar gc;
  generate
    for (gr = 0; gr < ARRAY_N; gr = gr + 1) begin : gen_a_injection
      assign a_link[gr][0] = a_inject_q[gr];
      assign a_valid_link[gr][0] = a_inject_valid_q[gr];
    end

    for (gc = 0; gc < ARRAY_N; gc = gc + 1) begin : gen_b_injection
      assign b_link[0][gc] = b_inject_q[gc];
      assign b_valid_link[0][gc] = b_inject_valid_q[gc];
    end

    for (gr = 0; gr < ARRAY_N; gr = gr + 1) begin : gen_pe_row
      for (gc = 0; gc < ARRAY_N; gc = gc + 1) begin : gen_pe_col
        tinynpu_systolic_pe u_pe (
          .clk         (clk),
          .rst_n       (rst_n),
          .clear       (pe_clear),
          .a_in        (a_link[gr][gc]),
          .a_valid_in  (a_valid_link[gr][gc]),
          .a_out       (a_link[gr][gc+1]),
          .a_valid_out (a_valid_link[gr][gc+1]),
          .b_in        (b_link[gr][gc]),
          .b_valid_in  (b_valid_link[gr][gc]),
          .b_out       (b_link[gr+1][gc]),
          .b_valid_out (b_valid_link[gr+1][gc]),
          .acc_out     (pe_acc[gr][gc])
        );
      end
    end
  endgenerate

  always_ff @(posedge clk or negedge rst_n) begin
    int row;
    int col;

    if (!rst_n) begin
      state_q <= S_IDLE;
      step_q  <= '0;
      c_flat  <= '0;
      for (row = 0; row < ARRAY_N; row = row + 1) begin
        a_inject_q[row]       <= '0;
        a_inject_valid_q[row] <= 1'b0;
      end
      for (col = 0; col < ARRAY_N; col = col + 1) begin
        b_inject_q[col]       <= '0;
        b_inject_valid_q[col] <= 1'b0;
      end
    end else begin
      case (state_q)
        S_IDLE: begin
          if (start) begin
            state_q <= S_CLEAR;
            step_q  <= '0;
            c_flat  <= '0;
          end
        end

        S_CLEAR: begin
          step_q <= '0;
          for (row = 0; row < ARRAY_N; row = row + 1) begin
            a_inject_q[row]       <= '0;
            a_inject_valid_q[row] <= 1'b0;
          end
          for (col = 0; col < ARRAY_N; col = col + 1) begin
            b_inject_q[col]       <= '0;
            b_inject_valid_q[col] <= 1'b0;
          end
          state_q <= S_RUN;
        end

        S_RUN: begin
          for (row = 0; row < ARRAY_N; row = row + 1) begin
            a_inject_q[row]       <= '0;
            a_inject_valid_q[row] <= 1'b0;
            if ((step_q >= row) && (step_q < row + ARRAY_N)) begin
              a_inject_q[row] <=
                a_flat[((row * ARRAY_N) + (step_q - row))*`DATA_W +: `DATA_W];
              a_inject_valid_q[row] <= 1'b1;
            end
          end

          for (col = 0; col < ARRAY_N; col = col + 1) begin
            b_inject_q[col]       <= '0;
            b_inject_valid_q[col] <= 1'b0;
            if ((step_q >= col) && (step_q < col + ARRAY_N)) begin
              b_inject_q[col] <=
                b_flat[(((step_q - col) * ARRAY_N) + col)*`DATA_W +: `DATA_W];
              b_inject_valid_q[col] <= 1'b1;
            end
          end

          if (step_q == LAST_STEP) begin
            state_q <= S_FLUSH_PARTIAL;
          end else begin
            step_q <= step_q + 1'b1;
          end
        end

        S_FLUSH_PARTIAL: begin
          for (row = 0; row < ARRAY_N; row = row + 1) begin
            a_inject_q[row]       <= '0;
            a_inject_valid_q[row] <= 1'b0;
          end
          for (col = 0; col < ARRAY_N; col = col + 1) begin
            b_inject_q[col]       <= '0;
            b_inject_valid_q[col] <= 1'b0;
          end
          state_q <= S_FLUSH_PRODUCT;
        end

        S_FLUSH_PRODUCT: begin
          state_q <= S_FLUSH_ACC;
        end

        S_FLUSH_ACC: begin
          state_q <= S_CAPTURE;
        end

        S_CAPTURE: begin
          for (row = 0; row < ARRAY_N; row = row + 1) begin
            for (col = 0; col < ARRAY_N; col = col + 1) begin
              c_flat[((row * ARRAY_N) + col)*`ACC_W +: `ACC_W] <=
                pe_acc[row][col];
            end
          end
          state_q <= S_DONE;
        end

        S_DONE: begin
          state_q <= S_IDLE;
        end

        default: begin
          state_q <= S_IDLE;
        end
      endcase
    end
  end

endmodule
