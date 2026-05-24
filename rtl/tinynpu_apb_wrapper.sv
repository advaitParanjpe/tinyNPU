`timescale 1ns/1ps

module tinynpu_apb_wrapper (
  input  logic        pclk,
  input  logic        presetn,

  input  logic        psel,
  input  logic        penable,
  input  logic        pwrite,
  input  logic [7:0]  paddr,
  input  logic [31:0] pwdata,
  output logic [31:0] prdata,
  output logic        pready,
  output logic        pslverr
);

  logic        core_bus_valid;
  logic        core_bus_we;
  logic [7:0]  core_bus_addr;
  logic [31:0] core_bus_wdata;
  logic [31:0] core_bus_rdata;
  logic        core_bus_ready;
  logic        read_wait_q;

  assign pslverr = 1'b0;

  assign pready = (!psel || !penable) ? 1'b1 :
                  (pwrite ? core_bus_ready : read_wait_q);

  assign core_bus_valid = psel && penable && (pwrite || !read_wait_q);
  assign core_bus_we    = pwrite;
  assign core_bus_addr  = paddr;
  assign core_bus_wdata = pwdata;

  always_ff @(posedge pclk or negedge presetn) begin
    if (!presetn) begin
      prdata      <= 32'h0;
      read_wait_q <= 1'b0;
    end else begin
      if (psel && penable && !pwrite) begin
        if (!read_wait_q) begin
          read_wait_q <= 1'b1;
        end else begin
          prdata      <= core_bus_rdata;
          read_wait_q <= 1'b0;
        end
      end else begin
        read_wait_q <= 1'b0;
      end
    end
  end

  tinynpu_top u_core (
    .clk       (pclk),
    .rst_n     (presetn),
    .bus_valid (core_bus_valid),
    .bus_we    (core_bus_we),
    .bus_addr  (core_bus_addr),
    .bus_wdata (core_bus_wdata),
    .bus_rdata (core_bus_rdata),
    .bus_ready (core_bus_ready)
  );

endmodule
