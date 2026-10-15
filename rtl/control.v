`timescale 1ns/1ps
// -----------------------------------------------------------------------------
// control.v - Unidade de Controle (FSM de 2 blocos always)
//
//   RST (00) -> FETCH/DECODE (01) -> EXECUTE (10) -> STORE (11) -> FETCH ...
//
//   cmd_in vem do registrador reg_cmd (saida Q), conforme o diagrama.
//
//   RST    : todas as saidas em 0; cpu_rdy = 0.
//   FETCH  : cpu_rdy = 1, aluin_reg_en = 1, datain_reg_en = 1.
//            reg_cmd captura o novo comando nesta borda.
//   EXECUTE: cpu_rdy = 0; aluin_reg_en = 1 recarrega regA/regB com os
//            seletores do comando ja armazenado em reg_cmd. LOAD -> memoryRead.
//   STORE  : aluout_reg_en = 1 (ADD/SUB/MUL/DIV/LOAD); STORE -> memoryWrite.
//            NOP nao altera reg_out/flags; STORE grava reg_out na memoria e
//            preserva reg_out/flags.
//
//   nvalid_data = algum operando usa realimentacao (sel = 2'b11) e a flag
//   error registrada (p_error) da instrucao anterior esta ativa. Fica ativo
//   em EXECUTE e STORE, enquanto a ALU calcula o valor capturado em reg_out.
//   memoryRead/selmux2 ficam ativos em EXECUTE e STORE no LOAD para que o dado
//   lido de forma assincrona esteja estavel na borda que carrega reg_out.
// -----------------------------------------------------------------------------
module control (
    input  wire       clk,
    input  wire       rst,
    input  wire [6:0] cmd_in,        // comando registrado (reg_cmd)
    input  wire       p_error,       // flag error registrada
    output reg        aluin_reg_en,
    output reg        datain_reg_en,
    output reg        aluout_reg_en,
    output reg        cpu_rdy,
    output reg        memoryWrite,
    output reg        memoryRead,
    output reg        selmux2,
    output reg        nvalid_data,
    output reg  [1:0] in_select_a,
    output reg  [1:0] in_select_b,
    output reg  [2:0] opcode
);

    localparam [1:0] S_RST     = 2'b00;
    localparam [1:0] S_FETCH   = 2'b01;
    localparam [1:0] S_EXECUTE = 2'b10;
    localparam [1:0] S_STORE   = 2'b11;

    localparam [2:0] OP_NOP0  = 3'b100;
    localparam [2:0] OP_LOAD  = 3'b101;
    localparam [2:0] OP_STORE = 3'b110;
    localparam [2:0] OP_NOP1  = 3'b111;

    reg [1:0] state, next_state;
    reg       uses_feedback;

    // ---------------- Bloco 1: registrador de estado (sincrono) -------------
    always @(posedge clk or posedge rst) begin
        if (rst)
            state <= S_RST;
        else
            state <= next_state;
    end

    // ---------------- Bloco 2: proximo estado e saidas (combinacional) ------
    always @(*) begin
        // valores padrao
        next_state    = state;
        aluin_reg_en  = 1'b0;
        datain_reg_en = 1'b0;
        aluout_reg_en = 1'b0;
        cpu_rdy       = 1'b0;
        memoryWrite   = 1'b0;
        memoryRead    = 1'b0;
        selmux2       = 1'b0;
        nvalid_data   = 1'b0;
        in_select_a   = 2'b00;
        in_select_b   = 2'b00;
        opcode        = 3'b000;

        uses_feedback = (cmd_in[6:5] == 2'b11) | (cmd_in[4:3] == 2'b11);

        case (state)
            S_RST: begin
                next_state = S_FETCH;
            end

            S_FETCH: begin
                next_state    = S_EXECUTE;
                cpu_rdy       = 1'b1;
                aluin_reg_en  = 1'b1;
                datain_reg_en = 1'b1;
            end

            S_EXECUTE: begin
                next_state   = S_STORE;
                aluin_reg_en = 1'b1;
                in_select_a  = cmd_in[6:5];
                in_select_b  = cmd_in[4:3];
                opcode       = cmd_in[2:0];
                nvalid_data  = uses_feedback & p_error;
                if (cmd_in[2:0] == OP_LOAD) begin
                    memoryRead = 1'b1;
                    selmux2    = ~nvalid_data;  // erro -> reg_out recebe -1 da ALU
                end
            end

            S_STORE: begin
                next_state  = S_FETCH;
                in_select_a = cmd_in[6:5];
                in_select_b = cmd_in[4:3];
                opcode      = cmd_in[2:0];
                nvalid_data = uses_feedback & p_error;
                case (cmd_in[2:0])
                    OP_STORE: memoryWrite = 1'b1;
                    OP_NOP0,
                    OP_NOP1:  ; // mantem reg_out e flags
                    OP_LOAD: begin
                        memoryRead    = 1'b1;
                        selmux2       = ~nvalid_data;
                        aluout_reg_en = 1'b1;
                    end
                    default:  aluout_reg_en = 1'b1; // ADD/SUB/MUL/DIV
                endcase
            end

            default: next_state = S_RST;
        endcase
    end

endmodule
