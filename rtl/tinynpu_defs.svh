`ifndef TINYNPU_DEFS_SVH
`define TINYNPU_DEFS_SVH

`define MATRIX_N 4
`define DATA_W 8
`define ACC_W 32

`define MATRIX_ELEMS (`MATRIX_N * `MATRIX_N)
`define A_FLAT_W (`MATRIX_ELEMS * `DATA_W)
`define B_FLAT_W (`MATRIX_ELEMS * `DATA_W)
`define C_FLAT_W (`MATRIX_ELEMS * `ACC_W)

`endif
