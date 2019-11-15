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
 lint lint_src/rtl/nts_engine int_tb lint-submodules \
 sim-api sim-engine sim-parser sim-rxbuf sim-txbuf sim-secure sim

default: all sim-engine

AES_SRC_PATH = sub/aes/src/rtl
AES_SRC = $(AES_SRC_PATH)/aes_core.v $(AES_SRC_PATH)/aes_decipher_block.v $(AES_SRC_PATH)/aes_encipher_block.v $(AES_SRC_PATH)/aes_inv_sbox.v $(AES_SRC_PATH)/aes_key_mem.v  $(AES_SRC_PATH)/aes_sbox.v
CMAC_SRC = sub/cmac/src/rtl/cmac_core.v $(AES_SRC)
SIV_SRC = sub/aes-siv/src/rtl/aes_siv_core.v $(CMAC_SRC)

ifeq ($(VLINT),)
VLINT=tools/verilator-4.018/bin/verilator
endif

ifeq ($(VLINT_FLAGS),)
VLINT_FLAGS= --lint-only -Wwarn-style -Wno-BLKSEQ -Wno-VARHIDDEN
endif

ifeq ($(VLINT_TESTS_FLAGS),)
VLINT_TESTS_FLAGS= --lint-only
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

lint: lint_src/rtl/nts_engine lint_tb
lint_src/rtl/nts_engine:
	# Memory
	$(VLINT) $(VLINT_FLAGS) src/rtl/memory/bram.v
	$(VLINT) $(VLINT_FLAGS) src/rtl/memory/bram_dpge.v
	$(VLINT) $(VLINT_FLAGS) src/rtl/memory/memory_ctrl.v src/rtl/memory//bram_dpge.v
	# NTS Engine
	$(VLINT) $(VLINT_FLAGS) src/rtl/nts_engine/nts_api.v
	-$(VLINT) $(VLINT_FLAGS) src/rtl/nts_engine/nts_parser_ctrl.v
	$(VLINT) $(VLINT_FLAGS) src/rtl/nts_engine/nts_timestamp.v
	$(VLINT) $(VLINT_FLAGS) src/rtl/nts_engine/nts_rx_buffer.v src/rtl/memory/bram.v
	-$(VLINT) $(VLINT_FLAGS) src/rtl/nts_engine/nts_tx_buffer.v src/rtl/memory/memory_ctrl.v src/rtl/memory/bram_dpge.v
	$(VLINT) $(VLINT_FLAGS) -Wno-UNOPTFLAT src/rtl/nts_engine/nts_verify_secure.v src/rtl/memory/bram_dp2w.v $(SIV_SRC)
	-$(VLINT) $(VLINT_FLAGS) \
 src/rtl/nts_engine/nts_engine.v \
 src/rtl/nts_engine/nts_tx_buffer.v \
 src/rtl/nts_engine/nts_verify_secure.v \
 src/rtl/nts_engine/nts_rx_buffer.v \
 src/rtl/nts_engine/nts_parser_ctrl.v \
 src/rtl/nts_engine/nts_api.v \
 src/rtl/nts_engine/nts_timestamp.v \
 src/rtl/memory/memory_ctrl.v \
 src/rtl/memory/bram.v \
 src/rtl/memory/bram_dpge.v \
 src/rtl/memory/bram_dp2w.v \
 sub/keymem/src/rtl/keymem.v \
 $(SIV_SRC)
	# NTS dispatcher
	$(VLINT) $(VLINT_FLAGS) src/rtl/nts_dispatcher.v src/rtl/memory/bram.v

