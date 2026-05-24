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
  output logic        pslverr,

  output logic        mem_valid,
  output logic        mem_we,
  output logic [31:0] mem_addr,
  output logic [31:0] mem_wdata,
  input  logic [31:0] mem_rdata,
  input  logic        mem_ready
);

  localparam logic [11:0] DMA_CTRL       = 12'h100;
  localparam logic [11:0] DMA_STATUS     = 12'h104;
  localparam logic [11:0] DMA_A_EXT_BASE = 12'h108;
  localparam logic [11:0] DMA_B_EXT_BASE = 12'h10c;
  localparam logic [11:0] DMA_C_EXT_BASE = 12'h110;
  localparam logic [11:0] DMA_CONFIG     = 12'h114;

  localparam logic [7:0] CORE_ADDR_CTRL   = 8'h00;
  localparam logic [7:0] CORE_ADDR_STATUS = 8'h04;
  localparam logic [7:0] CORE_ADDR_A_BASE = 8'h10;
  localparam logic [7:0] CORE_ADDR_B_BASE = 8'h50;
  localparam logic [7:0] CORE_ADDR_C_BASE = 8'h90;

  localparam logic [2:0] DMA_IDLE       = 3'd0;
  localparam logic [2:0] DMA_LOAD_A     = 3'd1;
  localparam logic [2:0] DMA_LOAD_B     = 3'd2;
  localparam logic [2:0] DMA_START_CORE = 3'd3;
  localparam logic [2:0] DMA_WAIT_CORE  = 3'd4;
  localparam logic [2:0] DMA_STORE_C    = 3'd5;
  localparam logic [2:0] DMA_DONE       = 3'd6;

  localparam logic [2:0] PHASE_MEM_READ       = 3'd0;
  localparam logic [2:0] PHASE_CORE_WRITE     = 3'd1;
  localparam logic [2:0] PHASE_CORE_READ      = 3'd2;
  localparam logic [2:0] PHASE_CORE_CAPTURE   = 3'd3;
  localparam logic [2:0] PHASE_MEM_WRITE      = 3'd4;
  localparam logic [2:0] PHASE_CORE_GAP       = 3'd5;

  logic        core_sel;
  logic        desc_sel;
  logic        apb_access;
  logic        external_core_access;
  logic        internal_core_access;

  logic [31:0] core_prdata;
  logic        core_pready;
  logic        core_pslverr;
  logic [31:0] desc_prdata;
  logic        core_psel;
  logic        core_penable;
  logic        core_pwrite;
  logic [7:0]  core_paddr;
  logic [31:0] core_pwdata;

  logic        dma_busy;
  logic        dma_done;
  logic        dma_error;
  logic [31:0] dma_a_ext_base;
  logic [31:0] dma_b_ext_base;
  logic [31:0] dma_c_ext_base;
  logic [31:0] dma_config;
  logic [2:0]  dma_state;
  logic [2:0]  dma_phase;
  logic [3:0]  dma_idx;
  logic [31:0] dma_data_q;
  logic        internal_core_write;
  logic [7:0]  internal_core_addr;
  logic [31:0] internal_core_wdata;
  logic [31:0] dma_i8_wdata;

  assign core_sel   = (paddr[11:8] == 4'h0);
  assign desc_sel   = (paddr >= 12'h100) && (paddr <= 12'h11f);
  assign apb_access = psel && penable;
  assign external_core_access = core_sel && !dma_busy;
  assign internal_core_access = (dma_state == DMA_START_CORE) ||
                                (dma_state == DMA_WAIT_CORE) ||
                                (dma_phase == PHASE_CORE_WRITE) ||
                                (dma_phase == PHASE_CORE_READ);

  assign pready  = (core_sel && !dma_busy) ? core_pready : 1'b1;
  assign pslverr = 1'b0;
  assign prdata  = core_sel ? (dma_busy ? 32'h0 : core_prdata) : desc_prdata;

  assign core_psel    = internal_core_access ? 1'b1 : (psel && external_core_access);
  assign core_penable = internal_core_access ? 1'b1 : penable;
  assign core_pwrite  = internal_core_access ? internal_core_write : pwrite;
  assign core_paddr   = internal_core_access ?
                        internal_core_addr :
                        paddr[7:0];
  assign core_pwdata  = internal_core_access ?
                        internal_core_wdata :
                        pwdata;
  assign dma_i8_wdata = {{24{dma_data_q[7]}}, dma_data_q[7:0]};

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
        internal_core_wdata = 32'h0;
      end

      DMA_STORE_C: begin
        if (dma_phase == PHASE_CORE_READ) begin
          internal_core_write = 1'b0;
          internal_core_addr  = CORE_ADDR_C_BASE + {dma_idx, 2'b00};
          internal_core_wdata = 32'h0;
        end
      end

      default: begin
      end
    endcase
  end

  always_comb begin
    mem_valid = 1'b0;
    mem_we    = 1'b0;
    mem_addr  = 32'h0;
    mem_wdata = 32'h0;

    if ((dma_state == DMA_LOAD_A) && (dma_phase == PHASE_MEM_READ)) begin
      mem_valid = 1'b1;
      mem_we    = 1'b0;
      mem_addr  = dma_a_ext_base + {28'h0, dma_idx};
    end else if ((dma_state == DMA_LOAD_B) && (dma_phase == PHASE_MEM_READ)) begin
      mem_valid = 1'b1;
      mem_we    = 1'b0;
      mem_addr  = dma_b_ext_base + {28'h0, dma_idx};
    end else if ((dma_state == DMA_STORE_C) && (dma_phase == PHASE_MEM_WRITE)) begin
      mem_valid = 1'b1;
      mem_we    = 1'b1;
      mem_addr  = dma_c_ext_base + {28'h0, dma_idx};
      mem_wdata = dma_data_q;
    end
  end

  tinynpu_apb_wrapper u_core_apb (
    .pclk    (pclk),
    .presetn (presetn),
    .psel    (core_psel),
    .penable (core_penable),
    .pwrite  (core_pwrite),
    .paddr   (core_paddr),
    .pwdata  (core_pwdata),
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
      dma_state      <= DMA_IDLE;
      dma_phase      <= PHASE_MEM_READ;
      dma_idx        <= 4'h0;
      dma_data_q     <= 32'h0;
    end else begin
      if (apb_access && desc_sel && pwrite) begin
        case (paddr)
          DMA_CTRL: begin
            if (pwdata[1]) begin
              dma_done <= 1'b0;
            end
            if (pwdata[2]) begin
              dma_error <= 1'b0;
            end
            if (pwdata[0] && !dma_busy && (dma_state == DMA_IDLE)) begin
              dma_busy    <= 1'b1;
              dma_done    <= 1'b0;
              dma_error   <= 1'b0;
              dma_state   <= DMA_LOAD_A;
              dma_phase   <= PHASE_MEM_READ;
              dma_idx     <= 4'h0;
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

      case (dma_state)
        DMA_IDLE: begin
        end

        DMA_LOAD_A: begin
          if (dma_phase == PHASE_MEM_READ) begin
            if (mem_ready) begin
              dma_data_q <= mem_rdata;
              dma_phase  <= PHASE_CORE_WRITE;
            end
          end else if (dma_phase == PHASE_CORE_WRITE) begin
            if (core_pready) begin
              if (dma_idx == 4'd15) begin
                dma_idx   <= 4'h0;
                dma_phase <= PHASE_MEM_READ;
                dma_state <= DMA_LOAD_B;
              end else begin
                dma_idx   <= dma_idx + 4'h1;
                dma_phase <= PHASE_MEM_READ;
              end
            end
          end
        end

        DMA_LOAD_B: begin
          if (dma_phase == PHASE_MEM_READ) begin
            if (mem_ready) begin
              dma_data_q <= mem_rdata;
              dma_phase  <= PHASE_CORE_WRITE;
            end
          end else if (dma_phase == PHASE_CORE_WRITE) begin
            if (core_pready) begin
              if (dma_idx == 4'd15) begin
                dma_idx   <= 4'h0;
                dma_phase <= PHASE_CORE_READ;
                dma_state <= DMA_START_CORE;
              end else begin
                dma_idx   <= dma_idx + 4'h1;
                dma_phase <= PHASE_MEM_READ;
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
            if (core_pready) begin
              dma_phase <= PHASE_CORE_CAPTURE;
            end
          end else if (dma_phase == PHASE_CORE_CAPTURE) begin
            if (core_prdata[1]) begin
              dma_idx   <= 4'h0;
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
            if (core_pready) begin
              dma_phase <= PHASE_CORE_CAPTURE;
            end
          end else if (dma_phase == PHASE_CORE_CAPTURE) begin
            dma_data_q <= core_prdata;
            dma_phase  <= PHASE_MEM_WRITE;
          end else if (dma_phase == PHASE_MEM_WRITE) begin
            if (mem_ready) begin
              if (dma_idx == 4'd15) begin
                dma_idx   <= 4'h0;
                dma_phase <= PHASE_MEM_READ;
                dma_state <= DMA_DONE;
              end else begin
                dma_idx   <= dma_idx + 4'h1;
                dma_phase <= PHASE_CORE_GAP;
              end
            end
          end
        end

        DMA_DONE: begin
          dma_busy  <= 1'b0;
          dma_done  <= 1'b1;
          dma_idx   <= 4'h0;
          dma_phase <= PHASE_MEM_READ;
          dma_state <= DMA_IDLE;
        end

        default: begin
          dma_busy    <= 1'b0;
          dma_error   <= 1'b1;
          dma_state   <= DMA_IDLE;
          dma_phase   <= PHASE_MEM_READ;
          dma_idx     <= 4'h0;
        end
      endcase

      if (apb_access && !pwrite) begin
        if (core_sel && !dma_busy && core_pready) begin
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
