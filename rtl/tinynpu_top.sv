`timescale 1ns/1ps

import tinynpu_pkg::*;

module tinynpu_top (
  input  logic        clk,
  input  logic        rst_n,

  input  logic        bus_valid,
  input  logic        bus_we,
  input  logic [7:0]  bus_addr,
  input  logic [31:0] bus_wdata,
  output logic [31:0] bus_rdata,
  output logic        bus_ready
);

  localparam logic [7:0] ADDR_CTRL   = 8'h00;
  localparam logic [7:0] ADDR_STATUS = 8'h04;
  localparam logic [7:0] ADDR_A_BASE = 8'h10;
  localparam logic [7:0] ADDR_B_BASE = 8'h50;
  localparam logic [7:0] ADDR_C_BASE = 8'h90;

  logic signed [DATA_W-1:0] a_mem [0:MATRIX_ELEMS-1];
  logic signed [DATA_W-1:0] b_mem [0:MATRIX_ELEMS-1];
  logic signed [ACC_W-1:0]  c_mem [0:MATRIX_ELEMS-1];

  logic [A_FLAT_W-1:0] mac_a_flat;
  logic [B_FLAT_W-1:0] mac_b_flat;
  logic [C_FLAT_W-1:0] mac_c_flat;
  logic                mac_start;
  logic                mac_busy;
  logic                mac_done;
  logic                done_q;

  genvar g;

`ifdef TINYNPU_SIM_ASSERT
  logic                debug_start_accepted;
  logic                debug_start_while_busy;
  logic [C_FLAT_W-1:0] debug_c_flat;
`endif

  assign bus_ready = 1'b1;

  generate
    for (g = 0; g < MATRIX_ELEMS; g = g + 1) begin : gen_flatten_inputs
      assign mac_a_flat[g*DATA_W +: DATA_W] = a_mem[g];
      assign mac_b_flat[g*DATA_W +: DATA_W] = b_mem[g];
`ifdef TINYNPU_SIM_ASSERT
      assign debug_c_flat[g*ACC_W +: ACC_W] = c_mem[g];
`endif
    end
  endgenerate

  always_ff @(posedge clk or negedge rst_n) begin
    int idx;

    if (!rst_n) begin
      mac_start <= 1'b0;
      done_q    <= 1'b0;
      bus_rdata <= 32'h0;
`ifdef TINYNPU_SIM_ASSERT
      debug_start_accepted <= 1'b0;
      debug_start_while_busy <= 1'b0;
`endif
      for (idx = 0; idx < MATRIX_ELEMS; idx = idx + 1) begin
        a_mem[idx] <= '0;
        b_mem[idx] <= '0;
        c_mem[idx] <= '0;
      end
    end else begin
      mac_start <= 1'b0;
`ifdef TINYNPU_SIM_ASSERT
      debug_start_accepted <= 1'b0;
      debug_start_while_busy <= 1'b0;
`endif

      if (mac_done) begin
        done_q <= 1'b1;
        for (idx = 0; idx < MATRIX_ELEMS; idx = idx + 1) begin
          c_mem[idx] <= mac_c_flat[idx*ACC_W +: ACC_W];
        end
      end

      if (bus_valid && bus_we) begin
        if ((bus_addr >= ADDR_A_BASE) && (bus_addr <= 8'h4c) && (bus_addr[1:0] == 2'b00)) begin
          a_mem[(bus_addr - ADDR_A_BASE) >> 2] <= bus_wdata[DATA_W-1:0];
        end else if ((bus_addr >= ADDR_B_BASE) && (bus_addr <= 8'h8c) && (bus_addr[1:0] == 2'b00)) begin
          b_mem[(bus_addr - ADDR_B_BASE) >> 2] <= bus_wdata[DATA_W-1:0];
        end else if (bus_addr == ADDR_CTRL) begin
          if (bus_wdata[1]) begin
            done_q <= 1'b0;
          end

`ifdef TINYNPU_SIM_ASSERT
          if (bus_wdata[0] && mac_busy) begin
            debug_start_while_busy <= 1'b1;
          end
`endif

          if (bus_wdata[0] && !mac_busy) begin
            mac_start <= 1'b1;
            done_q    <= 1'b0;
`ifdef TINYNPU_SIM_ASSERT
            debug_start_accepted <= 1'b1;
`endif
          end
        end
      end else if (bus_valid && !bus_we) begin
        if (bus_addr == ADDR_STATUS) begin
          bus_rdata <= {30'h0, done_q, mac_busy};
        end else if ((bus_addr >= ADDR_A_BASE) && (bus_addr <= 8'h4c) && (bus_addr[1:0] == 2'b00)) begin
          bus_rdata <= $signed(a_mem[(bus_addr - ADDR_A_BASE) >> 2]);
        end else if ((bus_addr >= ADDR_B_BASE) && (bus_addr <= 8'h8c) && (bus_addr[1:0] == 2'b00)) begin
          bus_rdata <= $signed(b_mem[(bus_addr - ADDR_B_BASE) >> 2]);
        end else if ((bus_addr >= ADDR_C_BASE) && (bus_addr <= 8'hcc) && (bus_addr[1:0] == 2'b00)) begin
          bus_rdata <= c_mem[(bus_addr - ADDR_C_BASE) >> 2];
        end else begin
          bus_rdata <= 32'h0;
        end
      end
    end
  end

  tinynpu_mac_array u_mac_array (
    .clk    (clk),
    .rst_n  (rst_n),
    .start  (mac_start),
    .a_flat (mac_a_flat),
    .b_flat (mac_b_flat),
    .busy   (mac_busy),
    .done   (mac_done),
    .c_flat (mac_c_flat)
  );

`ifdef TINYNPU_SIM_ASSERT
  tinynpu_assertions u_tinynpu_assertions (
    .clk                    (clk),
    .rst_n                  (rst_n),
    .busy                   (mac_busy),
    .done                   (done_q),
    .start_accepted         (debug_start_accepted),
    .start_while_busy       (debug_start_while_busy),
    .c_flat                 (debug_c_flat)
  );
`endif

endmodule
