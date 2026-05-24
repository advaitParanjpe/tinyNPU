`timescale 1ns/1ps

package tinynpu_pkg;
  parameter int MATRIX_N = 4;
  parameter int DATA_W   = 8;
  parameter int ACC_W    = 32;

  parameter int MATRIX_ELEMS = MATRIX_N * MATRIX_N;
  parameter int A_FLAT_W     = MATRIX_ELEMS * DATA_W;
  parameter int B_FLAT_W     = MATRIX_ELEMS * DATA_W;
  parameter int C_FLAT_W     = MATRIX_ELEMS * ACC_W;

  typedef logic signed [DATA_W-1:0] data_t;
  typedef logic signed [ACC_W-1:0]  acc_t;
endpackage