lint_tb:
	# Memory testbenches
	$(VLINT) $(VLINT_TESTS_FLAGS) -Wno-STMTDLY \
 src/tb/memory/bram_tb.v \
 src/rtl/memory/bram.v
	$(VLINT) $(VLINT_TESTS_FLAGS) -Wno-STMTDLY \
 src/tb/memory/memory_ctrl_tb.v \
 src/rtl/memory/memory_ctrl.v \
 src/rtl/memory/bram_dpge.v
	# NTS Engine testbenches
	$(VLINT) $(VLINT_TESTS_FLAGS) -Wno-STMTDLY \
 src/tb/nts_engine/nts_api_tb.v \
 src/rtl/nts_engine/nts_api.v
	-$(VLINT) $(VLINT_TESTS_FLAGS) -Wno-STMTDLY \
 src/tb/nts_engine/nts_rx_buffer_tb.v \
 src/rtl/nts_engine/nts_rx_buffer.v \
 src/rtl/memory/bram.v
	-$(VLINT) $(VLINT_TESTS_FLAGS) -Wno-STMTDLY \
 src/tb/nts_engine/nts_tx_buffer_tb.v \
 src/rtl/nts_engine/nts_tx_buffer.v \
 src/rtl/memory/memory_ctrl.v \
 src/rtl/memory/bram_dpge.v
	$(VLINT) $(VLINT_TESTS_FLAGS) -Wno-STMTDLY -Wno-UNOPTFLAT \
 src/tb/nts_engine/nts_parser_ctrl_tb.v \
 src/rtl/nts_engine/nts_parser_ctrl.v
	$(VLINT) $(VLINT_TESTS_FLAGS) -Wno-STMTDLY -Wno-UNOPTFLAT \
 src/tb/nts_engine/nts_verify_secure_tb.v \
 src/rtl/nts_engine/nts_verify_secure.v \
 src/rtl/memory/bram_dp2w.v $(SIV_SRC)
	$(VLINT) $(VLINT_TESTS_FLAGS) -Wno-STMTDLY -Wno-UNOPTFLAT \
 src/tb/nts_engine/nts_engine_tb.v \
 src/rtl/nts_engine/nts_engine.v \
 src/rtl/nts_engine/nts_verify_secure.v \
 src/rtl/nts_engine/nts_tx_buffer.v \
 src/rtl/nts_engine/nts_rx_buffer.v \
 src/rtl/nts_engine/nts_parser_ctrl.v \
 src/rtl/nts_engine/nts_api.v \
 src/rtl/nts_engine/nts_timestamp.v \
 src/rtl/memory/memory_ctrl.v \
 src/rtl/memory/bram.v \
 src/rtl/memory/bram_dpge.v \
 src/rtl/memory/bram_dp2w.v \
 sub/keymem/src/rtl/keymem.v \
 $(SIV_SRC)
	#
	$(VLINT) $(VLINT_TESTS_FLAGS) -Wno-STMTDLY src/tb/nts_dispatcher_tb.v src/rtl/nts_dispatcher.v src/rtl/memory/bram.v

lint-submodules:
	make -C sub/aes/toolruns lint
	make -C sub/aes-siv/toolruns lint
	make -C sub/cmac/toolruns lint
	make -C sub/keymem/toolruns lint
	make -C sub/nts_noncegen/toolruns lint
	make -C sub/siphash/toolruns lint

DIRS: output/vvp

VVPS: \
 output/vvp/memory_ctrl_tb.vvp \
 output/vvp/nts_dispatcher_tb.vvp \
 output/vvp/nts_api_tb.vvp \
 output/vvp/nts_timestamp_tb.vvp \
 output/vvp/nts_rx_buffer_tb.vvp \
 output/vvp/nts_tx_buffer_tb.vvp \
 output/vvp/nts_parser_ctrl_tb.vvp \
 output/vvp/nts_verify_secure_tb.vvp \
 output/vvp/nts_engine_tb.vvp
# output/vvp/bram_tb.vvp \

output/vvp:
	mkdir -p $@

output/vvp/memory_ctrl_tb.vvp: \
 src/tb/memory/memory_ctrl_tb.v \
 src/rtl/memory/memory_ctrl.v \
 src/rtl/memory/bram_dpge.v
ifeq (,$(NO_VLINT))
	-$(VLINT) $(VLINT_FLAGS) -Wno-STMTDLY $^
endif
	iverilog -o $@ $^

output/vvp/nts_api_tb.vvp: \
 src/tb/nts_engine/nts_api_tb.v \
 src/rtl/nts_engine/nts_api.v
