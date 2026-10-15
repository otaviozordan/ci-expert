`timescale 1ns/1ps
// -----------------------------------------------------------------------------
// top.v - Processador multiciclo (Datapath + Controle)
//
//   cmd_in[6:5] = muxA  (00 din_1, 01 din_2, 10 din_3, 11 dout_high)
//   cmd_in[4:3] = muxB  (00 din_1, 01 din_2, 10 din_3, 11 dout_low)
//   cmd_in[2:0] = opcode
//       000 ADD | 001 SUB | 010 MUL | 011 DIV
//       100 NOP | 101 LOAD | 110 STORE | 111 NOP
//
//   LOAD : reg_out <= mem[regA[2:0]]
//   STORE: mem[regA[2:0]] <= {dout_high, dout_low}
// -----------------------------------------------------------------------------
module top #(
    parameter WIDTH = 8
) (
    input  wire             clk,
    input  wire             rst,
    input  wire [6:0]       cmd_in,
    input  wire [WIDTH-1:0] din_1,
    input  wire [WIDTH-1:0] din_2,
    input  wire [WIDTH-1:0] din_3,
    output wire [WIDTH-1:0] dout_high,
    output wire [WIDTH-1:0] dout_low,
    output wire             zero,
    output wire             error,
    output wire             cpu_rdy
);

    // ---------------- sinais de controle ----------------
    wire       aluin_reg_en;
    wire       datain_reg_en;
    wire       aluout_reg_en;
    wire       memoryWrite;
    wire       memoryRead;
    wire       selmux2;
    wire       nvalid_data;
    wire [1:0] in_select_a;
    wire [1:0] in_select_b;
    wire [2:0] opcode;

    // ---------------- datapath ----------------
    wire [6:0]         reg_cmd;
    wire [WIDTH-1:0]   reg_a;
    wire [WIDTH-1:0]   reg_b;
    wire [2*WIDTH-1:0] alu_result;
    wire               alu_zero;
    wire               alu_error;
    wire [2*WIDTH-1:0] mem_data_out;
    wire [2*WIDTH-1:0] out_mux;
    wire [2*WIDTH-1:0] reg_out;
    wire [1:0]         reg_flags;    // {zero, error}

    assign dout_high = reg_out[2*WIDTH-1:WIDTH];
    assign dout_low  = reg_out[WIDTH-1:0];
    assign zero      = reg_flags[1];
    assign error     = reg_flags[0];

    // Registrador de comando (reg_cmd)
    register_bank #(.WIDTH(7)) u_reg_cmd (
        .clk   (clk),
        .rst   (rst),
        .wr_en (datain_reg_en),
        .d     (cmd_in),
        .q     (reg_cmd)
    );

    // Mux A + regA
    mux4_registered #(.WIDTH(WIDTH)) u_mux_a (
        .clk    (clk),
        .rst    (rst),
        .reg_en (aluin_reg_en),
        .sel    (in_select_a),
        .in0    (din_1),
        .in1    (din_2),
        .in2    (din_3),
        .in3    (dout_high),
        .out    (reg_a)
    );

    // Mux B + regB
    mux4_registered #(.WIDTH(WIDTH)) u_mux_b (
        .clk    (clk),
        .rst    (rst),
        .reg_en (aluin_reg_en),
        .sel    (in_select_b),
        .in0    (din_1),
        .in1    (din_2),
        .in2    (din_3),
        .in3    (dout_low),
        .out    (reg_b)
    );

    alu #(.WIDTH(WIDTH)) u_alu (
        .a           (reg_a),
        .b           (reg_b),
        .alu_op      (opcode),
        .nvalid_data (nvalid_data),
        .result      (alu_result),
        .zero        (alu_zero),
        .error       (alu_error)
    );

    memory #(
        .DATA_WIDTH (2*WIDTH),
        .ADDR_WIDTH (3),
        .DEPTH      (8)
    ) u_memory (
        .clk         (clk),
        .rst         (rst),
        .memoryWrite (memoryWrite),
        .memoryRead  (memoryRead),
        .address     (reg_a[2:0]),
        .data_in     (reg_out),
        .data_out    (mem_data_out)
    );

    // selmux2: 0 = ALU, 1 = memoria
    assign out_mux = selmux2 ? mem_data_out : alu_result;

    // Registrador de saida (reg_out)
    register_bank #(.WIDTH(2*WIDTH)) u_reg_out (
        .clk   (clk),
        .rst   (rst),
        .wr_en (aluout_reg_en),
        .d     (out_mux),
        .q     (reg_out)
    );

    // Registrador de flags (reg_flags) = {zero, error}
    register_bank #(.WIDTH(2)) u_reg_flags (
        .clk   (clk),
        .rst   (rst),
        .wr_en (aluout_reg_en),
        .d     ({alu_zero, alu_error}),
        .q     (reg_flags)
    );

    control u_control (
        .clk           (clk),
        .rst           (rst),
        .cmd_in        (cmd_in),
        .reg_cmd       (reg_cmd),
        .p_error       (reg_flags[0]),
        .aluin_reg_en  (aluin_reg_en),
        .datain_reg_en (datain_reg_en),
        .aluout_reg_en (aluout_reg_en),
        .cpu_rdy       (cpu_rdy),
        .memoryWrite   (memoryWrite),
        .memoryRead    (memoryRead),
        .selmux2       (selmux2),
        .nvalid_data   (nvalid_data),
        .in_select_a   (in_select_a),
        .in_select_b   (in_select_b),
        .opcode        (opcode)
    );

endmodule
