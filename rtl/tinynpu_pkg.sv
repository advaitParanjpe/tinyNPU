`timescale 1ns/1ps

`include "tinynpu_defs.svh"

package tinynpu_pkg;
  parameter int MATRIX_N = `MATRIX_N;
  parameter int DATA_W   = `DATA_W;
  parameter int ACC_W    = `ACC_W;

  parameter int MATRIX_ELEMS = `MATRIX_ELEMS;
  parameter int A_FLAT_W     = `A_FLAT_W;
  parameter int B_FLAT_W     = `B_FLAT_W;
  parameter int C_FLAT_W     = `C_FLAT_W;

  typedef logic signed [DATA_W-1:0] data_t;
  typedef logic signed [ACC_W-1:0]  acc_t;
endpackage
