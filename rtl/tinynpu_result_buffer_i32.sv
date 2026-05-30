`timescale 1ns/1ps

`include "tinynpu_defs.svh"

module tinynpu_result_buffer_i32 (
  input  logic                 clk,
  input  logic                 rst_n,

  input  logic                 load_en,
  input  logic [`C_FLAT_W-1:0]  load_flat_data,

  input  logic [3:0]           read_idx,
  output logic signed [`ACC_W-1:0] read_data,
  output logic [`C_FLAT_W-1:0]  flat_data
);

  logic signed [`ACC_W-1:0] mem [0:`MATRIX_ELEMS-1];

  genvar g;

  generate
    for (g = 0; g < `MATRIX_ELEMS; g = g + 1) begin : gen_flatten
      assign flat_data[g*`ACC_W +: `ACC_W] = mem[g];
    end
  endgenerate

  assign read_data = mem[read_idx];

  always_ff @(posedge clk or negedge rst_n) begin
    int idx;

    if (!rst_n) begin
      for (idx = 0; idx < `MATRIX_ELEMS; idx = idx + 1) begin
        mem[idx] <= '0;
      end
    end else if (load_en) begin
      for (idx = 0; idx < `MATRIX_ELEMS; idx = idx + 1) begin
        mem[idx] <= load_flat_data[idx*`ACC_W +: `ACC_W];
      end
    end
  end

endmodule
