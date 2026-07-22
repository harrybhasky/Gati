`include "common/portid.vh"
`include "common/instructions.vh"
`include "common/arch_functions.vh"
`include "common/arch_param.vh"

module rah_gati #(
    parameter   SYS_CLK_PERIOD      = 32'd85_000_000 ,  //System Clock Period
    parameter   NO_PORT_WR          = 2,
    parameter   ADDRESS_WIDTH       = 32, // address width                 
    parameter   IN_ADDR             = 8, // input address width of port controller
    parameter   ID_WIDTH            = 8,// ID width after the arbiter module
    parameter   AXI_ID_BLEN_CON     = 8,  // burst length width for AXI
    parameter   AXI_BYTE_NUMBER     = AXI_DATA_WIDTH/8,
    parameter   ADW_C               = AXI_DATA_WIDTH ,
    parameter   ABN_C               = AXI_BYTE_NUMBER ,
    //Default burst lenghts for various memory request controllers
    parameter MIPI_REQ_BLEN         = 15,
    parameter CONFIG_REQ_BLEN       = 7,
    parameter WEIGHT_REQ_BLEN       = 47,
    parameter FC_WEIGHT_REQ_BLEN    = 63,
    parameter ACC_REQ_BLEN          = 15,
    parameter BIAS_REQ_BLEN         = 15,
    parameter OP_WRITE_REQ_ACC_BLEN = 15, //burst length for writng accumulants (32-bit) into the DRAM
    parameter OP_WRITE_REQ_QUA_BLEN = 15, //burst length for writng quantized output (8-bit) into the DRAM
    parameter CPU_DISPATCH_REQ_BLEN = 15,

    //parameters related to DRAM controller
    parameter FIXED_PORTS = 8, //config, img, weights, bias, acc, op_write, mipi_read/write
    parameter ELTWISE = `ifdef ELTWISE 2 `else 0 `endif, // ELTWISE
    parameter FC_PORT = `ifdef FC 1 `else 0 `endif, //FC
    parameter BIAS_FC_PORT = `ifdef BIAS_FC 1 `else 0 `endif, //BIAS_FC
    parameter TRANSPOSE_PORT = `ifdef TRANSPOSE 1 `else 0 `endif, //TRANSPOSE
    parameter CONCAT_PORT = `ifdef CONCAT 1 `else 0 `endif, 
    parameter NUM_PORTS = FIXED_PORTS + ELTWISE + FC_PORT + BIAS_FC_PORT + TRANSPOSE_PORT+ CONCAT_PORT, //Number of read and write requestors

    //parameters related to AXI
    parameter AXI_DATA_WIDTH = 256,
    parameter AXI_DATA_BYTES = 32,  // Axi Data width = 256 bit
    parameter AXI_ADDR_W = `CONV_ImageStartAddress_WIDTH,   // Axi Address width
    parameter BURST_LENGTH_WIDTH =8,

    //MIPI related params
    parameter MIPI_DATA_WIDTH = 32,
    parameter MIPI_FIFO_DEPTH = 512,
    //Config blk param
    parameter NUM_INSTRUCTIONS = 11,
    parameter INST_W = 256,
    parameter CONFIG_FIFO_OCCUPANCY = 10,
    //Output block inst param
    parameter W_CITER_CNT       = `OutputBlock_ChannelItr_WIDTH,
    parameter W_KITER_CNT       = `OutputBlock_KernelItr_WIDTH,
    parameter I_ACC_SIZE_WIDTH  = `OutputBlock_ImageDimAcc_WIDTH, // bit width of input image dimension
    parameter I_OP_SIZE_WIDTH   = `OutputBlock_ImageDimOutput_WIDTH,
    parameter ACCEN_WIDTH       = `OutputBlock_AccEn_WIDTH,
    parameter DISPATCH_ID_WIDTH = `OutputBlock_DispatchID_WIDTH,
    parameter DISPATCHEN_WIDTH  = `OutputBlock_DispatchEn_WIDTH,
    parameter ACC_ONCHIP_WIDTH  = `OutputBlock_OnChipAcc_WIDTH,
    //Element wise operations param
    parameter EltWise_TYPE_WIDTH = 4,
    //Other parameters

    parameter MIPI_FIFO     = 8, // Number of MIPI DWP FIFOs
    parameter QUANT_OP_FIFO = 1, // Number of quantized output FIFOs
    parameter OP_FIFO       = 1,  // Number of output write FIFOs
    parameter BIAS_FIFO_FC  = 32, // Number of FC bias FIFOs
    parameter CPU_DISPATCH_FIFO = 1, //Number of Data FIFOs in CPU_DISPATCH module
    parameter ACC_OP_FIFO_DEPTH   = 256,
    parameter QUANT_OP_FIFO_DEPTH = 256,
    parameter OP_WRITE_FIFO_DEPTH = 512,
    parameter DRAM_IMG_FIFO_DEPTH = 512,
    parameter WEIGHT_FIFO_DEPTH   = 512,
    
    parameter CPU_DISPATCH_REQ_FIFO_DEPTH = 8,
    parameter DISPATCH_FIFO_DEPTH = 256, //FIFO Depth of data FIFO in CPU dispatch module 
    parameter DATA_WIDTH    = 8,
    parameter COL_FC        = 32,
    parameter W_PSUM        = 20,
    parameter DATA_WIDTH_OB = 32
) (
    input i_clk,
    input valid_32,
    input c_81_clk,
    input s_clk,
    input m_clk,
    input i_rst,
    input empty,
    input [31:0] data,
    output  reg rden=0,
    output  layer_debug_pin,

    //DRAM read and mipi write related signals
    input mipi_fifo_rd_en,
    output mipi_fifo_empty,
    output mipi_fifo_almost_empty,
    output [MIPI_DATA_WIDTH-1:0] mipi_fifo_data_out,
    output mipi_fifo_data_valid,
    output [2*I_OP_SIZE_WIDTH-1:0] data_size_rah, // These two signals are for rah module
    output valid_data_size_rah,
    output [$clog2(MIPI_FIFO_DEPTH):0] mipi_rd_fifo_occupants,

	//input start_gpio,	

    input [1:0] PllLocked,
    output      DdrCtrl_CFG_RST_N , //(O)[Control]DDR Cntrl Reset(Low Active)     
    output      DdrCtrl_CFG_SEQ_RST, //(O)[Control]DDR Cntrl Sequencer Reset 
    output      DdrCtrl_CFG_SEQ_START ,   

    output d_done,
    output  [      7:0] aid     ,
    output  [     31:0] aaddr   , 

    output  [      7:0] alen    , 
    output  [      2:0] asize   , 
    output  [      1:0] aburst  , 
    output  [      1:0] alock   , 
    output              avalid  , 
    input               aready  , 
    output              atype   ,
    output  [      7:0] wid     , 
    output  [ABN_C-1:0] wstrb   , 
    output              wlast   , 
    output              wvalid  , 
    input               wready  , 
    output  [ADW_C-1:0] wdata   , 
    input   [      7:0] rid     , 
    input               rlast   , 
    input               rvalid  , 
    output              rready  , 
    input   [      1:0] rresp   , 
    input   [ADW_C-1:0] rdata   , 
    input   [      7:0] bid     , 
    input               bvalid  , 
    output              bready  ,
     
    //io signals to board gpio
    output [6:0] kernal_count,  // current kernal iteration number 
    output [6:0] channel_count, // current channel iteration number
    output       soft_start,    //user_start from top_gati_module
    output [3:0] layer_count,
    output       layer_done,
    output       eop,

    output [31:0] layer_cycles_count,
    output [59:0] stall_cycles_count,
    output reg [7:0] consolidated_error_flag
);


