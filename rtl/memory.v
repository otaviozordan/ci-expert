`timescale 1ns/1ps
// -----------------------------------------------------------------------------
// memory.v - Memoria interna de DEPTH palavras x DATA_WIDTH bits
//   Escrita sincrona (memoryWrite), leitura assincrona (memoryRead).
//   Com memoryRead = 0, data_out = 0. Reset assincrono zera o conteudo.
// -----------------------------------------------------------------------------
module memory #(
    parameter DATA_WIDTH = 16,
    parameter ADDR_WIDTH = 3,
    parameter DEPTH      = 8
) (
    input  wire                  clk,
    input  wire                  rst,
    input  wire                  memoryWrite,
    input  wire                  memoryRead,
    input  wire [ADDR_WIDTH-1:0] address,
    input  wire [DATA_WIDTH-1:0] data_in,
    output wire [DATA_WIDTH-1:0] data_out
);

    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    integer i;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < DEPTH; i = i + 1)
                mem[i] <= {DATA_WIDTH{1'b0}};
        end else if (memoryWrite) begin
            mem[address] <= data_in;
        end
    end

    assign data_out = memoryRead ? mem[address] : {DATA_WIDTH{1'b0}};

endmodule
