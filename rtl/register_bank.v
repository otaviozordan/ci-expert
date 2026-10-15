`timescale 1ns/1ps
// -----------------------------------------------------------------------------
// register_bank.v - Registrador parametrizado
//   Borda de subida de clk, reset assincrono (rst ativo alto), enable de escrita.
// -----------------------------------------------------------------------------
module register_bank #(
    parameter WIDTH = 8
) (
    input  wire             clk,
    input  wire             rst,
    input  wire             wr_en,
    input  wire [WIDTH-1:0] d,
    output reg  [WIDTH-1:0] q
);

    always @(posedge clk or posedge rst) begin
        if (rst)
            q <= {WIDTH{1'b0}};
        else if (wr_en)
            q <= d;
    end

endmodule
