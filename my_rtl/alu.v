module alu#(
    parameter WIDTH = 8
)
(
    input wire [WIDTH-1:0] a,
    input wire [WIDTH-1:0] b,
    input wire [2:0] alu_op,
    input wire nvalid_data,

    output reg [2*WIDTH-1:0] result,
    output reg zero,
    output reg error
);

    //Parametros de operação da ALU
    localparam OP_ADD = 3'b000;
    localparam OP_SUB = 3'b001;
    localparam OP_MUL = 3'b010;
    localparam OP_DIV = 3'b011;

    // Operandos estendidos com zero para 2*WIDTH bits
    wire [2*WIDTH-1:0] a_ext = {{WIDTH{1'b0}}, a};
    wire [2*WIDTH-1:0] b_ext = {{WIDTH{1'b0}}, b};

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            result <= 0;
            zero <= 0;
            error <= 0;
        end else if (!nvalid_data) begin
            case (alu_op)
                OP_ADD: result <= a_ext + b_ext;
                OP_SUB: result <= a_ext - b_ext;
                OP_MUL: result <= a_ext * b_ext;
                OP_DIV: result <= (b_ext == 0) ? 0 : a_ext / b_ext;
                default: result <= 0;
            endcase
            zero <= (result == 0);
            error <= (alu_op == OP_DIV && b_ext == 0);
        end
    end

endmodule