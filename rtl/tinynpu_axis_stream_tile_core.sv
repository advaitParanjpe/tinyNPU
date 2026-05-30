`timescale 1ns/1ps

`include "tinynpu_defs.svh"

module tinynpu_axis_stream_tile_core (
  input  logic        clk,
  input  logic        rst_n,

  input  logic        s_axis_tvalid,
  output logic        s_axis_tready,
  input  logic [7:0]  s_axis_tdata,
  input  logic        s_axis_tlast,

  output logic        m_axis_tvalid,
  input  logic        m_axis_tready,
  output logic [31:0] m_axis_tdata,
  output logic        m_axis_tlast,

  output logic        busy,
  output logic        done,
  output logic        frame_error
);

  typedef enum logic [2:0] {
    S_LOAD_A,
    S_LOAD_B,
    S_START_MAC,
    S_WAIT_MAC,
    S_OUTPUT
  } state_t;

  state_t state_q;
  logic [4:0] input_idx_q;
  logic [3:0] output_idx_q;
  logic [`A_FLAT_W-1:0] a_flat_q;
  logic [`B_FLAT_W-1:0] b_flat_q;
  logic [`C_FLAT_W-1:0] c_flat_w;
  logic mac_start_q;
  logic mac_busy_w;
  logic mac_done_w;
  logic done_q;

  wire input_fire = s_axis_tvalid && s_axis_tready;
  wire output_fire = m_axis_tvalid && m_axis_tready;

  assign s_axis_tready = (state_q == S_LOAD_A) || (state_q == S_LOAD_B);
  assign m_axis_tvalid = (state_q == S_OUTPUT);
  assign m_axis_tdata = c_flat_w[output_idx_q*`ACC_W +: `ACC_W];
  assign m_axis_tlast = (state_q == S_OUTPUT) && (output_idx_q == `MATRIX_ELEMS-1);
  assign busy = (state_q == S_START_MAC) || (state_q == S_WAIT_MAC) || (state_q == S_OUTPUT);
  assign done = done_q;

  tinynpu_mac_row4_pipe2 u_mac (
    .clk    (clk),
    .rst_n  (rst_n),
    .start  (mac_start_q),
    .a_flat (a_flat_q),
    .b_flat (b_flat_q),
    .busy   (mac_busy_w),
    .done   (mac_done_w),
    .c_flat (c_flat_w)
  );

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state_q      <= S_LOAD_A;
      input_idx_q  <= '0;
      output_idx_q <= '0;
      a_flat_q     <= '0;
      b_flat_q     <= '0;
      mac_start_q  <= 1'b0;
      done_q       <= 1'b0;
      frame_error  <= 1'b0;
    end else begin
      mac_start_q <= 1'b0;
      done_q      <= 1'b0;

      case (state_q)
        S_LOAD_A: begin
          if (input_fire) begin
            if (input_idx_q == '0) begin
              frame_error <= 1'b0;
              a_flat_q    <= '0;
              b_flat_q    <= '0;
            end

            a_flat_q[input_idx_q*`DATA_W +: `DATA_W] <= s_axis_tdata;

            if (s_axis_tlast) begin
              frame_error <= 1'b1;
              input_idx_q <= '0;
              state_q     <= S_LOAD_A;
            end else if (input_idx_q == `MATRIX_ELEMS-1) begin
              input_idx_q <= '0;
              state_q     <= S_LOAD_B;
            end else begin
              input_idx_q <= input_idx_q + 1'b1;
            end
          end
        end

        S_LOAD_B: begin
          if (input_fire) begin
            b_flat_q[input_idx_q*`DATA_W +: `DATA_W] <= s_axis_tdata;

            if (input_idx_q == `MATRIX_ELEMS-1) begin
              input_idx_q <= '0;
              if (s_axis_tlast) begin
                mac_start_q <= 1'b1;
                state_q     <= S_START_MAC;
              end else begin
                frame_error <= 1'b1;
                state_q     <= S_LOAD_A;
              end
            end else if (s_axis_tlast) begin
              frame_error <= 1'b1;
              input_idx_q <= '0;
              state_q     <= S_LOAD_A;
            end else begin
              input_idx_q <= input_idx_q + 1'b1;
            end
          end
        end

        S_START_MAC: begin
          state_q <= S_WAIT_MAC;
        end

        S_WAIT_MAC: begin
          if (mac_done_w) begin
            output_idx_q <= '0;
            state_q      <= S_OUTPUT;
          end
        end

        S_OUTPUT: begin
          if (output_fire) begin
            if (output_idx_q == `MATRIX_ELEMS-1) begin
              output_idx_q <= '0;
              done_q       <= 1'b1;
              state_q      <= S_LOAD_A;
            end else begin
              output_idx_q <= output_idx_q + 1'b1;
            end
          end
        end

        default: begin
          state_q <= S_LOAD_A;
        end
      endcase
    end
  end

endmodule
