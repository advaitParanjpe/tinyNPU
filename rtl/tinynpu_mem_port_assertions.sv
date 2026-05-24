`timescale 1ns/1ps

module tinynpu_mem_port_assertions (
  input logic        clk,
  input logic        rst_n,
  input logic        mem_valid,
  input logic        mem_we,
  input logic [31:0] mem_addr,
  input logic [31:0] mem_wdata,
  input logic [31:0] mem_rdata,
  input logic        mem_ready
);

`ifdef TINYNPU_SIM_ASSERT
  logic        stalled_q;
  logic        stalled_we_q;
  logic [31:0] stalled_addr_q;
  logic [31:0] stalled_wdata_q;

  function automatic has_x_1(input logic value);
    begin
      has_x_1 = (value !== 1'b0) && (value !== 1'b1);
    end
  endfunction

  function automatic has_x_32(input logic [31:0] value);
    begin
      has_x_32 = (^value === 1'bx);
    end
  endfunction

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      stalled_q      <= 1'b0;
      stalled_we_q   <= 1'b0;
      stalled_addr_q <= 32'h0;
      stalled_wdata_q <= 32'h0;
    end else begin
      #1;

      if (has_x_1(mem_valid)) begin
        $display("ASSERT FAIL mem_port_valid_known: mem_valid is X/Z");
        $fatal(1);
      end

      if (mem_valid) begin
        if (has_x_1(mem_we)) begin
          $display("ASSERT FAIL mem_port_we_known: mem_we is X/Z while mem_valid");
          $fatal(1);
        end
        if (has_x_32(mem_addr)) begin
          $display("ASSERT FAIL mem_port_addr_known: mem_addr is X/Z while mem_valid");
          $fatal(1);
        end
        if (mem_we && has_x_32(mem_wdata)) begin
          $display("ASSERT FAIL mem_port_wdata_known: mem_wdata is X/Z during write");
          $fatal(1);
        end
      end

      if (stalled_q) begin
        if (!mem_valid) begin
          $display("ASSERT FAIL mem_port_valid_held: mem_valid dropped before mem_ready");
          $fatal(1);
        end
        if (mem_addr !== stalled_addr_q) begin
          $display("ASSERT FAIL mem_port_addr_stable: addr changed while stalled expected=0x%08x actual=0x%08x",
                   stalled_addr_q, mem_addr);
          $fatal(1);
        end
        if (mem_we !== stalled_we_q) begin
          $display("ASSERT FAIL mem_port_we_stable: mem_we changed while stalled expected=%0b actual=%0b",
                   stalled_we_q, mem_we);
          $fatal(1);
        end
        if (stalled_we_q && (mem_wdata !== stalled_wdata_q)) begin
          $display("ASSERT FAIL mem_port_wdata_stable: wdata changed while stalled expected=0x%08x actual=0x%08x",
                   stalled_wdata_q, mem_wdata);
          $fatal(1);
        end

        if (mem_ready) begin
          stalled_q <= 1'b0;
        end
      end else if (mem_valid && !mem_ready) begin
        stalled_q      <= 1'b1;
        stalled_we_q   <= mem_we;
        stalled_addr_q <= mem_addr;
        stalled_wdata_q <= mem_wdata;
      end
    end
  end
`endif

endmodule
