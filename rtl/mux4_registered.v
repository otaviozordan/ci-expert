`timescale 1ns/1ps
// -----------------------------------------------------------------------------
// mux4_registered.v - Mux 4:1 seguido de registrador (regA / regB)
//   A saida do mux e capturada na borda de subida quando reg_en = 1.
// -----------------------------------------------------------------------------
module mux4_registered #(
    parameter WIDTH = 8
) (
    input  wire             clk,
    input  wire             rst,
    input  wire             reg_en,
    input  wire [1:0]       sel,
    input  wire [WIDTH-1:0] in0,
    input  wire [WIDTH-1:0] in1,
    input  wire [WIDTH-1:0] in2,
    input  wire [WIDTH-1:0] in3,
    output wire [WIDTH-1:0] out
);

    wire [WIDTH-1:0] mux_out;

    mux4 #(.WIDTH(WIDTH)) u_mux (
        .sel (sel),
        .in0 (in0),
        .in1 (in1),
        .in2 (in2),
        .in3 (in3),
        .out (mux_out)
    );

    register_bank #(.WIDTH(WIDTH)) u_reg (
        .clk   (clk),
        .rst   (rst),
        .wr_en (reg_en),
        .d     (mux_out),
        .q     (out)
    );

endmodule