/* --------------------- ARCH Related Parameter ----------------------------*/ 

// these parameter are fetched based on the current architecture from arch_param
// arch realated parametere 

  localparam integer N_SA           = `N_SA;
  localparam integer COL_SA         = `COL_SA;
  localparam integer ROW            = `ROW;
  localparam IM2COL_BOUND_GEN_WIDTH = `IM2COL_BOUND_GEN_WIDTH; // Data width for bound generation registers of Im2Col Engine
  localparam N_MOD_STAGES           = `N_MOD_STAGES; // Number of stages in mod operator in Im2Col stride handling block

  // Derived parameters via functions 
  // TODO : these parameters needs to be formulated based on the architecture and the functions defined in arch_functions.vh for the param be removed

  localparam IMG_REQ_BLEN        = get_img_req_blen(N_SA, COL_SA, ROW);
  localparam POINTER_COUNT       = get_pointer_count(N_SA, COL_SA, ROW);
  localparam INST_QUEUE_DEPTH    = get_inst_queue_depth(N_SA, COL_SA, ROW);
  localparam IM2COL_FIFO_DEPTH   = get_im2col_fifo_depth(N_SA, COL_SA, ROW);
  localparam PSUM_FIFO_DEPTH     = get_psum_fifo_depth(N_SA, COL_SA, ROW);
  localparam ACC_FIFO_DEPTH      = get_acc_fifo_depth(N_SA, COL_SA, ROW);
  localparam BIAS_FIFO_DEPTH     = get_bias_fifo_depth(N_SA, COL_SA, ROW);
  localparam ELTWISE_FIFO_DEPTH  = get_eltwise_fifo_depth(N_SA, COL_SA, ROW);
  localparam NSA_LUT             = get_nsa_lut(N_SA, COL_SA, ROW);
  localparam NSA_DSP             = get_nsa_dsp(N_SA, COL_SA, ROW);
  localparam FC_BRAM_DEPTH       = get_fc_bram_depth(N_SA, COL_SA, ROW);
  localparam MOD1                = get_mod1(N_SA, COL_SA, ROW);
  localparam N_DMUX_PORTS        = get_n_dmux_ports(N_SA, COL_SA, ROW);
  localparam BIAS_FIFO           = get_bias_fifo(N_SA, COL_SA, ROW);
  localparam ACC_FIFO            = get_acc_fifo(N_SA, COL_SA, ROW);
  localparam ACC_OP_FIFO         = get_acc_op_fifo(N_SA, COL_SA, ROW);
  localparam NO_PORT_VA          = get_no_port_va(N_SA, COL_SA, ROW);
  localparam NO_PORT_BAC         = get_no_port_bac(N_SA, COL_SA, ROW);
  localparam ACC_TOGGLE          = get_acc_toggle(N_SA, COL_SA, ROW);
  localparam AXI_STALL_THRESHOLD = 10'd1023;

  
  // formuled parameters 
  localparam SHFT_REG_X    = AXI_DATA_BYTES/N_SA; // Number of shift register
  localparam MOD2          = AXI_DATA_BYTES/N_SA;
  localparam RAM_DEPTH     = (1 << POINTER_COUNT);  // fifo depth
  localparam POP_THRESHOLD = AXI_DATA_BYTES/N_SA - 2 ;

  // FC Engine related parameters
  localparam ACC_DW            = 32;
  localparam N_BANK            = N_SA;
  localparam N_BRAM            = AXI_DATA_BYTES/N_SA;
  localparam ACC_DATA_REORDER  = ((COL_FC/(ACC_DW/8)) > COL_SA)? 1:0;
  localparam N_FC_MUX          = N_SA; //number of muxes for FC output
  localparam NO_PORT_FC        = COL_FC/N_SA; //FC mux size
  localparam NO_PORT_BAFC      = AXI_DATA_BYTES/N_SA ;

  /*-----------------------------------------------------------------*/



  /*------------------- generate port_ ID ----------------------------*/

  // this logic will generate port ID based on the number of ports using NUM_PORTS parameter and the PORT_ID_WIDTH

  localparam PORT_ID_WIDTH                  = ($clog2(NUM_PORTS));   
  localparam TOTAL_PORT_WIDTH               = PORT_ID_WIDTH * NUM_PORTS;
  localparam [TOTAL_PORT_WIDTH-1:0] PORT_ID = generate_port_id(NUM_PORTS, PORT_ID_WIDTH);

  /* --------------- function to generate port ID ------------- */

    function [(TOTAL_PORT_WIDTH)-1:0] generate_port_id;
    input integer num_port;
    input integer id_width;
    integer i;
    reg [(TOTAL_PORT_WIDTH)-1:0] result;
    reg [31:0] mask;
    begin
      result = 0;
      mask = (1 << id_width) - 1;  // Create mask based on id_width
      for (i = 0; i < num_port; i = i + 1) begin
        result = (result << id_width) | (i & mask);
      end
      generate_port_id = result;
    end
    endfunction

  /*----------------------------------------------------------*/

  /*------------------------------------------------------------------------*/

// TODO : kya chahiye bhai per q 
  wire  [31:0] o_data ;
  assign o_data=data; 
  wire valid_data;
  assign valid_data=valid_32;
 

  always @(posedge c_81_clk) begin
    if (!empty) begin
      rden <= 1;
    end else begin
      rden <= 0;
    end
  end 

  reg sel_mipi_write;
  wire wr_id_o_wready ;                              
  wire start;
  wire [(MIPI_DATA_WIDTH * MIPI_FIFO)-1 : 0] o_fifo_data;  //comes from fifo array
  wire final_o_data_last;  //comes from dram wr ctrl
  wire o_data_valid;  //comes from dram wr ctrl
  wire req_wr_req_ctrl;
  wire [7:0] address_wr_req_ctrl;
  wire [BURST_LENGTH_WIDTH-1 : 0] final_burst_len_wr_req_ctrl;
  wire final_last_wr_req_ctrl;
  wire valid_wr_req_ctrl;
  wire user_start;
    
  assign soft_start = user_start;
	////////////////////////////MIPI controller rx
    mipi_ctrl_top #(
      .N_FIFO(MIPI_FIFO),
      .W_DATA(MIPI_DATA_WIDTH),
      .BURST_LEN(MIPI_REQ_BLEN),
      .W_BURST_LEN(BURST_LENGTH_WIDTH),
      .W_ADDR($clog2(MIPI_FIFO_DEPTH)),
      .AXI_BYTES(AXI_DATA_BYTES)
    ) mipi_ctrler_reciver (
      .i_clk(c_81_clk),
	    .dr_clk(i_clk),
      .i_rstn(i_rst),
      // .i_rstn(1'b1),
      .i_data_valid(valid_data),
      .i_data(o_data),
      .ddr_sel(sel_mipi_write),
      .ddr_wready(wr_id_o_wready),
      .ddr_blen(wr_burst_len),
      .o_fifo_data(o_fifo_data),
      .final_o_data_last(final_o_data_last),
      .o_data_valid(o_data_valid),
      .req_wr_req_ctrl(req_wr_req_ctrl),
      .address_wr_req_ctrl(address_wr_req_ctrl),
      .final_burst_len_wr_req_ctrl(final_burst_len_wr_req_ctrl),
      .final_last_wr_req_ctrl(final_last_wr_req_ctrl),
      .valid_wr_req_ctrl(valid_wr_req_ctrl),
      .soft_start(user_start),
      .eop(eop)
    );
    
  wire [NUM_PORTS-1:0] select_wr;
  wire [NUM_PORTS-1:0] select_rd;
  wire [(AXI_DATA_WIDTH*NO_PORT_WR)-1:0] in_wr_data_mux;
  
  wire [AXI_DATA_WIDTH-1:0] dram_in_wrdata;

  //////////////////////////////// gati module instatiation

  //signals to DRAM ctrler
  ////config
  wire [7:0] mc_config_addr;
  wire mc_config_rdreq;
  wire mc_config_valid;
  wire [BURST_LENGTH_WIDTH-1 : 0] mc_config_bl;
  wire mc_config_last;

  ////img
  wire [7:0] mc_img_addr;
  wire mc_img_rdreq;
  wire mc_img_valid;
  wire [BURST_LENGTH_WIDTH-1 : 0] mc_img_bl;
  wire mc_img_last;

  /////conv
  wire [7:0] mc_wghts_addr;
  wire mc_wghts_rdreq;
  wire mc_wghts_valid;
  wire [BURST_LENGTH_WIDTH-1 : 0] mc_wghts_bl;
  wire mc_wghts_last;

  `ifdef FC
  ///////fc
  wire [7:0] mc_fc_addr;
  wire mc_fc_rdreq;
  wire mc_fc_valid;
  wire [BURST_LENGTH_WIDTH-1 : 0] mc_fc_bl;
  wire mc_fc_last;
  `endif //FC

  //////////bias 
  wire [7:0] mc_bias_addr;
  wire mc_bias_rdreq;
  wire mc_bias_valid;
  wire [BURST_LENGTH_WIDTH-1 : 0] mc_bias_bl;
  wire mc_bias_last;

  `ifdef BIAS_FC
  ///////////////fc_bias 
  wire [7:0] mc_fc_bias_addr;
  wire mc_fc_bias_rdreq;
  wire mc_fc_bias_valid;
  wire [BURST_LENGTH_WIDTH-1 : 0] mc_fc_bias_bl;
  wire mc_fc_bias_last;
  `endif //BIAS_FC

  /////////////acc
  wire [7:0] mc_acc_addr;
  wire mc_acc_rdreq;
  wire mc_acc_valid;
  wire [BURST_LENGTH_WIDTH-1:0] mc_acc_bl;
  wire mc_acc_last;

  `ifdef ELTWISE 
  /////////////LeftOperand
  wire [7:0] mc_LeftOperand_addr;
  wire mc_LeftOperand_rdreq;
  wire mc_LeftOperand_valid;
  wire [BURST_LENGTH_WIDTH-1:0] mc_LeftOperand_bl;
  wire mc_LeftOperand_last;

  /////////////RightOperand
  wire [7:0] mc_RightOperand_addr;
  wire mc_RightOperand_rdreq;
  wire mc_RightOperand_valid;
  wire [BURST_LENGTH_WIDTH-1:0] mc_RightOperand_bl;
  wire mc_RightOperand_last;
  `endif //ELTWISE

  `ifdef TRANSPOSE
  ///////////////ReshapeTranspose
  wire [7:0] mc_ReshapeTranspose_addr;
  wire mc_ReshapeTranspose_rdreq;
  wire mc_ReshapeTranspose_valid;   
  wire [BURST_LENGTH_WIDTH-1 : 0] mc_ReshapeTranspose_bl;
  wire mc_ReshapeTranspose_last;
  `endif //TRANSPOSE

  `ifdef CONCAT
  // Concat Operator
  wire [7:0] mc_Concat_addr;
  wire mc_Concat_rdreq;
  wire mc_Concat_valid;
  wire [BURST_LENGTH_WIDTH-1 : 0] mc_Concat_bl;
  wire mc_Concat_last;
  `endif 

  /////////////wire write ctrl
  wire [7:0] mc_op_write_addr;
  wire mc_op_writereq;
  wire mc_op_write_valid;
  wire [BURST_LENGTH_WIDTH-1 : 0] mc_op_write_bl;
  wire mc_op_write_last;

  /////////// dispatch req ctrl
  wire [7:0] mc_dispatch_addr;
  wire mc_dispatch_readreq;
  wire mc_dispatch_valid;
  wire [BURST_LENGTH_WIDTH-1 : 0] mc_dispatch_bl;
  wire mc_dispatch_last;

  ///////////////////////operators data

  //Signals from DRAM ctrl to internal operator blocks
 
  //Read block signals
  // wire sel_rd
  wire dram_rd_datavalid;
  wire dram_rd_data_last;
  wire [AXI_DATA_WIDTH - 1 : 0] dram_rd_data;

  //op_write block signals
  reg sel_op_write; // Todo: have to check ; wheteher sel is common or not
  wire [BURST_LENGTH_WIDTH-1 : 0] wr_burst_len;
  wire dv_op_write;
  wire data_last_op_write;
  wire [(AXI_DATA_WIDTH)-1:0] op_dram_fifo;

  assign in_wr_data_mux = {op_dram_fifo, o_fifo_data};

  //Generation of select signals locally for write to DRAM
  
  always@(posedge i_clk) begin
    if(!i_rst) sel_mipi_write <= 0;
    else begin
      if(final_o_data_last) sel_mipi_write <= 0;
      else if(select_wr[`MIPI_Wr]) sel_mipi_write <= 1;
    end
  end

  always@(posedge i_clk) begin
    if(!i_rst) sel_op_write <= 0;
    else begin
      if(data_last_op_write) sel_op_write <= 0;
      else if(select_wr[`OPWrite]) sel_op_write <= 1;
    end
  end

    vector_mux_param #(
      .PORT_SIZE(AXI_DATA_WIDTH),
      .NO_PORT  (NO_PORT_WR)
    ) dram_write_data (
      .sel({sel_op_write,sel_mipi_write}),
      .in (in_wr_data_mux),
      .out(dram_in_wrdata)
    );

  wire [(1*NO_PORT_WR)-1:0] in_wr_valid_mux;
  assign in_wr_valid_mux = {dv_op_write, o_data_valid};
  wire dram_in_wrvalid;

    vector_mux_param #(
      .PORT_SIZE(1),
      .NO_PORT  (NO_PORT_WR)
    ) dram_write_valid (
	    .sel({sel_op_write,sel_mipi_write}),
      .in (in_wr_valid_mux),
      .out(dram_in_wrvalid)
    );



  wire [(1*NO_PORT_WR)-1:0] in_wr_last_mux;
  assign in_wr_last_mux = {data_last_op_write, final_o_data_last};
  wire dram_in_wrlast;

    vector_mux_param #(
      .PORT_SIZE(1),
      .NO_PORT  (NO_PORT_WR)
    ) dram_write_last (
      .sel({sel_op_write,sel_mipi_write}),
	    .in (in_wr_last_mux),
      .out(dram_in_wrlast)
    );
  
  wire i_valid_req_clk81;
  wire [IN_ADDR-1:0] in_address_clk81;
  wire [AXI_ID_BLEN_CON-1 : 0] in_BLEN_clk81;
  wire i_rw_enable_clk81;
  wire i_last_clk81;

  assign i_valid_req_clk81  = valid_wr_req_ctrl;
  assign in_address_clk81   = address_wr_req_ctrl;
  assign in_BLEN_clk81      = final_burst_len_wr_req_ctrl;
  assign i_rw_enable_clk81  = req_wr_req_ctrl;
  assign i_last_clk81       = final_last_wr_req_ctrl;

  wire [NUM_PORTS-2:0] i_valid;
  wire [((NUM_PORTS-1)*8)-1:0] in_address;
  wire [((NUM_PORTS-1)*8)-1:0] in_BLEN;
  wire [NUM_PORTS-2:0] i_enable;
  wire [NUM_PORTS-2:0] i_last;

  reg user_start_d;
  reg [9:0] axi_addr_stall_cnt;
  reg [9:0] axi_write_stall_cnt;

  always @(posedge i_clk) begin
    user_start_d <= user_start;
  end

  // Sticky error bits; cleared on reset and at the start of a new inference.
  always @(posedge i_clk) begin
    if(!i_rst || (user_start && !user_start_d)) begin
      consolidated_error_flag <= 8'b0;
      axi_addr_stall_cnt <= 10'd0;
      axi_write_stall_cnt <= 10'd0;
    end
    else begin
      // bit0: MIPI FIFO underflow attempt (read when empty)
      if(mipi_fifo_rd_en && mipi_fifo_empty) consolidated_error_flag[0] <= 1'b1;
      // bit1: AXI read response error
      if(rvalid && rready && (|rresp)) consolidated_error_flag[1] <= 1'b1;
      // bit4: write data mux select conflict
      if(sel_mipi_write && sel_op_write) consolidated_error_flag[4] <= 1'b1;
      // bit5: request issued while PLL is not locked
      if((i_valid_req_clk81 || (|i_valid)) && (PllLocked != 2'b11)) consolidated_error_flag[5] <= 1'b1;
      // bit6: new start issued while dispatcher is still busy
      if(start && dispatcher_busy) consolidated_error_flag[6] <= 1'b1;
      // bit7: upstream read request while input stream is empty
      if(rden && empty) consolidated_error_flag[7] <= 1'b1;

      // bit2: AXI address channel backpressure timeout
      if(avalid && !aready) begin
        if(axi_addr_stall_cnt == AXI_STALL_THRESHOLD) consolidated_error_flag[2] <= 1'b1;
        else axi_addr_stall_cnt <= axi_addr_stall_cnt + 10'd1;
      end
      else begin
        axi_addr_stall_cnt <= 10'd0;
      end

      // bit3: AXI write-data channel backpressure timeout
      if(dram_in_wrvalid && !wr_id_o_wready) begin
        if(axi_write_stall_cnt == AXI_STALL_THRESHOLD) consolidated_error_flag[3] <= 1'b1;
        else axi_write_stall_cnt <= axi_write_stall_cnt + 10'd1;
      end
      else begin
        axi_write_stall_cnt <= 10'd0;
      end
    end
  end

  assign i_valid = {
    mc_config_valid,
    mc_wghts_valid,    
    mc_bias_valid,
    mc_img_valid,
    `ifdef FC mc_fc_valid, `endif //FC
    mc_acc_valid,
    mc_op_write_valid,
    `ifdef BIAS_FC mc_fc_bias_valid, `endif //BIAS_FC
    mc_dispatch_valid
    `ifdef ELTWISE ,mc_LeftOperand_valid, mc_RightOperand_valid `endif //ELTWISE
    `ifdef TRANSPOSE ,mc_ReshapeTranspose_valid `endif //TRANSPOSE
    `ifdef CONCAT    ,mc_Concat_valid `endif
   };

   assign in_address = {
    mc_config_addr,
    mc_wghts_addr,
    mc_bias_addr,
    mc_img_addr,
    `ifdef FC mc_fc_addr, `endif //FC
    mc_acc_addr,
    mc_op_write_addr,
    `ifdef BIAS_FC mc_fc_bias_addr, `endif //BIAS_FC
    mc_dispatch_addr
    `ifdef ELTWISE ,mc_LeftOperand_addr, mc_RightOperand_addr `endif //ELTWISE
    `ifdef TRANSPOSE ,mc_ReshapeTranspose_addr `endif //TRANSPOSE
    `ifdef CONCAT    ,mc_Concat_addr `endif
   };

   assign in_BLEN = {
    mc_config_bl,
    mc_wghts_bl,
    mc_bias_bl,
    mc_img_bl,
    `ifdef FC mc_fc_bl, `endif //FC
    mc_acc_bl,
    mc_op_write_bl,
    `ifdef BIAS_FC mc_fc_bias_bl, `endif //BIAS_FC
    mc_dispatch_bl
    `ifdef ELTWISE ,mc_LeftOperand_bl, mc_RightOperand_bl `endif //ELTWISE
    `ifdef TRANSPOSE ,mc_ReshapeTranspose_bl `endif //TRANSPOSE
    `ifdef CONCAT ,mc_Concat_bl `endif 
   };

   assign i_enable = {
    mc_config_rdreq,
    mc_wghts_rdreq,  
    mc_bias_rdreq,
    mc_img_rdreq,
    `ifdef FC mc_fc_rdreq, `endif //FC
    mc_acc_rdreq,
    mc_op_writereq,
    `ifdef BIAS_FC mc_fc_bias_rdreq, `endif //BIAS_FC
    mc_dispatch_readreq
    `ifdef ELTWISE ,mc_LeftOperand_rdreq, mc_RightOperand_rdreq `endif //ELTWSIE
    `ifdef TRANSPOSE ,mc_ReshapeTranspose_rdreq `endif //TRANSPOSE
    `ifdef CONCAT ,mc_Concat_rdreq `endif
   };

   assign i_last = {
    mc_config_last,
    mc_wghts_last,
    mc_bias_last,
    mc_img_last,
    `ifdef FC mc_fc_last, `endif //FC
    mc_acc_last,
    mc_op_write_last,
    `ifdef BIAS_FC mc_fc_bias_last, `endif //BIAS_FC
    mc_dispatch_last
    `ifdef ELTWISE ,mc_LeftOperand_last, mc_RightOperand_last `endif //ELTWISE
    `ifdef TRANSPOSE ,mc_ReshapeTranspose_last `endif //TRANSPOSE
    `ifdef CONCAT ,mc_Concat_last `endif
   };
   


  wire DdrInitDone;
  wire dispatcher_busy;
  //////////////////////////////


  /* --------- Memory Controller --------------*/

  Top_DRAM_controller # (
    .SYS_CLK_PERIOD(SYS_CLK_PERIOD),
    .NUM_PORTS(NUM_PORTS),
    .BURST_LENGTH_WIDTH(BURST_LENGTH_WIDTH),
    .ADDRESS_WIDTH(ADDRESS_WIDTH),
    .IN_ADDR(IN_ADDR),
    .PORT_ID(PORT_ID),
    .POINTER_COUNT(POINTER_COUNT),
    .RAM_DEPTH(RAM_DEPTH),
    .PORT_ID_WIDTH(PORT_ID_WIDTH),
    .ID_WIDTH(ID_WIDTH),
    .AXI_ID_BLEN_CON(AXI_ID_BLEN_CON),
    .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
    .AXI_BYTE_NUMBER(AXI_BYTE_NUMBER),
    .ADW_C(ADW_C),
    .ABN_C(ABN_C)
  )
  Top_DRAM_controller_inst (
    .clk(i_clk),
    .c_81_clk(c_81_clk),
    .rst(i_rst),
    .PllLocked(PllLocked),
    .DdrCtrl_CFG_RST_N(DdrCtrl_CFG_RST_N),
    .DdrCtrl_CFG_SEQ_RST(DdrCtrl_CFG_SEQ_RST),
    .DdrCtrl_CFG_SEQ_START(DdrCtrl_CFG_SEQ_START),
    .port_ctrl_i_valid_clk81(i_valid_req_clk81),
    .port_ctrl_i_address_clk81(in_address_clk81),
    .port_ctrl_i_BLEN_clk81(in_BLEN_clk81),
    .port_ctrl_i_rw_enable_clk81(i_rw_enable_clk81),
    .port_ctrl_i_last_clk81(i_last_clk81),
    .port_ctrl_i_valid(i_valid),
    .port_ctrl_i_address(in_address),
    .port_ctrl_i_BLEN(in_BLEN),
    .port_ctrl_i_rw_enable(i_enable),
    .port_ctrl_i_last(i_last),
    .axi_read_o_delay_data(dram_rd_data),
    .d_done(d_done),
	  .rd_r_last(dram_rd_data_last),
    .rd_r_valid(dram_rd_datavalid),
    .wr_id_o_wready(wr_id_o_wready),
    .wr_axi_blen(wr_burst_len),
    .wr_axi_valid(dram_in_wrvalid),
    .wr_axi_last(dram_in_wrlast),
    .wr_axi_data(dram_in_wrdata),
    .select_wr(select_wr),
    .select_rd(select_rd),
    .aid(aid),
    .aaddr(aaddr),
    .alen(alen),
    .asize(asize),
    .aburst(aburst),
    .alock(alock),
    .avalid(avalid),
    .aready(aready),
    .atype(atype),
    .wid(wid),
    .wstrb(wstrb),
    .wlast(wlast),
    .wvalid(wvalid),
    .wready(wready),
    .wdata(wdata),
    .rid(rid),
    .rlast(rlast),
    .rvalid(rvalid),
    .rready(rready),
    .rresp(rresp),
    .rdata(rdata),
    .bid(bid) ,
    .bvalid(bvalid),
    .bready(bready)
  );

  wire [AXI_ADDR_W-1:0] dispatch_start_address;
  wire [2*I_OP_SIZE_WIDTH-1:0] datasize_dispatch;
  wire [DISPATCH_ID_WIDTH-1:0] dispatch_id;
  wire [DISPATCHEN_WIDTH-1:0] dispatch_cpu_en;

  top_gati_module #(
      .INST_QUEUE_DEPTH(INST_QUEUE_DEPTH),
      .DRAM_IMG_FIFO_DEPTH(DRAM_IMG_FIFO_DEPTH),
      .IM2COL_FIFO_DEPTH(IM2COL_FIFO_DEPTH),
      .WEIGHT_FIFO_DEPTH(WEIGHT_FIFO_DEPTH),
      .PSUM_FIFO_DEPTH(PSUM_FIFO_DEPTH),
      .ACC_FIFO_DEPTH(ACC_FIFO_DEPTH),
      .BIAS_FIFO_DEPTH(BIAS_FIFO_DEPTH),
      .ACC_OP_FIFO_DEPTH(ACC_OP_FIFO_DEPTH),
      .QUANT_OP_FIFO_DEPTH(QUANT_OP_FIFO_DEPTH),
      .OP_WRITE_FIFO_DEPTH(OP_WRITE_FIFO_DEPTH),
      .ELTWISE_FIFO_DEPTH(ELTWISE_FIFO_DEPTH),
      .CONFIG_REQ_BLEN(CONFIG_REQ_BLEN),
      .IMG_REQ_BLEN(IMG_REQ_BLEN),
      .WEIGHT_REQ_BLEN(WEIGHT_REQ_BLEN),
      .FC_WEIGHT_REQ_BLEN(FC_WEIGHT_REQ_BLEN),
      .ACC_REQ_BLEN(ACC_REQ_BLEN),
      .BIAS_REQ_BLEN(BIAS_REQ_BLEN),
      .OP_WRITE_REQ_ACC_BLEN(OP_WRITE_REQ_ACC_BLEN),
      .OP_WRITE_REQ_QUA_BLEN(OP_WRITE_REQ_QUA_BLEN),
      .NUM_PORTS(NUM_PORTS),
      .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
      .AXI_DATA_BYTES(AXI_DATA_BYTES),
      .AXI_ADDR_W(AXI_ADDR_W),
      .BURST_LENGTH_WIDTH(BURST_LENGTH_WIDTH),
      .NUM_INSTRUCTIONS(NUM_INSTRUCTIONS),
      .INST_W(INST_W),
      .CONFIG_FIFO_OCCUPANCY(CONFIG_FIFO_OCCUPANCY),
      .IM2COL_BOUND_GEN_WIDTH(IM2COL_BOUND_GEN_WIDTH),
      .N_MOD_STAGES(N_MOD_STAGES),
      .POP_THRESHOLD(POP_THRESHOLD),
      .NSA_DSP(NSA_DSP),
      .NSA_LUT(NSA_LUT),
      .N_SA(N_SA),
      .DATA_WIDTH(DATA_WIDTH),
      .COL_SA(COL_SA),
      .COL_FC(COL_FC),
      .ROW(ROW),
      .W_PSUM(W_PSUM),
      .DATA_WIDTH_OB(DATA_WIDTH_OB),    
      .ACC_DW(ACC_DW),
      .N_BANK(N_BANK),
      .N_BRAM(N_BRAM),
      .FC_BRAM_DEPTH(FC_BRAM_DEPTH),
      .ACC_DATA_REORDER(ACC_DATA_REORDER),
      .N_FC_MUX(N_FC_MUX),
      .NO_PORT_FC(NO_PORT_FC),
      .W_CITER_CNT(W_CITER_CNT),
      .W_KITER_CNT(W_KITER_CNT),
      .I_ACC_SIZE_WIDTH(I_ACC_SIZE_WIDTH),
      .I_OP_SIZE_WIDTH(I_OP_SIZE_WIDTH),
      .ACCEN_WIDTH(ACCEN_WIDTH),
      .DISPATCH_ID_WIDTH(DISPATCH_ID_WIDTH),
      .DISPATCHEN_WIDTH(DISPATCHEN_WIDTH),
      .ACC_ONCHIP_WIDTH(ACC_ONCHIP_WIDTH),
      .MOD1(MOD1),
      .MOD2(MOD2),
      .N_DMUX_PORTS(N_DMUX_PORTS),
      .SHFT_REG_X(SHFT_REG_X),
      .BIAS_FIFO(BIAS_FIFO),
      .ACC_OP_FIFO(ACC_OP_FIFO),
      .QUANT_OP_FIFO(QUANT_OP_FIFO),
      .OP_FIFO(OP_FIFO),
      .ACC_FIFO(ACC_FIFO),
      .BIAS_FIFO_FC(BIAS_FIFO_FC),
      .NO_PORT_VA(NO_PORT_VA),
      .NO_PORT_BAC(NO_PORT_BAC),
      .ACC_TOGGLE(ACC_TOGGLE),
      .NO_PORT_BAFC(NO_PORT_BAFC)
    ) top_gati_module_inst (
      .i_clk(i_clk),
	    .s_clk(s_clk),
      .i_rst(i_rst),
      .dispatcher_busy(dispatcher_busy),
      .user_start(user_start),
      .mc_config_addr(mc_config_addr),
      .mc_config_rdreq(mc_config_rdreq),
      .mc_config_valid(mc_config_valid),
      .mc_config_bl(mc_config_bl),
      .mc_config_last(mc_config_last),
      .mc_img_addr(mc_img_addr),
      .mc_img_rdreq(mc_img_rdreq),
      .mc_img_valid(mc_img_valid),
      .mc_img_bl(mc_img_bl),
      .mc_img_last(mc_img_last),
      .mc_wghts_addr(mc_wghts_addr),
      .mc_wghts_rdreq(mc_wghts_rdreq),
      .mc_wghts_valid(mc_wghts_valid),
      .mc_wghts_bl(mc_wghts_bl),
      .mc_wghts_last(mc_wghts_last),

      `ifdef FC
      .mc_fc_addr(mc_fc_addr),
      .mc_fc_rdreq(mc_fc_rdreq),
      .mc_fc_valid(mc_fc_valid),
      .mc_fc_bl(mc_fc_bl),
      .mc_fc_last(mc_fc_last),
      `endif //FC

      .mc_bias_addr(mc_bias_addr),
      .mc_bias_rdreq(mc_bias_rdreq),
      .mc_bias_valid(mc_bias_valid),
      .mc_bias_bl(mc_bias_bl),
      .mc_bias_last(mc_bias_last),

      `ifdef BIAS_FC
      .mc_fc_bias_addr(mc_fc_bias_addr),
      .mc_fc_bias_rdreq(mc_fc_bias_rdreq),
      .mc_fc_bias_valid(mc_fc_bias_valid),
      .mc_fc_bias_bl(mc_fc_bias_bl),
      .mc_fc_bias_last(mc_fc_bias_last),
      `endif //BIAS_FC

      .mc_acc_addr(mc_acc_addr),
      .mc_acc_rdreq(mc_acc_rdreq),
      .mc_acc_valid(mc_acc_valid),
      .mc_acc_bl(mc_acc_bl),
      .mc_acc_last(mc_acc_last),
      .mc_op_write_addr(mc_op_write_addr),
      .mc_op_writereq(mc_op_writereq),
      .mc_op_write_valid(mc_op_write_valid),
      .mc_op_write_bl(mc_op_write_bl),
      .mc_op_write_last(mc_op_write_last),

      `ifdef ELTWISE 
      .mc_LeftOperand_addr(mc_LeftOperand_addr),
      .mc_LeftOperand_rdreq(mc_LeftOperand_rdreq),
      .mc_LeftOperand_valid(mc_LeftOperand_valid),
      .mc_LeftOperand_bl(mc_LeftOperand_bl),
      .mc_LeftOperand_last(mc_LeftOperand_last),
      .mc_RightOperand_addr(mc_RightOperand_addr),
      .mc_RightOperand_rdreq(mc_RightOperand_rdreq),
      .mc_RightOperand_valid(mc_RightOperand_valid),
      .mc_RightOperand_bl(mc_RightOperand_bl),
      .mc_RightOperand_last(mc_RightOperand_last),
      `endif

      `ifdef TRANSPOSE
      .mc_ReshapeTranspose_addr(mc_ReshapeTranspose_addr),
      .mc_ReshapeTranspose_bl(mc_ReshapeTranspose_bl),
      .mc_ReshapeTranspose_last(mc_ReshapeTranspose_last),
      .mc_ReshapeTranspose_rdreq(mc_ReshapeTranspose_rdreq),
      .mc_ReshapeTranspose_valid(mc_ReshapeTranspose_valid),
      `endif //TRANSPOSE

      `ifdef CONCAT
      .mc_Concat_addr(mc_Concat_addr),
      .mc_Concat_rdreq(mc_Concat_rdreq),
      .mc_Concat_valid(mc_Concat_valid),
      .mc_Concat_bl(mc_Concat_bl),
      .mc_Concat_last(mc_Concat_last),
      `endif

      .select(select_rd|select_wr),
      .dram_rd_datavalid(dram_rd_datavalid),
      .dram_rd_data_last(dram_rd_data_last),
      .dram_rd_data(dram_rd_data),
      .sel_op_write(sel_op_write),
	    .wready(wr_id_o_wready),
	    .wr_burst_len(wr_burst_len),
      .dv_op_write(dv_op_write),
      .o_data_last_op_write(data_last_op_write),
      .op_dram_fifo(op_dram_fifo),
      .layer_debug_pin(layer_debug_pin),
      .start(start),
      .layer_done(layer_done),
      .dispatch_id(dispatch_id),
      .dispatch_cpu_en(dispatch_cpu_en),
      .datasize_dispatch(datasize_dispatch),
      .dispatch_start_address(dispatch_start_address),
       
       // io signals to the board gpio 
      .kernal_count(kernal_count), // current kernal iteration number 
      .channel_count(channel_count), //current channel iteration number
      .layer_count(layer_count) ,
      .layer_cycles_count(layer_cycles_count),
      .stall_cycles_count(stall_cycles_count)
  );
 
  
  //DISPATCH (CPU Dispatch) Module to transfer the layer output to CPU for debugging
  
  top_dispatch # (
    .ADDR_W(AXI_ADDR_W),
    .DATA_SIZE(2*I_OP_SIZE_WIDTH),
    .ID(DISPATCH_ID_WIDTH),
    .W_ADDR($clog2(DISPATCH_FIFO_DEPTH)),
    .BURST_LEN(CPU_DISPATCH_REQ_BLEN),
    .BURST_LENGTH_WIDTH(BURST_LENGTH_WIDTH),
    .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
    .CPU_DATA_WIDTH(MIPI_DATA_WIDTH),
    .N_FIFO(CPU_DISPATCH_FIFO),
    .MIPI_FIFO_DEPTH(MIPI_FIFO_DEPTH),
    .REQ_FIFO_DEPTH(CPU_DISPATCH_REQ_FIFO_DEPTH)
  )
  top_dispatch_inst (
    .clk(i_clk),
    .clk_81mhz(c_81_clk),
    .rst(i_rst),
    .i_addr(dispatch_start_address), // comes from OP_Block instruction
    .i_data_size(datasize_dispatch), //i_img_dim_op*no.of kernels - for conv, i_img_dim_op*
    .i_id(dispatch_id), //comes from OP_Block instruction
    .dispatch_cpu(dispatch_cpu_en), // DispatchEn signal comes from OP_Block instruction
    .layer_done(layer_done), // from Iteration cnter module
    .i_start(start), // start signal from config block
    .dispatcher_busy(dispatcher_busy), //goes to config blk to hold the schedule of next instruction
    .read_write(mc_dispatch_readreq), // next 5 signals are DRAM read request signals
    .o_valid(mc_dispatch_valid),
    .o_last(mc_dispatch_last),
    .o_addr(mc_dispatch_addr),
    .o_blen(mc_dispatch_bl),
    .sel(select_rd[`MIPI_Rd]), //from DRAM controller
    .i_data_in(dram_rd_data), 
    .i_data_last(dram_rd_data_last),
    .i_data_valid(dram_rd_datavalid),
    .mipi_rd_en(mipi_fifo_rd_en), 
    .o_mipi_ready(),
    .mipi_fifo_empty(mipi_fifo_empty),
    .mipi_fifo_almost_empty(mipi_fifo_almost_empty),
    .mipi_rd_fifo_occupants(mipi_rd_fifo_occupants),
    .mipi_fifo_data_out(mipi_fifo_data_out),
    .mipi_fifo_data_valid(mipi_fifo_data_valid),
    .o_data_size_rah(data_size_rah),
    .o_valid_data_size_rah(valid_data_size_rah)
  );

endmodule



