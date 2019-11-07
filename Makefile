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

.PHONY: DIRS VVP clean default all \
 lint lint_hdl lint_tb lint-submodules \
 sim-api sim-engine sim-parser sim-rxbuf sim-txbuf sim-secure sim

default: all sim

AES_SRC_PATH = sub/aes/src/rtl
AES_SRC = $(AES_SRC_PATH)/aes_core.v $(AES_SRC_PATH)/aes_decipher_block.v $(AES_SRC_PATH)/aes_encipher_block.v $(AES_SRC_PATH)/aes_inv_sbox.v $(AES_SRC_PATH)/aes_key_mem.v  $(AES_SRC_PATH)/aes_sbox.v
CMAC_SRC = sub/cmac/src/rtl/cmac_core.v $(AES_SRC)
SIV_SRC = sub/aes-siv/src/rtl/aes_siv_core.v $(CMAC_SRC)

ifeq ($(VLINT),)
VLINT=tools/verilator-4.018/bin/verilator
endif

ifeq ($(VLINT_FLAGS),)
VLINT_FLAGS= --lint-only
endif

all: DIRS VVPS

sim-api: output/vvp/nts_api_tb.vvp
	vvp $^

sim-engine: output/vvp/nts_engine_tb.vvp
	vvp $^

sim-parser: output/vvp/nts_parser_ctrl_tb.vvp
	vvp $^

sim-rxbuf: output/vvp/nts_rx_buffer_tb.vvp
	vvp $^

sim-txbuf: output/vvp/nts_tx_buffer_tb.vvp
	vvp $^

sim-secure: output/vvp/nts_verify_secure_tb.vvp
	vvp $^

sim: sim-api sim-engine sim-parser sim-rxbuf sim-secure sim-txbuf

clean:
	rm -rf output

lint: lint_hdl lint_tb
lint_hdl:
	$(VLINT) $(VLINT_FLAGS) hdl/bram.v
	$(VLINT) $(VLINT_FLAGS) hdl/bram_dpge.v
	$(VLINT) $(VLINT_FLAGS) hdl/memory_ctrl.v hdl/bram_dpge.v
	$(VLINT) $(VLINT_FLAGS) hdl/nts_api.v
	$(VLINT) $(VLINT_FLAGS) hdl/nts_parser_ctrl.v
	$(VLINT) $(VLINT_FLAGS) hdl/nts_timestamp.v
	$(VLINT) $(VLINT_FLAGS) hdl/nts_dispatcher.v hdl/bram.v
	$(VLINT) $(VLINT_FLAGS) hdl/nts_rx_buffer.v hdl/bram.v
	$(VLINT) $(VLINT_FLAGS) hdl/nts_tx_buffer.v hdl/memory_ctrl.v hdl/bram_dpge.v
	$(VLINT) $(VLINT_FLAGS) -Wno-UNOPTFLAT hdl/nts_verify_secure.v hdl/bram_dp2w.v $(SIV_SRC)
	$(VLINT) $(VLINT_FLAGS) hdl/nts_engine.v hdl/nts_tx_buffer.v hdl/nts_verify_secure.v hdl/nts_rx_buffer.v hdl/nts_parser_ctrl.v hdl/nts_api.v hdl/nts_timestamp.v hdl/memory_ctrl.v hdl/bram.v hdl/bram_dpge.v hdl/bram_dp2w.v sub/keymem/src/rtl/keymem.v $(SIV_SRC)
