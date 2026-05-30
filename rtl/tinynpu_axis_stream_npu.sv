`timescale 1ns/1ps

`include "tinynpu_defs.svh"

module tinynpu_axis_stream_npu (
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
  output logic        frame_error
);

  localparam logic [1:0] IN_FREE    = 2'd0;
  localparam logic [1:0] IN_LOADING = 2'd1;
  localparam logic [1:0] IN_FULL    = 2'd2;
  localparam logic [1:0] IN_COMPUTE = 2'd3;

  localparam logic [1:0] OUT_FREE    = 2'd0;
  localparam logic [1:0] OUT_COMPUTE = 2'd1;
  localparam logic [1:0] OUT_FULL    = 2'd2;
  localparam logic [1:0] OUT_STREAM  = 2'd3;

  typedef enum logic [1:0] {
    C_IDLE,
    C_START,
    C_WAIT
  } compute_state_t;

  logic [1:0] in_state0_q;
  logic [1:0] in_state1_q;
  logic [1:0] out_state0_q;
  logic [1:0] out_state1_q;
  logic load_active_q;
  logic load_buf_q;
  logic [5:0] load_idx_q;
  logic stream_active_q;
  logic stream_buf_q;
  logic [3:0] stream_idx_q;
  logic comp_in_buf_q;
  logic comp_out_buf_q;
  logic mac_start_q;
  logic mac_busy_w;
  logic mac_done_w;
  logic [`A_FLAT_W-1:0] a_buf0_q;
  logic [`A_FLAT_W-1:0] a_buf1_q;
  logic [`B_FLAT_W-1:0] b_buf0_q;
  logic [`B_FLAT_W-1:0] b_buf1_q;
  logic [`C_FLAT_W-1:0] c_buf0_q;
  logic [`C_FLAT_W-1:0] c_buf1_q;
  logic [`C_FLAT_W-1:0] mac_c_flat_w;
  compute_state_t compute_state_q;

  wire input_buf0_free = (in_state0_q == IN_FREE);
  wire input_buf1_free = (in_state1_q == IN_FREE);
  wire output_buf0_free = (out_state0_q == OUT_FREE);
  wire output_buf1_free = (out_state1_q == OUT_FREE);
  wire input_buf_available = input_buf0_free || input_buf1_free;
  wire output_buf_available = output_buf0_free || output_buf1_free;
  wire load_target_buf = load_active_q ? load_buf_q : (input_buf0_free ? 1'b0 : 1'b1);
  wire input_fire = s_axis_tvalid && s_axis_tready;
  wire output_fire = m_axis_tvalid && m_axis_tready;
  wire [`A_FLAT_W-1:0] mac_a_flat_w = comp_in_buf_q ? a_buf1_q : a_buf0_q;
  wire [`B_FLAT_W-1:0] mac_b_flat_w = comp_in_buf_q ? b_buf1_q : b_buf0_q;
  wire [`C_FLAT_W-1:0] stream_c_flat_w = stream_buf_q ? c_buf1_q : c_buf0_q;

  assign s_axis_tready = load_active_q || input_buf_available;
  assign m_axis_tvalid = stream_active_q;
  assign m_axis_tdata = stream_c_flat_w[stream_idx_q*`ACC_W +: `ACC_W];
  assign m_axis_tlast = stream_active_q && (stream_idx_q == `MATRIX_ELEMS-1);
  assign busy = load_active_q || stream_active_q || (compute_state_q != C_IDLE) ||
                (in_state0_q != IN_FREE) || (in_state1_q != IN_FREE) ||
                (out_state0_q != OUT_FREE) || (out_state1_q != OUT_FREE);

  tinynpu_mac_row4_pipe2 u_mac (
    .clk    (clk),
    .rst_n  (rst_n),
    .start  (mac_start_q),
    .a_flat (mac_a_flat_w),
    .b_flat (mac_b_flat_w),
    .busy   (mac_busy_w),
    .done   (mac_done_w),
    .c_flat (mac_c_flat_w)
  );

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      in_state0_q     <= IN_FREE;
      in_state1_q     <= IN_FREE;
      out_state0_q    <= OUT_FREE;
      out_state1_q    <= OUT_FREE;
      load_active_q   <= 1'b0;
      load_buf_q      <= 1'b0;
      load_idx_q      <= '0;
      stream_active_q <= 1'b0;
      stream_buf_q    <= 1'b0;
      stream_idx_q    <= '0;
      comp_in_buf_q   <= 1'b0;
      comp_out_buf_q  <= 1'b0;
      mac_start_q     <= 1'b0;
      compute_state_q <= C_IDLE;
      a_buf0_q        <= '0;
      a_buf1_q        <= '0;
      b_buf0_q        <= '0;
      b_buf1_q        <= '0;
      c_buf0_q        <= '0;
      c_buf1_q        <= '0;
      frame_error     <= 1'b0;
    end else begin
      mac_start_q <= 1'b0;

      if (input_fire) begin
        if (!load_active_q) begin
          load_active_q <= 1'b1;
          load_buf_q    <= load_target_buf;
          load_idx_q    <= '0;
          frame_error   <= 1'b0;
          if (load_target_buf) begin
            in_state1_q <= IN_LOADING;
            a_buf1_q    <= '0;
            b_buf1_q    <= '0;
          end else begin
            in_state0_q <= IN_LOADING;
            a_buf0_q    <= '0;
            b_buf0_q    <= '0;
          end
        end

        if (load_idx_q < `MATRIX_ELEMS) begin
          if (load_target_buf) begin
            a_buf1_q[load_idx_q*`DATA_W +: `DATA_W] <= s_axis_tdata;
          end else begin
            a_buf0_q[load_idx_q*`DATA_W +: `DATA_W] <= s_axis_tdata;
          end
        end else begin
          if (load_target_buf) begin
            b_buf1_q[(load_idx_q-`MATRIX_ELEMS)*`DATA_W +: `DATA_W] <= s_axis_tdata;
          end else begin
            b_buf0_q[(load_idx_q-`MATRIX_ELEMS)*`DATA_W +: `DATA_W] <= s_axis_tdata;
          end
        end

        if ((s_axis_tlast && (load_idx_q != (`MATRIX_ELEMS*2)-1)) ||
            (!s_axis_tlast && (load_idx_q == (`MATRIX_ELEMS*2)-1))) begin
          frame_error   <= 1'b1;
          load_active_q <= 1'b0;
          load_idx_q    <= '0;
          if (load_target_buf) begin
            in_state1_q <= IN_FREE;
          end else begin
            in_state0_q <= IN_FREE;
          end
        end else if (load_idx_q == (`MATRIX_ELEMS*2)-1) begin
          load_active_q <= 1'b0;
          load_idx_q    <= '0;
          if (load_target_buf) begin
            in_state1_q <= IN_FULL;
          end else begin
            in_state0_q <= IN_FULL;
          end
        end else begin
          load_idx_q <= load_idx_q + 1'b1;
        end
      end

      case (compute_state_q)
        C_IDLE: begin
          if (output_buf_available && (in_state0_q == IN_FULL || in_state1_q == IN_FULL)) begin
            comp_in_buf_q  <= (in_state0_q == IN_FULL) ? 1'b0 : 1'b1;
            comp_out_buf_q <= output_buf0_free ? 1'b0 : 1'b1;
            if (in_state0_q == IN_FULL) begin
              in_state0_q <= IN_COMPUTE;
            end else begin
              in_state1_q <= IN_COMPUTE;
            end
            if (output_buf0_free) begin
              out_state0_q <= OUT_COMPUTE;
            end else begin
              out_state1_q <= OUT_COMPUTE;
            end
            compute_state_q <= C_START;
          end
        end

        C_START: begin
          mac_start_q     <= 1'b1;
          compute_state_q <= C_WAIT;
        end

        C_WAIT: begin
          if (mac_done_w) begin
            if (comp_out_buf_q) begin
              c_buf1_q     <= mac_c_flat_w;
              out_state1_q <= OUT_FULL;
            end else begin
              c_buf0_q     <= mac_c_flat_w;
              out_state0_q <= OUT_FULL;
            end
            if (comp_in_buf_q) begin
              in_state1_q <= IN_FREE;
            end else begin
              in_state0_q <= IN_FREE;
            end
            compute_state_q <= C_IDLE;
          end
        end

        default: begin
          compute_state_q <= C_IDLE;
        end
      endcase

      if (stream_active_q) begin
        if (output_fire) begin
          if (stream_idx_q == `MATRIX_ELEMS-1) begin
            stream_active_q <= 1'b0;
            stream_idx_q    <= '0;
            if (stream_buf_q) begin
              out_state1_q <= OUT_FREE;
            end else begin
              out_state0_q <= OUT_FREE;
            end
          end else begin
            stream_idx_q <= stream_idx_q + 1'b1;
          end
        end
      end else begin
        if (out_state0_q == OUT_FULL) begin
          stream_active_q <= 1'b1;
          stream_buf_q    <= 1'b0;
          stream_idx_q    <= '0;
          out_state0_q    <= OUT_STREAM;
        end else if (out_state1_q == OUT_FULL) begin
          stream_active_q <= 1'b1;
          stream_buf_q    <= 1'b1;
          stream_idx_q    <= '0;
          out_state1_q    <= OUT_STREAM;
        end
      end
    end
  end

endmodule
