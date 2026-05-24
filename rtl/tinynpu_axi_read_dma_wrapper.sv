`timescale 1ns/1ps

module tinynpu_axi_read_dma_wrapper (
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

  output logic [31:0] m_axi_araddr,
  output logic [7:0]  m_axi_arlen,
  output logic [2:0]  m_axi_arsize,
  output logic [1:0]  m_axi_arburst,
  output logic        m_axi_arvalid,
  input  logic        m_axi_arready,
  input  logic [31:0] m_axi_rdata,
  input  logic [1:0]  m_axi_rresp,
  input  logic        m_axi_rvalid,
  output logic        m_axi_rready,
  input  logic        m_axi_rlast,

  output logic        c_mem_valid,
  output logic [31:0] c_mem_addr,
  output logic [31:0] c_mem_wdata,
  input  logic        c_mem_ready,

  output logic        irq
);

  localparam logic [1:0] AXI_RESP_OKAY  = 2'b00;
  localparam logic [1:0] AXI_BURST_INCR = 2'b01;

  localparam logic [11:0] DMA_CTRL       = 12'h100;
  localparam logic [11:0] DMA_STATUS     = 12'h104;
  localparam logic [11:0] DMA_A_EXT_BASE = 12'h108;
  localparam logic [11:0] DMA_B_EXT_BASE = 12'h10c;
  localparam logic [11:0] DMA_C_EXT_BASE = 12'h110;
  localparam logic [11:0] DMA_CONFIG     = 12'h114;
  localparam logic [11:0] DMA_ERROR_CODE = 12'h118;
  localparam logic [11:0] DMA_IRQ_ENABLE = 12'h11c;
  localparam logic [11:0] DMA_IRQ_STATUS = 12'h120;

  localparam logic [31:0] ERROR_NONE          = 32'd0;
  localparam logic [31:0] ERROR_MEM_TIMEOUT   = 32'd1;
  localparam logic [31:0] ERROR_CORE_TIMEOUT  = 32'd2;
  localparam logic [31:0] ERROR_AXI_RRESP     = 32'd3;

  localparam logic [15:0] MEM_TIMEOUT_DEFAULT  = 16'd1024;
  localparam logic [15:0] CORE_TIMEOUT_DEFAULT = 16'd1024;

  localparam logic [7:0] CORE_ADDR_CTRL   = 8'h00;
  localparam logic [7:0] CORE_ADDR_STATUS = 8'h04;
  localparam logic [7:0] CORE_ADDR_A_BASE = 8'h10;
  localparam logic [7:0] CORE_ADDR_B_BASE = 8'h50;
  localparam logic [7:0] CORE_ADDR_C_BASE = 8'h90;

  localparam logic [2:0] WR_IDLE   = 2'd0;
  localparam logic [2:0] WR_SETUP  = 2'd1;
  localparam logic [2:0] WR_ACCESS = 2'd2;
  localparam logic [2:0] WR_RESP   = 2'd3;

  localparam logic [2:0] RD_IDLE    = 3'd0;
  localparam logic [2:0] RD_SETUP   = 3'd1;
  localparam logic [2:0] RD_ACCESS  = 3'd2;
  localparam logic [2:0] RD_CAPTURE = 3'd3;
  localparam logic [2:0] RD_RESP    = 3'd4;

  localparam logic [2:0] DMA_IDLE       = 3'd0;
  localparam logic [2:0] DMA_LOAD_A     = 3'd1;
  localparam logic [2:0] DMA_LOAD_B     = 3'd2;
  localparam logic [2:0] DMA_START_CORE = 3'd3;
  localparam logic [2:0] DMA_WAIT_CORE  = 3'd4;
  localparam logic [2:0] DMA_STORE_C    = 3'd5;
  localparam logic [2:0] DMA_DONE       = 3'd6;

  localparam logic [2:0] PHASE_AXI_AR       = 3'd0;
  localparam logic [2:0] PHASE_AXI_R        = 3'd1;
  localparam logic [2:0] PHASE_CORE_WRITE   = 3'd2;
  localparam logic [2:0] PHASE_CORE_READ    = 3'd3;
  localparam logic [2:0] PHASE_CORE_CAPTURE = 3'd4;
  localparam logic [2:0] PHASE_C_WRITE      = 3'd5;
  localparam logic [2:0] PHASE_CORE_GAP     = 3'd6;

  logic [1:0]  wr_state;
  logic [2:0]  rd_state;
  logic        aw_seen;
  logic        w_seen;
  logic [11:0] awaddr_q;
  logic [11:0] araddr_q;
  logic [31:0] wdata_q;
  logic [3:0]  wstrb_q;

  logic        bus_access;
  logic        bus_write;
  logic [11:0] bus_addr;
  logic [31:0] bus_wdata;
  logic [31:0] bus_rdata;
  logic        bus_ready;
  logic        core_sel;
  logic        desc_sel;
  logic        external_core_access;

  logic [31:0] core_prdata;
  logic        core_pready;
  logic        core_pslverr;
  logic        core_psel;
  logic        core_penable;
  logic        core_pwrite;
  logic [7:0]  core_paddr;
  logic [31:0] core_pwdata;
  logic        internal_core_access;
  logic        internal_core_write;
  logic [7:0]  internal_core_addr;
  logic [31:0] internal_core_wdata;

  logic        dma_busy;
  logic        dma_done;
  logic        dma_error;
  logic [31:0] dma_a_ext_base;
  logic [31:0] dma_b_ext_base;
  logic [31:0] dma_c_ext_base;
  logic [31:0] dma_config;
  logic [31:0] dma_error_code;
  logic [1:0]  dma_irq_enable;
  logic        done_irq_pending;
  logic        error_irq_pending;
  logic [2:0]  dma_state;
  logic [2:0]  dma_phase;
  logic [3:0]  dma_idx;
  logic [31:0] dma_data_q;
  logic [15:0] mem_timeout_count;
  logic [15:0] core_timeout_count;
  logic [15:0] mem_timeout_limit;
  logic [15:0] core_timeout_limit;
  logic        mem_wait_active;
  logic        mem_timeout_hit;
  logic        core_timeout_hit;
  logic        core_done_observed;
  logic [31:0] dma_i8_wdata;

  wire write_idle = (wr_state == WR_IDLE);
  wire read_idle  = (rd_state == RD_IDLE);
  wire write_can_accept = write_idle && read_idle && !s_axi_bvalid;
  wire read_can_accept  = read_idle && write_idle && !aw_seen && !w_seen && !s_axi_rvalid;

  assign s_axi_awready = write_can_accept && !aw_seen;
  assign s_axi_wready  = write_can_accept && !w_seen;
  assign s_axi_arready = read_can_accept;
  assign s_axi_bresp   = AXI_RESP_OKAY;
  assign s_axi_rresp   = AXI_RESP_OKAY;

  assign bus_access = (wr_state == WR_ACCESS) || (rd_state == RD_ACCESS);
  assign bus_write  = (wr_state == WR_ACCESS);
  assign bus_addr   = bus_write ? awaddr_q : araddr_q;
  assign bus_wdata  = wdata_q;
  assign core_sel   = (bus_addr[11:8] == 4'h0);
  assign desc_sel   = (bus_addr >= 12'h100) && (bus_addr <= 12'h120);
  assign external_core_access = core_sel && !dma_busy;
  assign bus_ready = (core_sel && !dma_busy) ? core_pready : 1'b1;

  always_comb begin
    if (core_sel) begin
      bus_rdata = dma_busy ? 32'h0 : core_prdata;
    end else begin
      case (bus_addr)
        DMA_CTRL:       bus_rdata = 32'h0;
        DMA_STATUS:     bus_rdata = {29'h0, dma_error, dma_done, dma_busy};
        DMA_A_EXT_BASE: bus_rdata = dma_a_ext_base;
        DMA_B_EXT_BASE: bus_rdata = dma_b_ext_base;
        DMA_C_EXT_BASE: bus_rdata = dma_c_ext_base;
        DMA_CONFIG:     bus_rdata = dma_config;
        DMA_ERROR_CODE: bus_rdata = dma_error_code;
        DMA_IRQ_ENABLE: bus_rdata = {30'h0, dma_irq_enable};
        DMA_IRQ_STATUS: bus_rdata = {30'h0, error_irq_pending, done_irq_pending};
        default:        bus_rdata = 32'h0;
      endcase
    end
  end

  assign irq = (dma_irq_enable[0] && done_irq_pending) ||
               (dma_irq_enable[1] && error_irq_pending);
  assign dma_i8_wdata = {{24{dma_data_q[7]}}, dma_data_q[7:0]};
  assign mem_timeout_limit = (dma_config[15:0] == 16'h0) ? MEM_TIMEOUT_DEFAULT : dma_config[15:0];
  assign core_timeout_limit = (dma_config[31:16] == 16'h0) ? CORE_TIMEOUT_DEFAULT : dma_config[31:16];
  assign mem_wait_active = ((dma_state == DMA_LOAD_A) || (dma_state == DMA_LOAD_B)) &&
                           ((dma_phase == PHASE_AXI_AR) || (dma_phase == PHASE_AXI_R)) ||
                           ((dma_state == DMA_STORE_C) && (dma_phase == PHASE_C_WRITE));
  assign mem_timeout_hit = mem_wait_active &&
                           (mem_timeout_count >= (mem_timeout_limit - 16'd1));
  assign core_timeout_hit = (dma_state == DMA_WAIT_CORE) &&
                            (core_timeout_count >= (core_timeout_limit - 16'd1));
  assign core_done_observed = core_prdata[1];

  always_comb begin
    internal_core_write = 1'b0;
    internal_core_addr  = CORE_ADDR_STATUS;
    internal_core_wdata = 32'h0;

    case (dma_state)
      DMA_LOAD_A: begin
        if (dma_phase == PHASE_CORE_WRITE) begin
          internal_core_write = 1'b1;
          internal_core_addr  = CORE_ADDR_A_BASE + {dma_idx, 2'b00};
          internal_core_wdata = dma_i8_wdata;
        end
      end
      DMA_LOAD_B: begin
        if (dma_phase == PHASE_CORE_WRITE) begin
          internal_core_write = 1'b1;
          internal_core_addr  = CORE_ADDR_B_BASE + {dma_idx, 2'b00};
          internal_core_wdata = dma_i8_wdata;
        end
      end
      DMA_START_CORE: begin
        internal_core_write = 1'b1;
        internal_core_addr  = CORE_ADDR_CTRL;
        internal_core_wdata = 32'h1;
      end
      DMA_WAIT_CORE: begin
        internal_core_write = 1'b0;
        internal_core_addr  = CORE_ADDR_STATUS;
      end
      DMA_STORE_C: begin
        if (dma_phase == PHASE_CORE_READ) begin
          internal_core_write = 1'b0;
          internal_core_addr  = CORE_ADDR_C_BASE + {dma_idx, 2'b00};
        end
      end
      default: begin
      end
    endcase
  end

  assign internal_core_access = (dma_state == DMA_START_CORE) ||
                                (dma_state == DMA_WAIT_CORE) ||
                                (dma_phase == PHASE_CORE_WRITE) ||
                                (dma_phase == PHASE_CORE_READ);
  assign core_psel    = internal_core_access ? 1'b1 : (bus_access && external_core_access);
  assign core_penable = internal_core_access ? 1'b1 : bus_access;
  assign core_pwrite  = internal_core_access ? internal_core_write : bus_write;
  assign core_paddr   = internal_core_access ? internal_core_addr : bus_addr[7:0];
  assign core_pwdata  = internal_core_access ? internal_core_wdata : bus_wdata;

  always_comb begin
    m_axi_araddr  = 32'h0;
    m_axi_arlen   = 8'h00;
    m_axi_arsize  = 3'b010;
    m_axi_arburst = AXI_BURST_INCR;
    m_axi_arvalid = 1'b0;
    m_axi_rready  = 1'b0;
    c_mem_valid   = 1'b0;
    c_mem_addr    = 32'h0;
    c_mem_wdata   = 32'h0;

    if (((dma_state == DMA_LOAD_A) || (dma_state == DMA_LOAD_B)) &&
        (dma_phase == PHASE_AXI_AR)) begin
      m_axi_arvalid = 1'b1;
      if (dma_state == DMA_LOAD_A) begin
        m_axi_araddr = (dma_a_ext_base + {28'h0, dma_idx}) << 2;
      end else begin
        m_axi_araddr = (dma_b_ext_base + {28'h0, dma_idx}) << 2;
      end
    end

    if (((dma_state == DMA_LOAD_A) || (dma_state == DMA_LOAD_B)) &&
        (dma_phase == PHASE_AXI_R)) begin
      m_axi_rready = 1'b1;
    end

    if ((dma_state == DMA_STORE_C) && (dma_phase == PHASE_C_WRITE)) begin
      c_mem_valid = 1'b1;
      c_mem_addr  = dma_c_ext_base + {28'h0, dma_idx};
      c_mem_wdata = dma_data_q;
    end
  end

  tinynpu_apb_wrapper u_core_apb (
    .pclk    (aclk),
    .presetn (aresetn),
    .psel    (core_psel),
    .penable (core_penable),
    .pwrite  (core_pwrite),
    .paddr   (core_paddr),
    .pwdata  (core_pwdata),
    .prdata  (core_prdata),
    .pready  (core_pready),
    .pslverr (core_pslverr)
  );

  always_ff @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
      wr_state <= WR_IDLE;
      rd_state <= RD_IDLE;
      aw_seen <= 1'b0;
      w_seen <= 1'b0;
      awaddr_q <= 12'h0;
      araddr_q <= 12'h0;
      wdata_q <= 32'h0;
      wstrb_q <= 4'h0;
      s_axi_bvalid <= 1'b0;
      s_axi_rvalid <= 1'b0;
      s_axi_rdata <= 32'h0;
      dma_busy <= 1'b0;
      dma_done <= 1'b0;
      dma_error <= 1'b0;
      dma_a_ext_base <= 32'h0;
      dma_b_ext_base <= 32'h0;
      dma_c_ext_base <= 32'h0;
      dma_config <= 32'h0;
      dma_error_code <= ERROR_NONE;
      dma_irq_enable <= 2'b00;
      done_irq_pending <= 1'b0;
      error_irq_pending <= 1'b0;
      dma_state <= DMA_IDLE;
      dma_phase <= PHASE_AXI_AR;
      dma_idx <= 4'h0;
      dma_data_q <= 32'h0;
      mem_timeout_count <= 16'h0;
      core_timeout_count <= 16'h0;
    end else begin
      if (s_axi_bvalid && s_axi_bready) s_axi_bvalid <= 1'b0;
      if (s_axi_rvalid && s_axi_rready) s_axi_rvalid <= 1'b0;

      if (s_axi_awready && s_axi_awvalid) begin
        aw_seen <= 1'b1;
        awaddr_q <= s_axi_awaddr;
      end
      if (s_axi_wready && s_axi_wvalid) begin
        w_seen <= 1'b1;
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
              aw_seen <= 1'b0;
              w_seen <= 1'b0;
              s_axi_bvalid <= 1'b1;
              wr_state <= WR_RESP;
            end
          end
        end
        WR_SETUP: wr_state <= WR_ACCESS;
        WR_ACCESS: begin
          if (bus_ready) begin
            if (desc_sel) begin
              case (bus_addr)
                DMA_CTRL: begin
                  if (bus_wdata[1]) begin
                    dma_done <= 1'b0;
                    done_irq_pending <= 1'b0;
                  end
                  if (bus_wdata[2]) begin
                    dma_error <= 1'b0;
                    dma_error_code <= ERROR_NONE;
                    error_irq_pending <= 1'b0;
                  end
                  if (bus_wdata[0] && !dma_busy && !dma_error && (dma_state == DMA_IDLE)) begin
                    dma_busy <= 1'b1;
                    dma_done <= 1'b0;
                    dma_state <= DMA_LOAD_A;
                    dma_phase <= PHASE_AXI_AR;
                    dma_idx <= 4'h0;
                    mem_timeout_count <= 16'h0;
                    core_timeout_count <= 16'h0;
                  end
                end
                DMA_A_EXT_BASE: dma_a_ext_base <= bus_wdata;
                DMA_B_EXT_BASE: dma_b_ext_base <= bus_wdata;
                DMA_C_EXT_BASE: dma_c_ext_base <= bus_wdata;
                DMA_CONFIG:     dma_config <= bus_wdata;
                DMA_IRQ_ENABLE: dma_irq_enable <= bus_wdata[1:0];
                default: begin
                end
              endcase
            end
            aw_seen <= 1'b0;
            w_seen <= 1'b0;
            s_axi_bvalid <= 1'b1;
            wr_state <= WR_RESP;
          end
        end
        WR_RESP: begin
          if (s_axi_bvalid && s_axi_bready) wr_state <= WR_IDLE;
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
        RD_SETUP: rd_state <= RD_ACCESS;
        RD_ACCESS: begin
          if (bus_ready) begin
            s_axi_rdata <= bus_rdata;
            s_axi_rvalid <= 1'b1;
            rd_state <= RD_RESP;
          end
        end
        RD_CAPTURE: rd_state <= RD_RESP;
        RD_RESP: begin
          if (s_axi_rvalid && s_axi_rready) rd_state <= RD_IDLE;
        end
        default: rd_state <= RD_IDLE;
      endcase

      if (mem_timeout_hit) begin
        dma_busy <= 1'b0;
        dma_done <= 1'b1;
        dma_error <= 1'b1;
        dma_error_code <= ERROR_MEM_TIMEOUT;
        error_irq_pending <= 1'b1;
        dma_state <= DMA_IDLE;
        dma_phase <= PHASE_AXI_AR;
        dma_idx <= 4'h0;
        mem_timeout_count <= 16'h0;
        core_timeout_count <= 16'h0;
      end else if (core_timeout_hit) begin
        dma_busy <= 1'b0;
        dma_done <= 1'b1;
        dma_error <= 1'b1;
        dma_error_code <= ERROR_CORE_TIMEOUT;
        error_irq_pending <= 1'b1;
        dma_state <= DMA_IDLE;
        dma_phase <= PHASE_AXI_AR;
        dma_idx <= 4'h0;
        mem_timeout_count <= 16'h0;
        core_timeout_count <= 16'h0;
      end else begin
        if (mem_wait_active) mem_timeout_count <= mem_timeout_count + 16'd1;
        else mem_timeout_count <= 16'h0;

        if (dma_state == DMA_WAIT_CORE) core_timeout_count <= core_timeout_count + 16'd1;
        else core_timeout_count <= 16'h0;

        case (dma_state)
          DMA_IDLE: begin
            if (!dma_error) begin
              dma_busy <= 1'b0;
            end
          end
          DMA_LOAD_A, DMA_LOAD_B: begin
            if (dma_phase == PHASE_AXI_AR) begin
              if (m_axi_arready) dma_phase <= PHASE_AXI_R;
            end else if (dma_phase == PHASE_AXI_R) begin
              if (m_axi_rvalid) begin
                if ((m_axi_rresp != AXI_RESP_OKAY) || !m_axi_rlast) begin
                  dma_busy <= 1'b0;
                  dma_done <= 1'b1;
                  dma_error <= 1'b1;
                  dma_error_code <= ERROR_AXI_RRESP;
                  error_irq_pending <= 1'b1;
                  dma_state <= DMA_IDLE;
                  dma_phase <= PHASE_AXI_AR;
                  dma_idx <= 4'h0;
                end else begin
                  dma_data_q <= m_axi_rdata;
                  dma_phase <= PHASE_CORE_WRITE;
                end
              end
            end else if (dma_phase == PHASE_CORE_WRITE) begin
              if (core_pready) begin
                if (dma_idx == 4'd15) begin
                  dma_idx <= 4'h0;
                  dma_phase <= (dma_state == DMA_LOAD_A) ? PHASE_AXI_AR : PHASE_CORE_READ;
                  dma_state <= (dma_state == DMA_LOAD_A) ? DMA_LOAD_B : DMA_START_CORE;
                end else begin
                  dma_idx <= dma_idx + 4'h1;
                  dma_phase <= PHASE_AXI_AR;
                end
              end
            end
          end
          DMA_START_CORE: begin
            if (core_pready) begin
              dma_phase <= PHASE_CORE_GAP;
              dma_state <= DMA_WAIT_CORE;
            end
          end
          DMA_WAIT_CORE: begin
            if (dma_phase == PHASE_CORE_GAP) begin
              dma_phase <= PHASE_CORE_READ;
            end else if (dma_phase == PHASE_CORE_READ) begin
              if (core_pready) dma_phase <= PHASE_CORE_CAPTURE;
            end else if (dma_phase == PHASE_CORE_CAPTURE) begin
              if (core_done_observed) begin
                dma_idx <= 4'h0;
                dma_phase <= PHASE_CORE_GAP;
                dma_state <= DMA_STORE_C;
              end else begin
                dma_phase <= PHASE_CORE_GAP;
              end
            end
          end
          DMA_STORE_C: begin
            if (dma_phase == PHASE_CORE_GAP) begin
              dma_phase <= PHASE_CORE_READ;
            end else if (dma_phase == PHASE_CORE_READ) begin
              if (core_pready) dma_phase <= PHASE_CORE_CAPTURE;
            end else if (dma_phase == PHASE_CORE_CAPTURE) begin
              dma_data_q <= core_prdata;
              dma_phase <= PHASE_C_WRITE;
            end else if (dma_phase == PHASE_C_WRITE) begin
              if (c_mem_ready) begin
                if (dma_idx == 4'd15) begin
                  dma_idx <= 4'h0;
                  dma_phase <= PHASE_AXI_AR;
                  dma_state <= DMA_DONE;
                end else begin
                  dma_idx <= dma_idx + 4'h1;
                  dma_phase <= PHASE_CORE_GAP;
                end
              end
            end
          end
          DMA_DONE: begin
            dma_busy <= 1'b0;
            dma_done <= 1'b1;
            done_irq_pending <= 1'b1;
            dma_state <= DMA_IDLE;
            dma_phase <= PHASE_AXI_AR;
            dma_idx <= 4'h0;
          end
          default: begin
            dma_busy <= 1'b0;
            dma_done <= 1'b1;
            dma_error <= 1'b1;
            dma_error_code <= ERROR_CORE_TIMEOUT;
            error_irq_pending <= 1'b1;
            dma_state <= DMA_IDLE;
          end
        endcase
      end
    end
  end

endmodule
