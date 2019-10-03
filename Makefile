#
# Copyright (c) 2019, The Swedish Post and Telecom Authority (PTS)
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice, this
#    list of conditions and the following disclaimer.
#
# 2. Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#

#
# Author: Peter Magnusson, Assured AB
#

.PHONY: DIRS VVP clean default all run-tests lint lint_hdl lint_tb lint-submodules

default: lint-submodules all run-tests

all: DIRS VVPS

run-tests: all
	vvp output/vvp/nts_api_tb.vvp
	vvp output/vvp/nts_rx_buffer_tb.vvp
	vvp output/vvp/nts_parser_ctrl_tb.vvp
	vvp output/vvp/nts_tx_buffer_tb.vvp
	vvp output/vvp/nts_engine_tb.vvp
#	vvp output/vvp/bram_tb.vvp
#	vvp output/vvp/nts_dispatcher_tb.vvp

clean:
	rm -rf output

lint: lint_hdl lint_tb
lint_hdl:
	verilator --lint-only hdl/bram.v
	verilator --lint-only hdl/bram_dpge.v
	verilator --lint-only hdl/nts_api.v
	verilator --lint-only hdl/nts_parser_ctrl.v
	verilator --lint-only hdl/nts_timestamp.v
	verilator --lint-only hdl/nts_dispatcher.v hdl/bram.v
	verilator --lint-only hdl/nts_rx_buffer.v hdl/bram.v
	verilator --lint-only hdl/nts_tx_buffer.v hdl/bram.v
	verilator --lint-only hdl/nts_engine.v hdl/nts_tx_buffer.v hdl/nts_rx_buffer.v hdl/nts_parser_ctrl.v hdl/nts_api.v hdl/nts_timestamp.v hdl/bram.v sub/keymem/src/rtl/keymem.v
lint_tb:
	verilator --lint-only -Wno-STMTDLY tb/bram_tb.v hdl/bram.v
	verilator --lint-only -Wno-STMTDLY tb/nts_dispatcher_tb.v hdl/nts_dispatcher.v hdl/bram.v
	verilator --lint-only -Wno-STMTDLY tb/nts_api_tb.v hdl/nts_api.v
	verilator --lint-only -Wno-STMTDLY tb/nts_rx_buffer_tb.v hdl/nts_rx_buffer.v hdl/bram.v
	verilator --lint-only -Wno-STMTDLY tb/nts_tx_buffer_tb.v hdl/nts_tx_buffer.v hdl/bram.v
	verilator --lint-only -Wno-STMTDLY -Wno-UNOPTFLAT tb/nts_parser_ctrl_tb.v hdl/nts_parser_ctrl.v
	verilator --lint-only -Wno-STMTDLY -Wno-UNOPTFLAT tb/nts_engine_tb.v hdl/nts_engine.v hdl/nts_tx_buffer.v hdl/nts_rx_buffer.v hdl/nts_parser_ctrl.v hdl/nts_api.v hdl/nts_timestamp.v hdl/bram.v sub/keymem/src/rtl/keymem.v

lint-submodules:
	make -C sub/keymem/toolruns lint

DIRS: output/vvp

VVPS: \
 output/vvp/bram_tb.vvp \
 output/vvp/nts_dispatcher_tb.vvp \
 output/vvp/nts_api_tb.vvp \
 output/vvp/nts_timestamp_tb.vvp \
 output/vvp/nts_rx_buffer_tb.vvp \
 output/vvp/nts_tx_buffer_tb.vvp \
 output/vvp/nts_parser_ctrl_tb.vvp \
 output/vvp/nts_engine_tb.vvp

output/vvp:
	mkdir -p $@

output/vvp/nts_api_tb.vvp: tb/nts_api_tb.v hdl/nts_api.v
ifeq (,$(NO_LINT))
	verilator --lint-only -Wno-STMTDLY $^
endif
	iverilog -o $@ $^

output/vvp/nts_timestamp_tb.vvp: tb/nts_timestamp_tb.v hdl/nts_timestamp.v
ifeq (,$(NO_LINT))
	verilator --lint-only -Wno-STMTDLY -Wno-UNOPTFLAT $^
endif
	iverilog -o $@ $^

output/vvp/nts_parser_ctrl_tb.vvp: tb/nts_parser_ctrl_tb.v hdl/nts_parser_ctrl.v
ifeq (,$(NO_LINT))
	verilator --lint-only -Wno-STMTDLY -Wno-UNOPTFLAT $^
endif
	iverilog -o $@ $^

output/vvp/nts_dispatcher_tb.vvp: tb/nts_dispatcher_tb.v hdl/nts_dispatcher.v hdl/bram.v
ifeq (,$(NO_LINT))
	verilator --lint-only -Wno-STMTDLY $^
endif
	iverilog -o $@ $^

output/vvp/nts_rx_buffer_tb.vvp: tb/nts_rx_buffer_tb.v hdl/nts_rx_buffer.v hdl/bram.v
ifeq (,$(NO_LINT))
	verilator --lint-only -Wno-STMTDLY $^
endif
	iverilog -o $@ $^

output/vvp/nts_tx_buffer_tb.vvp: tb/nts_tx_buffer_tb.v hdl/nts_tx_buffer.v hdl/bram.v
ifeq (,$(NO_LINT))
	verilator --lint-only -Wno-STMTDLY $^
endif
	iverilog -o $@ $^

output/vvp/nts_engine_tb.vvp: tb/nts_engine_tb.v hdl/nts_tx_buffer.v hdl/nts_rx_buffer.v hdl/nts_parser_ctrl.v hdl/nts_engine.v hdl/nts_api.v hdl/nts_timestamp.v hdl/bram.v sub/keymem/src/rtl/keymem.v
ifeq (,$(NO_LINT))
	verilator --lint-only -Wno-STMTDLY -Wno-UNOPTFLAT $^
endif
	iverilog -o $@ $^

output/vvp/%_tb.vvp: tb/%_tb.v hdl/%.v
ifeq (,$(NO_LINT))
	verilator --lint-only -Wno-STMTDLY $^
endif
	iverilog -o $@ $^
