# CI Expert — Processador Multiciclo Parametrizado

Documentação oficial do projeto final do CI Expert: projeto, verificação, síntese e implementação física de um processador multiciclo de 3 estágios (Fetch/Decode, Execute, Store), do RTL ao Sign-Off.

Especificação de referência: [Roteiro_Projeto_CI_Expert.pdf](Roteiro_Projeto_CI_Expert.pdf).

## Equipe e trilhas

| # | Etapa do fluxo (Figura 1 do roteiro)                            | Responsável                  | Status        |
| - | --------------------------------------------------------------- | ----------------------------- | ------------- |
| 1 | [RTL Design](#1-rtl-design)                                      | Otávio Zordan Alves          | Concluído    |
| 2 | [Verification with Testbench](#2-verification-with-testbench)    | Melissa                       | Não iniciado |
| 3 | [Verification with UVM](#3-verification-with-uvm)                | Marina                        | Não iniciado |
| 4 | [Coverage Analysis](#4-coverage-analysis)                        | sem responsável definido     | Não iniciado |
| 5 | [Synthesis + DFT (Clock Gating)](#5-synthesis--dft-clock-gating) | *sem responsável definido* | Não iniciado |
| 6 | [Physical Implementation](#6-physical-implementation)            | João Matheus                 | Não iniciado |
| 7 | [Parasitic Extraction](#7-parasitic-extraction)                  | sem responsável definido     | Não iniciado |
| 8 | [Static Timing Analysis](#8-static-timing-analysis)              | sem responsável definido     | Não iniciado |
| 9 | [Sign-Off](#9-sign-off)                                          | sem responsável definido     | Não iniciado |

## Estrutura do repositório

Entregáveis obrigatórios do roteiro (seções 3.1 a 3.4) marcados com 📦.

```
rtl/                         1. RTL Design
  📦 top.v, control.v, alu.v, memory.v,
     register_bank.v, mux4.v, mux4_registered.v   (sintetizáveis, sem erros de compilação)
tb/                          2. Verification with Testbench
     Testbench funcional para depuração de formas de onda no Verdi
dv/                          3-4. Verification with UVM / Coverage Analysis
  uvm/env|seq|tests        📦 Ambiente UVM funcional (interface, sequencer, driver,
                              monitor, predictor, scoreboard) e testes (incl. 100k random)
  sva/                       Asserções SVA da FSM
  coverage/                  Coletores de cobertura funcional e cruzada
  scripts/                 📦 Scripts de simulação (VCS/Verdi)
  reports/                 📦 Relatórios de cobertura funcional/cruzada
                           📦 Log de simulação com UVM_ERROR: 0
syn/                         5. Synthesis + DFT (Clock Gating)
  constraints/             📦 Arquivo de restrições SDC
  scripts/                   Scripts Tcl do Design Compiler / Fusion Compiler
  netlist/                 📦 Netlist sintetizado com DFT (scan chains)
  reports/baseline|ppa1|ppa2 📦 Relatórios de QoR/Power e dados numéricos de PPA
pd/                          6-9. Physical Implementation → Sign-Off
  floorplan/                 Floorplan e rede de alimentação VDD/VSS
  scripts/                   Scripts Tcl (Fusion Compiler, STARRC, PrimeTime)
  outputs/                 📦 Layout final (DEF/GDSII)
  spef/                      Parasitas extraídos (STARRC)
  reports/drc_lvs/         📦 Relatórios de DRC/LVS zerados (0 shorts, 0 opens)
  reports/sta/             📦 Relatórios de timing sign-off e curvas de convergência de frequência
docs/apresentacao/         📦 Slides da apresentação final (20 min)
```

---

## 1. RTL Design

**Responsável:** Otávio Zordan Alves

### Situação atual

- Os 7 arquivos obrigatórios do roteiro (seção 3.1) estão implementados em [rtl/](rtl/), parametrizados por `WIDTH` (padrão 8).
- A FSM de controle usa 2 blocos `always`: um síncrono para o estado e um combinacional para próximo estado e saídas.
- Compila sem erros nem warnings no Icarus Verilog (`-g2005 -Wall`). **Ainda falta validar no Synopsys VCS.**

### Arquivos

| Arquivo                                       | Descrição                                                                                       |
| --------------------------------------------- | ------------------------------------------------------------------------------------------------- |
| [rtl/top.v](rtl/top.v)                         | Top-level: conecta datapath e controle conforme a Figura 2 do roteiro                             |
| [rtl/control.v](rtl/control.v)                 | Unidade de controle: FSM RST → FETCH → EXECUTE → STORE                                         |
| [rtl/alu.v](rtl/alu.v)                         | ALU combinacional: ADD, SUB, MUL e DIV, com resultado de 2·WIDTH bits e flags `zero`/`error` |
| [rtl/memory.v](rtl/memory.v)                   | Memória de 8 palavras × 2·WIDTH bits, com escrita síncrona e leitura assíncrona              |
| [rtl/register_bank.v](rtl/register_bank.v)     | Registrador com reset assíncrono e `wr_en` (usado em `reg_cmd`, `reg_out` e `reg_flags`) |
| [rtl/mux4.v](rtl/mux4.v)                       | Mux 4:1 combinacional                                                                             |
| [rtl/mux4_registered.v](rtl/mux4_registered.v) | Mux 4:1 + registrador (`regA`/`regB`), habilitado por `reg_en`                              |

### Interface do `top`

| Sinal                           | Direção | Largura | Descrição                                            |
| ------------------------------- | --------- | ------- | ------------------------------------------------------ |
| `clk`, `rst`                | in        | 1       | Clock (borda de subida) e reset assíncrono ativo alto |
| `cmd_in`                      | in        | 7       | `{muxA[6:5], muxB[4:3], opcode[2:0]}`                |
| `din_1`, `din_2`, `din_3` | in        | WIDTH   | Operandos externos                                     |
| `dout_high`, `dout_low`     | out       | WIDTH   | Metades alta e baixa de `reg_out`                    |
| `zero`, `error`             | out       | 1       | Flags registradas (`reg_flags = {zero, error}`)      |
| `cpu_rdy`                     | out       | 1       | Em 1 somente no estado FETCH                           |

### ISA

| Opcode    | Instrução | Efeito                                                          |
| --------- | ----------- | --------------------------------------------------------------- |
| 000       | ADD         | `reg_out = A + B`                                             |
| 001       | SUB         | `reg_out = A - B` (em 2·WIDTH bits)                          |
| 010       | MUL         | `reg_out = A × B`                                            |
| 011       | DIV         | `reg_out = A / B`; se B = 0, `error = 1` e `reg_out = -1` |
| 100 / 111 | NOP         | Não altera `reg_out` nem as flags                            |
| 101       | LOAD        | `reg_out = mem[A[2:0]]`                                       |
| 110       | STORE       | `mem[A[2:0]] = reg_out`; `reg_out` e flags são preservados |

`muxA`/`muxB`: `00` = din_1, `01` = din_2, `10` = din_3, `11` = realimentação (`dout_high` em A, `dout_low` em B).

Se um operando usa realimentação (`11`) e a instrução anterior terminou com `error = 1`, o controle ativa `nvalid_data`. Nesse caso a ALU sinaliza `error = 1` e força o resultado para -1, inclusive no LOAD.

### Comportamento da FSM por estado

| Estado       | Sinais ativos                                                                                                                                                                 |
| ------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| RST (00)     | Todas as saídas em 0, `cpu_rdy = 0`                                                                                                                                        |
| FETCH (01)   | `cpu_rdy = 1`, `aluin_reg_en = 1`, `datain_reg_en = 1`. O comando é capturado em `reg_cmd`                                                                           |
| EXECUTE (10) | `cpu_rdy = 0`, `aluin_reg_en = 1` (recarrega `regA`/`regB` com os seletores de `reg_cmd`), `opcode`, `nvalid_data`; LOAD → `memoryRead = 1`, `selmux2 = 1` |
| STORE (11)   | `aluout_reg_en = 1` (ADD/SUB/MUL/DIV/LOAD); STORE → `memoryWrite = 1`; LOAD mantém `memoryRead`/`selmux2`; NOP → nada                                              |

### Decisões de projeto (pontos em que o roteiro é ambíguo)

Os registradores só mudam na borda que encerra o estado, e o resultado só é gravado em `reg_out` no fim do STORE. Por isso, seguir o texto da seção 2.3 ao pé da letra deixa o processador incorreto. Nestes 5 pontos foi adotada a interpretação mais próxima do roteiro que mantém o funcionamento:

| # | Roteiro diz                                                          | Problema se seguido literalmente                                                                                     | O que foi feito                                                                                                     |
| - | -------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------- |
| 1 | `aluin_reg_en` só no FETCH; controle lê o comando de `reg_cmd` | No FETCH, `reg_cmd` ainda tem o comando **anterior**, então `regA`/`regB` capturam os operandos errados | `aluin_reg_en` também no EXECUTE: `regA`/`regB` são recarregados quando `reg_cmd` já tem o comando certo |
| 2 | `nvalid_data` no FETCH                                             | O erro só seria gravado no fim do STORE, quando o sinal já caiu; nunca seria registrado                            | `nvalid_data` ativo no EXECUTE e no STORE                                                                         |
| 3 | `memoryRead` no EXECUTE (LOAD)                                     | No STORE, `data_out` volta a 0 e o LOAD grava 0                                                                    | `memoryRead` e `selmux2` ativos no EXECUTE e no STORE                                                           |
| 4 | `aluout_reg_en` no STORE                                           | NOP e STORE sobrescreveriam `reg_out` com 0                                                                        | Não ativa `aluout_reg_en` para NOP e STORE                                                                       |
| 5 | `zero` quando o resultado é 0                                     | Todo LOAD terminaria com `zero = 1` (a ALU dá 0 para LOAD)                                                        | `zero` só vale para ADD/SUB/MUL/DIV                                                                              |

**Atenção, verificação:** `cmd_in` precisa estar válido no fim do FETCH, e `din_1`/`din_2`/`din_3` precisam ficar estáveis do FETCH até o fim do EXECUTE.

### Próximos passos da trilha RTL

- Validar a compilação no Synopsys VCS.
- Gerar os esquemáticos no Verdi para a apresentação.
- Confirmar com o professor as interpretações listadas em [Decisões de projeto](#decisões-de-projeto-pontos-em-que-o-roteiro-é-ambíguo).

---

## 2. Verification with Testbench

**Responsável:** Melissa · **Pasta:** [tb/](tb/) · **Ferramentas:** Synopsys VCS, Verdi

Testbench funcional para depuração visual de formas de onda no Verdi.

Ainda não iniciado.

## 3. Verification with UVM

**Responsável:** Marina · **Pasta:** [dv/uvm/](dv/uvm/), [dv/sva/](dv/sva/) · **Ferramentas:** Synopsys VCS, Verdi

Ambiente UVM (Interface, Virtual Interface, Sequencer, Driver, Monitor, Predictor e Scoreboard), testes por operação e teste de 100k instruções aleatórias com `UVM_ERROR: 0`, além de asserções SVA da FSM.

Ainda não iniciado.

## 4. Coverage Analysis

**Responsável:** Marina · **Pasta:** [dv/coverage/](dv/coverage/), [dv/reports/](dv/reports/) · **Ferramentas:** Synopsys Verdi (Coverage Viewer)

Cobertura funcional e cruzada (`cmd_in × error` e `cmd_in × zero`).

Ainda não iniciado.

## 5. Synthesis + DFT (Clock Gating)

**Responsável:** *sem responsável definido* · **Pasta:** [syn/](syn/) · **Ferramentas:** Synopsys Design Compiler / Fusion Compiler

Arquivo SDC, síntese com Clock Gating e Scan Chains, análise do caminho crítico reg→reg e PPA sweep (Baseline 30 ns, PPA1 20 ns, PPA2 10 ns).

Ainda não iniciado.

## 6. Physical Implementation

**Responsável:** João Matheus · **Pasta:** [pd/floorplan/](pd/floorplan/), [pd/scripts/](pd/scripts/), [pd/outputs/](pd/outputs/) · **Ferramentas:** Synopsys Fusion Compiler

Floorplan, rede de alimentação VDD/VSS, `place_opt`, CTS (`clock_opt`) e roteamento; layout final em DEF/GDSII.

Ainda não iniciado.

## 7. Parasitic Extraction

**Responsável:** João Matheus · **Pasta:** [pd/spef/](pd/spef/) · **Ferramentas:** Synopsys STARRC

Extração RC pós-roteamento, gerando o arquivo SPEF.

Ainda não iniciado.

## 8. Static Timing Analysis

**Responsável:** João Matheus · **Pasta:** [pd/reports/sta/](pd/reports/sta/) · **Ferramentas:** Synopsys PrimeTime

STA sign-off com o SPEF e gráfico de convergência de frequência, da síntese ao pós-roteamento.

Ainda não iniciado.

## 9. Sign-Off

**Responsável:** João Matheus · **Pasta:** [pd/reports/drc_lvs/](pd/reports/drc_lvs/) · **Ferramentas:** Synopsys Fusion Compiler

`check_lvs` e `check_design -checks routes` com 0 shorts e 0 opens; relatórios finais de timing.

Ainda não iniciado.
