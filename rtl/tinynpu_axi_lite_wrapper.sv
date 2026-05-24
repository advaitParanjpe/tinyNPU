`timescale 1ns/1ps

module tinynpu_axi_lite_wrapper (
  input  logic        aclk,
  input  logic        aresetn,

  input  logic [11:0] s_axi_awaddr,
  input  logic        s_axi_awvalid,
  output logic        s_axi_awready,

  input  logic [31:0] s_axi_wdata,
  input  logic [3:0]  s_axi_wstrb,
  input  logic        s_axi_wvalid,
  output logic        s_axi_wready,

  output logic [1:0]  s_axi_bresp,
  output logic        s_axi_bvalid,
  input  logic        s_axi_bready,

  input  logic [11:0] s_axi_araddr,
  input  logic        s_axi_arvalid,
  output logic        s_axi_arready,

  output logic [31:0] s_axi_rdata,
  output logic [1:0]  s_axi_rresp,
  output logic        s_axi_rvalid,
  input  logic        s_axi_rready,

  output logic        mem_valid,
  output logic        mem_we,
  output logic [31:0] mem_addr,
  output logic [31:0] mem_wdata,
  input  logic [31:0] mem_rdata,
  input  logic        mem_ready,

  output logic        irq
);

  localparam logic [1:0] AXI_RESP_OKAY = 2'b00;

  localparam logic [1:0] WR_IDLE   = 2'd0;
  localparam logic [1:0] WR_SETUP  = 2'd1;
  localparam logic [1:0] WR_ACCESS = 2'd2;
  localparam logic [1:0] WR_RESP   = 2'd3;

  localparam logic [2:0] RD_IDLE    = 3'd0;
  localparam logic [2:0] RD_SETUP   = 3'd1;
  localparam logic [2:0] RD_ACCESS  = 3'd2;
  localparam logic [2:0] RD_CAPTURE = 3'd3;
  localparam logic [2:0] RD_RESP    = 3'd4;

  logic [1:0]  wr_state;
  logic [2:0]  rd_state;
  logic        aw_seen;
  logic        w_seen;
  logic [11:0] awaddr_q;
  logic [11:0] araddr_q;
  logic [31:0] wdata_q;
  logic [3:0]  wstrb_q;

  logic        psel;
  logic        penable;
  logic        pwrite;
  logic [11:0] paddr;
  logic [31:0] pwdata;
  logic [31:0] prdata;
  logic        pready;
  logic        pslverr;

  wire write_idle = (wr_state == WR_IDLE);
  wire read_idle  = (rd_state == RD_IDLE);
  wire write_can_accept = write_idle && read_idle && !s_axi_bvalid;
  wire read_can_accept  = read_idle && write_idle && !aw_seen && !w_seen && !s_axi_rvalid;

  assign s_axi_awready = write_can_accept && !aw_seen;
  assign s_axi_wready  = write_can_accept && !w_seen;
  assign s_axi_arready = read_can_accept;

  assign s_axi_bresp = AXI_RESP_OKAY;
  assign s_axi_rresp = AXI_RESP_OKAY;

  always_comb begin
    psel    = 1'b0;
    penable = 1'b0;
    pwrite  = 1'b0;
    paddr   = 12'h0;
    pwdata  = 32'h0;

    if ((wr_state == WR_SETUP) || (wr_state == WR_ACCESS)) begin
      psel    = 1'b1;
      penable = (wr_state == WR_ACCESS);
      pwrite  = 1'b1;
      paddr   = awaddr_q;
      pwdata  = wdata_q;
    end else if ((rd_state == RD_SETUP) || (rd_state == RD_ACCESS) || (rd_state == RD_CAPTURE)) begin
      psel    = 1'b1;
      penable = (rd_state == RD_ACCESS);
      pwrite  = 1'b0;
      paddr   = araddr_q;
      pwdata  = 32'h0;
    end
  end

  always_ff @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
      wr_state     <= WR_IDLE;
      rd_state     <= RD_IDLE;
      aw_seen      <= 1'b0;
      w_seen       <= 1'b0;
      awaddr_q     <= 12'h0;
      araddr_q     <= 12'h0;
      wdata_q      <= 32'h0;
      wstrb_q      <= 4'h0;
      s_axi_bvalid <= 1'b0;
      s_axi_rvalid <= 1'b0;
      s_axi_rdata  <= 32'h0;
    end else begin
      if (s_axi_bvalid && s_axi_bready) begin
        s_axi_bvalid <= 1'b0;
      end

      if (s_axi_rvalid && s_axi_rready) begin
        s_axi_rvalid <= 1'b0;
      end

      if (s_axi_awready && s_axi_awvalid) begin
        aw_seen  <= 1'b1;
        awaddr_q <= s_axi_awaddr;
      end

      if (s_axi_wready && s_axi_wvalid) begin
        w_seen  <= 1'b1;
        wdata_q <= s_axi_wdata;
        wstrb_q <= s_axi_wstrb;
      end

      case (wr_state)
        WR_IDLE: begin
          if (((aw_seen || (s_axi_awready && s_axi_awvalid)) &&
               (w_seen || (s_axi_wready && s_axi_wvalid))) &&
              !s_axi_bvalid) begin
            if ((s_axi_wready && s_axi_wvalid ? s_axi_wstrb : wstrb_q) == 4'hf) begin
              wr_state <= WR_SETUP;
            end else begin
              aw_seen      <= 1'b0;
              w_seen       <= 1'b0;
              s_axi_bvalid <= 1'b1;
              wr_state     <= WR_RESP;
            end
          end
        end

        WR_SETUP: begin
          wr_state <= WR_ACCESS;
        end

        WR_ACCESS: begin
          if (pready) begin
            aw_seen      <= 1'b0;
            w_seen       <= 1'b0;
            s_axi_bvalid <= 1'b1;
            wr_state     <= WR_RESP;
          end
        end

        WR_RESP: begin
          if (s_axi_bvalid && s_axi_bready) begin
            wr_state <= WR_IDLE;
          end
        end

        default: wr_state <= WR_IDLE;
      endcase

      case (rd_state)
        RD_IDLE: begin
          if (s_axi_arready && s_axi_arvalid) begin
            araddr_q <= s_axi_araddr;
            rd_state <= RD_SETUP;
          end
        end

        RD_SETUP: begin
          rd_state <= RD_ACCESS;
        end

        RD_ACCESS: begin
          if (pready) begin
            rd_state <= RD_CAPTURE;
          end
        end

        RD_CAPTURE: begin
          s_axi_rdata  <= prdata;
          s_axi_rvalid <= 1'b1;
          rd_state     <= RD_RESP;
        end

        RD_RESP: begin
          if (s_axi_rvalid && s_axi_rready) begin
            rd_state <= RD_IDLE;
          end
        end

        default: rd_state <= RD_IDLE;
      endcase
    end
  end

  tinynpu_dma_descriptor_wrapper u_dma_desc (
    .pclk      (aclk),
    .presetn   (aresetn),
    .psel      (psel),
    .penable   (penable),
    .pwrite    (pwrite),
    .paddr     (paddr),
    .pwdata    (pwdata),
    .prdata    (prdata),
    .pready    (pready),
    .pslverr   (pslverr),
    .mem_valid (mem_valid),
    .mem_we    (mem_we),
    .mem_addr  (mem_addr),
    .mem_wdata (mem_wdata),
    .mem_rdata (mem_rdata),
    .mem_ready (mem_ready),
    .irq       (irq)
  );

endmodule
