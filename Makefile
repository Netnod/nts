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

default: all run-tests

AES_SRC_PATH = sub/aes/src/rtl
AES_SRC = $(AES_SRC_PATH)/aes_core.v $(AES_SRC_PATH)/aes_decipher_block.v $(AES_SRC_PATH)/aes_encipher_block.v $(AES_SRC_PATH)/aes_inv_sbox.v $(AES_SRC_PATH)/aes_key_mem.v  $(AES_SRC_PATH)/aes_sbox.v
CMAC_SRC = sub/cmac/src/rtl/cmac_core.v $(AES_SRC)
CORE_SRC = sub/aes-siv/src/rtl/aes_siv_core.v $(CMAC_SRC)

all: DIRS VVPS

run-tests: all
	vvp output/vvp/nts_api_tb.vvp
	vvp output/vvp/nts_rx_buffer_tb.vvp
	vvp output/vvp/nts_parser_ctrl_tb.vvp
	vvp output/vvp/nts_tx_buffer_tb.vvp
	vvp output/vvp/nts_verify_secure_tb.vvp
	vvp output/vvp/nts_engine_tb.vvp
#	vvp output/vvp/bram_tb.vvp
#	vvp output/vvp/nts_dispatcher_tb.vvp

clean:
	rm -rf output

lint: lint_hdl lint_tb
lint_hdl:
	verilator --lint-only hdl/bram.v
	verilator --lint-only hdl/bram_dpge.v
	verilator --lint-only hdl/memory_ctrl.v hdl/bram_dpge.v
	verilator --lint-only hdl/nts_api.v
	verilator --lint-only hdl/nts_parser_ctrl.v
	verilator --lint-only hdl/nts_timestamp.v
	verilator --lint-only hdl/nts_dispatcher.v hdl/bram.v
	verilator --lint-only hdl/nts_rx_buffer.v hdl/bram.v
	verilator --lint-only hdl/nts_tx_buffer.v hdl/memory_ctrl.v hdl/bram_dpge.v
	verilator --lint-only -Wno-UNOPTFLAT hdl/nts_verify_secure.v hdl/bram_dp2w.v $(CORE_SRC)
	verilator --lint-only hdl/nts_engine.v hdl/nts_tx_buffer.v hdl/nts_verify_secure.v hdl/nts_rx_buffer.v hdl/nts_parser_ctrl.v hdl/nts_api.v hdl/nts_timestamp.v hdl/memory_ctrl.v hdl/bram.v hdl/bram_dpge.v hdl/bram_dp2w.v sub/keymem/src/rtl/keymem.v $(CORE_SRC)
lint_tb:
	verilator --lint-only -Wno-STMTDLY tb/bram_tb.v hdl/bram.v
	verilator --lint-only -Wno-STMTDLY tb/nts_dispatcher_tb.v hdl/nts_dispatcher.v hdl/bram.v
	verilator --lint-only -Wno-STMTDLY tb/nts_api_tb.v hdl/nts_api.v
	verilator --lint-only -Wno-STMTDLY tb/nts_rx_buffer_tb.v hdl/nts_rx_buffer.v hdl/bram.v
	verilator --lint-only -Wno-STMTDLY tb/nts_tx_buffer_tb.v hdl/nts_tx_buffer.v hdl/memory_ctrl.v hdl/bram_dpge.v
	verilator --lint-only -Wno-STMTDLY -Wno-UNOPTFLAT tb/nts_parser_ctrl_tb.v hdl/nts_parser_ctrl.v
	verilator --lint-only -Wno-STMTDLY -Wno-UNOPTFLAT tb/nts_verify_secure_tb.v hdl/nts_verify_secure.v hdl/bram_dp2w.v $(CORE_SRC)
	verilator --lint-only -Wno-STMTDLY -Wno-UNOPTFLAT tb/nts_engine_tb.v hdl/nts_engine.v hdl/nts_verify_secure.v hdl/nts_tx_buffer.v hdl/nts_rx_buffer.v hdl/nts_parser_ctrl.v hdl/nts_api.v hdl/nts_timestamp.v hdl/memory_ctrl.v hdl/bram.v hdl/bram_dpge.v hdl/bram_dp2w.v sub/keymem/src/rtl/keymem.v $(CORE_SRC)

lint-submodules:
	make -C sub/aes/toolruns lint
	make -C sub/aes-siv/toolruns lint
	make -C sub/cmac/toolruns lint
	make -C sub/keymem/toolruns lint
	make -C sub/nts_noncegen/toolruns lint
	make -C sub/siphash/toolruns lint

DIRS: output/vvp

VVPS: \
 output/vvp/bram_tb.vvp \
 output/vvp/memory_ctrl_tb.vvp \
 output/vvp/nts_dispatcher_tb.vvp \
 output/vvp/nts_api_tb.vvp \
 output/vvp/nts_timestamp_tb.vvp \
 output/vvp/nts_rx_buffer_tb.vvp \
 output/vvp/nts_tx_buffer_tb.vvp \
 output/vvp/nts_parser_ctrl_tb.vvp \
 output/vvp/nts_verify_secure_tb.vvp \
 output/vvp/nts_engine_tb.vvp

output/vvp:
	mkdir -p $@

output/vvp/memory_ctrl_tb.vvp: tb/memory_ctrl_tb.v hdl/memory_ctrl.v hdl/bram_dpge.v
ifeq (,$(NO_LINT))
	verilator --lint-only -Wno-STMTDLY $^
endif
	iverilog -o $@ $^

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

output/vvp/nts_tx_buffer_tb.vvp: tb/nts_tx_buffer_tb.v hdl/nts_tx_buffer.v hdl/memory_ctrl.v hdl/bram_dpge.v
ifeq (,$(NO_LINT))
	verilator --lint-only -Wno-STMTDLY $^
endif
	iverilog -o $@ $^

output/vvp/nts_verify_secure_tb.vvp: tb/nts_verify_secure_tb.v hdl/nts_verify_secure.v hdl/bram_dp2w.v $(CORE_SRC)
ifeq (,$(NO_LINT))
	verilator --lint-only -Wno-STMTDLY -Wno-UNOPTFLAT $^
endif
	iverilog -o $@ $^

output/vvp/nts_engine_tb.vvp: tb/nts_engine_tb.v hdl/nts_engine.v \
 hdl/nts_verify_secure.v hdl/nts_tx_buffer.v hdl/nts_rx_buffer.v hdl/nts_parser_ctrl.v hdl/nts_api.v hdl/nts_timestamp.v hdl/memory_ctrl.v \
 hdl/bram_dp2w.v hdl/bram_dpge.v hdl/bram.v \
 sub/keymem/src/rtl/keymem.v $(CORE_SRC)
ifeq (,$(NO_LINT))
	verilator --lint-only -Wno-STMTDLY -Wno-UNOPTFLAT $^
endif
	iverilog -o $@ $^

output/vvp/%_tb.vvp: tb/%_tb.v hdl/%.v
ifeq (,$(NO_LINT))
	verilator --lint-only -Wno-STMTDLY $^
endif
	iverilog -o $@ $^