lint_tb:
	$(VLINT) $(VLINT_FLAGS) -Wno-STMTDLY tb/bram_tb.v hdl/bram.v
	$(VLINT) $(VLINT_FLAGS) -Wno-STMTDLY tb/nts_dispatcher_tb.v hdl/nts_dispatcher.v hdl/bram.v
	$(VLINT) $(VLINT_FLAGS) -Wno-STMTDLY tb/nts_api_tb.v hdl/nts_api.v
	$(VLINT) $(VLINT_FLAGS) -Wno-STMTDLY tb/nts_rx_buffer_tb.v hdl/nts_rx_buffer.v hdl/bram.v
	$(VLINT) $(VLINT_FLAGS) -Wno-STMTDLY tb/nts_tx_buffer_tb.v hdl/nts_tx_buffer.v hdl/memory_ctrl.v hdl/bram_dpge.v
	$(VLINT) $(VLINT_FLAGS) -Wno-STMTDLY -Wno-UNOPTFLAT tb/nts_parser_ctrl_tb.v hdl/nts_parser_ctrl.v
	$(VLINT) $(VLINT_FLAGS) -Wno-STMTDLY -Wno-UNOPTFLAT tb/nts_verify_secure_tb.v hdl/nts_verify_secure.v hdl/bram_dp2w.v $(SIV_SRC)
	$(VLINT) $(VLINT_FLAGS) -Wno-STMTDLY -Wno-UNOPTFLAT tb/nts_engine_tb.v hdl/nts_engine.v hdl/nts_verify_secure.v hdl/nts_tx_buffer.v hdl/nts_rx_buffer.v hdl/nts_parser_ctrl.v hdl/nts_api.v hdl/nts_timestamp.v hdl/memory_ctrl.v hdl/bram.v hdl/bram_dpge.v hdl/bram_dp2w.v sub/keymem/src/rtl/keymem.v $(SIV_SRC)

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
ifeq (,$(NO_VLINT))
	$(VLINT) $(VLINT_FLAGS) -Wno-STMTDLY $^
endif
	iverilog -o $@ $^

output/vvp/nts_api_tb.vvp: tb/nts_api_tb.v hdl/nts_api.v
ifeq (,$(NO_VLINT))
	$(VLINT) $(VLINT_FLAGS) -Wno-STMTDLY $^
endif
	iverilog -o $@ $^

output/vvp/nts_timestamp_tb.vvp: tb/nts_timestamp_tb.v hdl/nts_timestamp.v
ifeq (,$(NO_VLINT))
	$(VLINT) $(VLINT_FLAGS) -Wno-STMTDLY -Wno-UNOPTFLAT $^
endif
	iverilog -o $@ $^

output/vvp/nts_parser_ctrl_tb.vvp: tb/nts_parser_ctrl_tb.v hdl/nts_parser_ctrl.v
ifeq (,$(NO_VLINT))
	$(VLINT) $(VLINT_FLAGS) -Wno-STMTDLY -Wno-UNOPTFLAT $^
endif
	iverilog -o $@ $^

output/vvp/nts_dispatcher_tb.vvp: tb/nts_dispatcher_tb.v hdl/nts_dispatcher.v hdl/bram.v
ifeq (,$(NO_VLINT))
	$(VLINT) $(VLINT_FLAGS) -Wno-STMTDLY $^
endif
	iverilog -o $@ $^

output/vvp/nts_rx_buffer_tb.vvp: tb/nts_rx_buffer_tb.v hdl/nts_rx_buffer.v hdl/bram.v
ifeq (,$(NO_VLINT))
	$(VLINT) $(VLINT_FLAGS) -Wno-STMTDLY $^
endif
	iverilog -o $@ $^

output/vvp/nts_tx_buffer_tb.vvp: tb/nts_tx_buffer_tb.v hdl/nts_tx_buffer.v hdl/memory_ctrl.v hdl/bram_dpge.v
ifeq (,$(NO_VLINT))
	$(VLINT) $(VLINT_FLAGS) -Wno-STMTDLY $^
endif
	iverilog -o $@ $^

output/vvp/nts_verify_secure_tb.vvp: tb/nts_verify_secure_tb.v hdl/nts_verify_secure.v hdl/bram_dp2w.v $(SIV_SRC)
ifeq (,$(NO_VLINT))
	$(VLINT) $(VLINT_FLAGS) -Wno-STMTDLY -Wno-UNOPTFLAT $^
endif
	iverilog -o $@ $^

output/vvp/nts_engine_tb.vvp: tb/nts_engine_tb.v hdl/nts_engine.v \
 hdl/nts_verify_secure.v hdl/nts_tx_buffer.v hdl/nts_rx_buffer.v hdl/nts_parser_ctrl.v hdl/nts_api.v hdl/nts_timestamp.v hdl/memory_ctrl.v \
 hdl/bram_dp2w.v hdl/bram_dpge.v hdl/bram.v \
 sub/keymem/src/rtl/keymem.v $(SIV_SRC)
ifeq (,$(NO_VLINT))
	$(VLINT) $(VLINT_FLAGS) -Wno-STMTDLY -Wno-UNOPTFLAT $^
endif
	iverilog -o $@ $^

output/vvp/%_tb.vvp: tb/%_tb.v hdl/%.v
ifeq (,$(NO_VLINT))
	$(VLINT) $(VLINT_FLAGS) -Wno-STMTDLY $^
endif
	iverilog -o $@ $^
