`timescale 1ns/1ps

module tinynpu_dma_descriptor_wrapper (
  input  logic        pclk,
  input  logic        presetn,

  input  logic        psel,
  input  logic        penable,
  input  logic        pwrite,
  input  logic [11:0] paddr,
  input  logic [31:0] pwdata,
  output logic [31:0] prdata,
  output logic        pready,
  output logic        pslverr
);

  localparam logic [11:0] DMA_CTRL       = 12'h100;
  localparam logic [11:0] DMA_STATUS     = 12'h104;
  localparam logic [11:0] DMA_A_EXT_BASE = 12'h108;
  localparam logic [11:0] DMA_B_EXT_BASE = 12'h10c;
  localparam logic [11:0] DMA_C_EXT_BASE = 12'h110;
  localparam logic [11:0] DMA_CONFIG     = 12'h114;

  localparam logic [2:0] DESC_BUSY_CYCLES = 3'd4;

  logic        core_sel;
  logic        desc_sel;
  logic        apb_access;

  logic [31:0] core_prdata;
  logic        core_pready;
  logic        core_pslverr;
  logic [31:0] desc_prdata;

  logic        dma_busy;
  logic        dma_done;
  logic        dma_error;
  logic [31:0] dma_a_ext_base;
  logic [31:0] dma_b_ext_base;
  logic [31:0] dma_c_ext_base;
  logic [31:0] dma_config;
  logic [2:0]  busy_count;

  assign core_sel   = (paddr[11:8] == 4'h0);
  assign desc_sel   = (paddr >= 12'h100) && (paddr <= 12'h11f);
  assign apb_access = psel && penable;

  assign pready  = core_sel ? core_pready : 1'b1;
  assign pslverr = 1'b0;
  assign prdata  = core_sel ? core_prdata : desc_prdata;

  tinynpu_apb_wrapper u_core_apb (
    .pclk    (pclk),
    .presetn (presetn),
    .psel    (psel && core_sel),
    .penable (penable),
    .pwrite  (pwrite),
    .paddr   (paddr[7:0]),
    .pwdata  (pwdata),
    .prdata  (core_prdata),
    .pready  (core_pready),
    .pslverr (core_pslverr)
  );

  always_ff @(posedge pclk or negedge presetn) begin
    if (!presetn) begin
      desc_prdata    <= 32'h0;
      dma_busy       <= 1'b0;
      dma_done       <= 1'b0;
      dma_error      <= 1'b0;
      dma_a_ext_base <= 32'h0;
      dma_b_ext_base <= 32'h0;
      dma_c_ext_base <= 32'h0;
      dma_config     <= 32'h0;
      busy_count     <= 3'h0;
    end else begin
      if (dma_busy && (busy_count != 3'h0)) begin
        busy_count <= busy_count - 3'h1;
        if (busy_count == 3'h1) begin
          dma_busy <= 1'b0;
          dma_done <= 1'b1;
        end
      end

      if (apb_access && desc_sel && pwrite) begin
        case (paddr)
          DMA_CTRL: begin
            if (pwdata[1]) begin
              dma_done <= 1'b0;
            end
            if (pwdata[2]) begin
              dma_error <= 1'b0;
            end
            if (pwdata[0] && !dma_busy) begin
              dma_busy   <= 1'b1;
              dma_done   <= 1'b0;
              dma_error  <= 1'b0;
              busy_count <= DESC_BUSY_CYCLES;
            end
          end
          DMA_A_EXT_BASE: dma_a_ext_base <= pwdata;
          DMA_B_EXT_BASE: dma_b_ext_base <= pwdata;
          DMA_C_EXT_BASE: dma_c_ext_base <= pwdata;
          DMA_CONFIG:     dma_config     <= pwdata;
          default: begin
          end
        endcase
      end

      if (apb_access && !pwrite) begin
        if (core_sel && core_pready) begin
          desc_prdata <= 32'h0;
        end else if (desc_sel) begin
          case (paddr)
            DMA_CTRL:       desc_prdata <= 32'h0;
            DMA_STATUS:     desc_prdata <= {29'h0, dma_error, dma_done, dma_busy};
            DMA_A_EXT_BASE: desc_prdata <= dma_a_ext_base;
            DMA_B_EXT_BASE: desc_prdata <= dma_b_ext_base;
            DMA_C_EXT_BASE: desc_prdata <= dma_c_ext_base;
            DMA_CONFIG:     desc_prdata <= dma_config;
            default:        desc_prdata <= 32'h0;
          endcase
        end else begin
          desc_prdata <= 32'h0;
        end
      end
    end
  end

endmodule
