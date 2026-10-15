module top #(
    parameter WIDTH = 8
)(
    input wire clk,
    input wire rst,
    input wire [6:0] cmd_in,
    input wire [WIDTH-1:0] din_1,
    input wire [WIDTH-1:0] din_2,
    input wire [WIDTH-1:0] din_3,

    output wire [WIDTH-1:0] dout_high,
    output wire [WIDTH-1:0] dout_low,
    output wire zero,
    output wire error,
    output wire cpu_rdy
);

// ----------------------------------------
// ---------- Sinais de controle ----------
// ----------------------------------------

wire datain_reg_en; // Habilita escrita no registrador de comando

// ---- Sinais dos Mux dos registradores de entrada da ALU ----
wire [1:0] in_select_a; // Seleciona a entrada A do ALU (00: din_1, 01: din_2, 10: din_3, 11: dout_high)
wire [1:0] in_select_b; // Seleciona a entrada B do ALU (00: din_1, 01: din_2, 10: din_3, 11: dout_low)
wire aluin_reg_en; // Habilita escrita no registrador de entrada na ALU

// ---- Sinais de controle da ALU ----
wire nvalid_data; // Indica que os dados de entrada não são válidos
wire [2:0] opcode; // Código da operação a ser realizada pela ALU

// ---- Sinais de controle da memória ----
wire memoryWrite; // Habilita escrita na memória
wire memoryRead; // Habilita leitura da memória

// ----- Sinais do Mux de saída da memória ----
wire selmux2; // Seleciona a saída da memória (0: alu_result, 1: mem_data_out)

// ----- Sinais do registrador de saída ----
wire aluout_reg_en; // Habilita escrita no registrador de saída da ALU

// ----------------------------------------
// --------------- Datapath ---------------
// ----------------------------------------

wire [6:0] reg_cmd; // Registrador de comando

// Saida dos multiplexadores de entrada da ALU
wire [WIDTH-1:0] out_mux_a; // Registrador de entrada A da ALU
wire [WIDTH-1:0] out_mux_b; // Registrador de entrada B da ALU

// Registradores de entrada da ALU
wire [WIDTH-1:0] reg_a; // Registrador de entrada A da ALU
wire [WIDTH-1:0] reg_b; // Registrador de entrada B da ALU

// Saída da ALU
wire [2*WIDTH-1:0] alu_result; // Resultado da ALU
wire alu_zero; // Indica que o resultado da ALU é zero
wire alu_error; // Indica que ocorreu um erro na ALU

// Saída da memória
wire [2*WIDTH-1:0] mem_data_out; // Dados lidos da memória

// Saída do Mux de saída da memória e ALU
wire [2*WIDTH-1:0] out_mux; 

// Registrador de saída
wire [2*WIDTH-1:0] reg_out; // Registrador de saída
wire [1:0] reg_flags; // Registrador de flags {zero, error}

// Atribuições das saídas do módulo
assign dout_high = reg_out[2*WIDTH-1:WIDTH];
assign dout_low = reg_out[WIDTH-1:0];
assign zero = reg_flags[0];
assign error = reg_flags[1];
assign cpu_rdy = 1;

// ----------------------------------------
// ------- Instanciação dos módulos -------
// ----------------------------------------

// Instanciação do registrador de comando (reg_cmd)

//O .WIDTH(7) indica que o registrador de comando tem 7 bits de largura
//O u_ é um prefixo usado para indicar que é uma instância de um módulo
register #(.WIDTH(7)) u_reg_cmd ( 
    .clk(clk),
    .rst(rst),
    .wr_en(datain_reg_en),
    .d(cmd_in),
    .q(reg_cmd)
);

// Instanciação do Mux A
mux4 #(.WIDTH(WIDTH)) u_mux_a (
    .clk(clk),
    .rst(rst),
    .sel(in_select_a),
    .in0(din_1),
    .in1(din_2),
    .in2(din_3),
    .in3(dout_high),
    .out(out_mux_a)
);

// Intanciação do registrador de entrada A da ALU
register #(.WIDTH(WIDTH)) u_reg_a (
    .clk(clk),
    .rst(rst),
    .wr_en(aluin_reg_en),
    .d(out_mux_a),
    .q(reg_a)
);

// Instanciação do Mux B
mux4 #(.WIDTH(WIDTH)) u_mux_b (
    .clk(clk),
    .rst(rst),
    .sel(in_select_b),
    .in0(din_1),
    .in1(din_2),
    .in2(din_3),
    .in3(dout_low),
    .out(out_mux_b)
);

// Intanciação do registrador de entrada B da ALU
register #(.WIDTH(WIDTH)) u_reg_b (
    .clk(clk),
    .rst(rst),
    .wr_en(aluin_reg_en),
    .d(out_mux_b),
    .q(reg_b)
);

// Instanciação da ALU
alu #(.WIDTH(WIDTH)) u_alu (
    .a(reg_a),
    .b(reg_b),
    .alu_op(opcode),
    .nvalid_data(nvalid_data),
    .result(alu_result),
    .zero(alu_zero),
    .error(alu_error)
);

// Instanciação da memória
memoria #(
    .DATA_WIDTH(2*WIDTH),
    .ADDR_WIDTH(3), // 2^3 = 8 endereços
    .DEPTH(8) // 8 palavras de 16 bits
)
u_memoria (
    .clk(clk),
    .rst(rst),
    .wr_en(memoryWrite),
    .rd_en(memoryRead),
    .addr(reg_a), // Endereço de escrita/leitura é o valor do registrador A
    .data_in(reg_out), // Dados de entrada são os dados do registrador de saída
    .data_out(mem_data_out) // Dados de saída são os dados lidos da memória
);

assign out_mux = selmux2 ? mem_data_out : alu_result;

// Instanciação do registrador de saída
register #(.WIDTH(2*WIDTH)) u_reg_out (
    .clk(clk),
    .rst(rst),
    .wr_en(aluout_reg_en),
    .d(out_mux),
    .q(reg_out)
);

// Instanciação do registrador de flags
register #(.WIDTH(2)) u_reg_flags (
    .clk(clk),
    .rst(rst),
    .wr_en(aluout_reg_en),
    .d({alu_zero, alu_error}),
    .q(reg_flags)
); 

// Instanciação do controlador
controlador u_controlador (
    .clk(clk),
    .rst(rst),
    .cmd_in(reg_cmd),
    .nvalid_data(nvalid_data),
    .alu_zero(alu_zero),
    .alu_error(alu_error),
    .datain_reg_en(datain_reg_en),
    .in_select_a(in_select_a),
    .in_select_b(in_select_b),
    .aluin_reg_en(aluin_reg_en),
    .opcode(opcode),
    .memoryWrite(memoryWrite),
    .memoryRead(memoryRead),
    .selmux2(selmux2),
    .aluout_reg_en(aluout_reg_en)
);

endmodule