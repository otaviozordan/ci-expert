`timescale 1ns/1ps
// -----------------------------------------------------------------------------
// alu.v - Unidade Logica e Aritmetica
//   Operandos de WIDTH bits, resultado de 2*WIDTH bits.
//   error = divisao por zero OU nvalid_data (reuso de dado invalido).
//   Sob erro, result = -1 (todos os bits em 1) e zero = 0.
//   Opcodes nao aritmeticos (NOP/LOAD/STORE): result = 0, zero = 0.
// -----------------------------------------------------------------------------
module alu #(
    parameter WIDTH = 8
) (
    input  wire [WIDTH-1:0]   a,
    input  wire [WIDTH-1:0]   b,
    input  wire [2:0]         alu_op,
    input  wire               nvalid_data,
    output reg  [2*WIDTH-1:0] result,
    output reg                zero,
    output reg                error
);

    localparam OP_ADD = 3'b000;
    localparam OP_SUB = 3'b001;
    localparam OP_MUL = 3'b010;
    localparam OP_DIV = 3'b011;

    // Operandos estendidos com zero para 2*WIDTH bits
    wire [2*WIDTH-1:0] a_ext = {{WIDTH{1'b0}}, a};
    wire [2*WIDTH-1:0] b_ext = {{WIDTH{1'b0}}, b};

    reg [2*WIDTH-1:0] raw;
    reg               arith;
    reg               div_by_zero;

    always @(*) begin
        raw         = {2*WIDTH{1'b0}};
        arith       = 1'b1;
        div_by_zero = 1'b0;

        case (alu_op)
            OP_ADD: raw = a_ext + b_ext;
            OP_SUB: raw = a_ext - b_ext;
            OP_MUL: raw = a_ext * b_ext;
            OP_DIV: begin
                if (b == {WIDTH{1'b0}})
                    div_by_zero = 1'b1;
                else
                    raw = a_ext / b_ext;
            end
            default: arith = 1'b0;
        endcase

        error = div_by_zero | nvalid_data;

        if (error) begin
            result = {2*WIDTH{1'b1}};
            zero   = 1'b0;
        end else begin
            result = raw;
            zero   = arith & (raw == {2*WIDTH{1'b0}});
        end
    end

endmodule