ifeq (,$(NO_VLINT))
	$(VLINT) $(VLINT_FLAGS) -Wno-STMTDLY $^
endif
	iverilog -o $@ $^

output/vvp/nts_timestamp_tb.vvp: \
 src/tb/nts_engine/nts_timestamp_tb.v \
 src/rtl/nts_engine/nts_timestamp.v
ifeq (,$(NO_VLINT))
	$(VLINT) $(VLINT_FLAGS) -Wno-STMTDLY -Wno-UNOPTFLAT $^
endif
	iverilog -o $@ $^

output/vvp/nts_parser_ctrl_tb.vvp: \
 src/tb/nts_engine/nts_parser_ctrl_tb.v \
 src/rtl/nts_engine/nts_parser_ctrl.v
ifeq (,$(NO_VLINT))
	$(VLINT) $(VLINT_FLAGS) -Wno-STMTDLY -Wno-UNOPTFLAT $^
endif
	iverilog -o $@ $^

output/vvp/nts_rx_buffer_tb.vvp: \
 src/tb/nts_engine/nts_rx_buffer_tb.v \
 src/rtl/nts_engine/nts_rx_buffer.v \
 src/rtl/memory/bram.v
ifeq (,$(NO_VLINT))
	-$(VLINT) $(VLINT_FLAGS) -Wno-STMTDLY $^
endif
	iverilog -o $@ $^

output/vvp/nts_tx_buffer_tb.vvp: \
 src/tb/nts_engine/nts_tx_buffer_tb.v \
 src/rtl/nts_engine/nts_tx_buffer.v \
 src/rtl/memory/memory_ctrl.v \
 src/rtl/memory/bram_dpge.v
ifeq (,$(NO_VLINT))
	-$(VLINT) $(VLINT_FLAGS) -Wno-STMTDLY $^
endif
	iverilog -o $@ $^

output/vvp/nts_verify_secure_tb.vvp: \
 src/tb/nts_engine/nts_verify_secure_tb.v \
 src/rtl/nts_engine/nts_verify_secure.v \
 src/rtl/memory/bram_dp2w.v \
 $(SIV_SRC)
ifeq (,$(NO_VLINT))
	$(VLINT) $(VLINT_FLAGS) -Wno-STMTDLY -Wno-UNOPTFLAT $^
endif
	iverilog -o $@ $^

output/vvp/nts_engine_tb.vvp: \
 src/tb/nts_engine/nts_engine_tb.v \
 src/rtl/nts_engine/nts_engine.v \
 src/rtl/nts_engine/nts_verify_secure.v \
 src/rtl/nts_engine/nts_tx_buffer.v \
 src/rtl/nts_engine/nts_rx_buffer.v \
 src/rtl/nts_engine/nts_parser_ctrl.v \
 src/rtl/nts_engine/nts_api.v \
 src/rtl/nts_engine/nts_timestamp.v \
 src/rtl/memory/memory_ctrl.v \
 src/rtl/memory/bram_dp2w.v \
 src/rtl/memory/bram_dpge.v \
 src/rtl/memory/bram.v \
 sub/keymem/src/rtl/keymem.v $(SIV_SRC)
ifeq (,$(NO_VLINT))
	$(VLINT) $(VLINT_FLAGS) -Wno-STMTDLY -Wno-UNOPTFLAT $^
endif
	iverilog -o $@ $^

output/vvp/nts_dispatcher_tb.vvp: \
 src/tb/nts_dispatcher_tb.v \
 src/rtl/nts_dispatcher.v \
 src/rtl/memory/bram.v
ifeq (,$(NO_VLINT))
	$(VLINT) $(VLINT_FLAGS) -Wno-STMTDLY $^
endif
	iverilog -o $@ $^


#output/vvp/%_tb.vvp: src/tb/%_tb.v src/rtl/nts_engine/%.v
#ifeq (,$(NO_VLINT))
#	$(VLINT) $(VLINT_FLAGS) -Wno-STMTDLY $^
#endif
#	iverilog -o $@ $^
