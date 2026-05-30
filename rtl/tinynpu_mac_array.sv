`timescale 1ns/1ps

`include "tinynpu_defs.svh"

module tinynpu_mac_array (
  input  logic                  clk,
  input  logic                  rst_n,
  input  logic                  start,
  input  logic [`A_FLAT_W-1:0]   a_flat,
  input  logic [`B_FLAT_W-1:0]   b_flat,
  output logic                  busy,
  output logic                  done,
  output logic [`C_FLAT_W-1:0]   c_flat
);

`ifdef TINYNPU_MAC_SERIAL
  tinynpu_mac_serial u_mac (
`elsif TINYNPU_MAC_ROW4_PIPE3
  tinynpu_mac_row4_pipe3 u_mac (
`elsif TINYNPU_MAC_ROW4_PIPE2_DUPA
  tinynpu_mac_row4_pipe2_dupa u_mac (
`elsif TINYNPU_MAC_ROW4_PIPE2
  tinynpu_mac_row4_pipe2 u_mac (
`elsif TINYNPU_MAC_ROW4_PIPE
  tinynpu_mac_row4_pipe u_mac (
`elsif TINYNPU_MAC_FULL16
  tinynpu_mac_full16 u_mac (
`else
  tinynpu_mac_row4 u_mac (
`endif
    .clk    (clk),
    .rst_n  (rst_n),
    .start  (start),
    .a_flat (a_flat),
    .b_flat (b_flat),
    .busy   (busy),
    .done   (done),
    .c_flat (c_flat)
  );

endmodule
