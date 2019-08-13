.PHONY: DIRS VVP default all lint

default: lint all

all: DIRS VVPS
	vvp output/vvp/bram_tb.vvp
	vvp output/vvp/nts_dispatcher_tb.vvp

lint:
	verilator --lint-only hdl/bram.v
	verilator --lint-only hdl/nts_dispatcher.v hdl/bram.v
	verilator --lint-only -Wno-STMTDLY --top-module nts_dispatcher_front_tb tb/nts_dispatcher_tb.v hdl/nts_dispatcher.v hdl/bram.v
	verilator --lint-only -Wno-STMTDLY tb/bram_tb.v hdl/bram.v

DIRS: output/vvp

VVPS: output/vvp/bram_tb.vvp output/vvp/nts_dispatcher.vvp output/vvp/nts_dispatcher_tb.vvp

output/vvp:
	mkdir -p $@

output/vvp/nts_dispatcher_tb.vvp: tb/nts_dispatcher_tb.v hdl/nts_dispatcher.v hdl/bram.v
	iverilog -o $@ $^

output/vvp/nts_dispatcher.vvp: hdl/nts_dispatcher.v hdl/bram.v
	iverilog -o $@ $^

output/vvp/%_tb.vvp: tb/%_tb.v hdl/%.v
	iverilog -o $@ $^
