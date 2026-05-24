`timescale 1ns/1ps

import tinynpu_pkg::*;

module tinynpu_scratchpad_i8 (
  input  logic                 clk,
  input  logic                 rst_n,

  input  logic                 write_en,
  input  logic [3:0]           write_idx,
  input  logic signed [DATA_W-1:0] write_data,

  input  logic [3:0]           read_idx,
  output logic signed [DATA_W-1:0] read_data,
  output logic [A_FLAT_W-1:0]  flat_data
);

  logic signed [DATA_W-1:0] mem [0:MATRIX_ELEMS-1];

  genvar g;

  generate
    for (g = 0; g < MATRIX_ELEMS; g = g + 1) begin : gen_flatten
      assign flat_data[g*DATA_W +: DATA_W] = mem[g];
    end
  endgenerate

  assign read_data = mem[read_idx];

  always_ff @(posedge clk or negedge rst_n) begin
    int idx;

    if (!rst_n) begin
      for (idx = 0; idx < MATRIX_ELEMS; idx = idx + 1) begin
        mem[idx] <= '0;
      end
    end else if (write_en) begin
      mem[write_idx] <= write_data;
    end
  end

endmodule
