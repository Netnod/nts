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

.PHONY: DIRS VVP clean default all verilator \
 lint lint_rtl lint_memory lint_engine lint_dispatcher lint_top int_tb lint-submodules \
 sim-api sim-engine sim-parser sim-rxbuf sim-txbuf sim-secure sim

AES_SRC_PATH = ../sub/aes/src/rtl
AES_SRC = $(AES_SRC_PATH)/aes_core.v $(AES_SRC_PATH)/aes_decipher_block.v $(AES_SRC_PATH)/aes_encipher_block.v $(AES_SRC_PATH)/aes_inv_sbox.v $(AES_SRC_PATH)/aes_key_mem.v  $(AES_SRC_PATH)/aes_sbox.v
CMAC_SRC = ../sub/cmac/src/rtl/cmac_core.v $(AES_SRC)
SIV_SRC = ../sub/aes-siv/src/rtl/aes_siv_core.v $(CMAC_SRC)
KEYMEM_SRC = ../sub/keymem/src/rtl/nts_keymem.v
ENGINE_SRC = ../src/rtl/nts_engine/nts_engine.v \
 ../src/rtl/nts_engine/nts_verify_secure.v \
 ../src/rtl/nts_engine/nts_tx_buffer.v \
 ../src/rtl/nts_engine/nts_rx_buffer.v \
 ../src/rtl/nts_engine/nts_parser_ctrl.v \
 ../src/rtl/nts_engine/nts_api.v \
 ../src/rtl/nts_engine/nts_timestamp.v \
 ../src/rtl/memory/memory_ctrl.v \
 ../src/rtl/memory/bram.v \
 ../src/rtl/memory/bram_dpge.v \
 ../src/rtl/memory/bram_dp2w.v \
 $(KEYMEM_SRC) \
 $(SIV_SRC)

OUTPUT = ../output/vvp

ifeq ($(VLINT),)
VLINT=verilator-4.018/bin/verilator
endif

ifeq ($(VLINT_FLAGS),)
VLINT_FLAGS= --lint-only -Wwarn-style -Wno-BLKSEQ -Wno-VARHIDDEN
endif

ifeq ($(VLINT_TESTS_FLAGS),)
VLINT_TESTS_FLAGS= --lint-only
endif

default: DIRS sim-top

all: DIRS VVPS

DIRS: $(OUTPUT)

$(OUTPUT):
	mkdir -p $@

sim-api: $(OUTPUT)/nts_api_tb.vvp
	vvp $^

sim-engine: $(OUTPUT)/nts_engine_tb.vvp
	vvp $^

sim-dispatcher: $(OUTPUT)/nts_dispatcher_tb.vvp
	vvp $^

sim-parser: $(OUTPUT)/nts_parser_ctrl_tb.vvp
	vvp $^

sim-rxbuf: $(OUTPUT)/nts_rx_buffer_tb.vvp
	vvp $^

sim-top: $(OUTPUT)/nts_top_tb.vvp
	vvp $^

sim-txbuf: $(OUTPUT)/nts_tx_buffer_tb.vvp
	vvp $^

sim-secure: $(OUTPUT)/nts_verify_secure_tb.vvp
	vvp $^


sim: sim-api sim-engine sim-parser sim-rxbuf sim-secure sim-txbuf

clean:
	rm -rf $(OUTPUT)

lint: lint_rtl lint_tb

lint_rtl: lint_memory lint_top lint_engine lint_dispatcher lint_top

lint_memory:
	$(VLINT) $(VLINT_FLAGS) ../src/rtl/memory/bram.v
	$(VLINT) $(VLINT_FLAGS) ../src/rtl/memory/bram_dpge.v
	$(VLINT) $(VLINT_FLAGS) ../src/rtl/memory/memory_ctrl.v src/rtl/memory/bram_dpge.v

lint_engine:
	$(VLINT) $(VLINT_FLAGS) ../src/rtl/nts_engine/nts_api.v
	-$(VLINT) $(VLINT_FLAGS) ../src/rtl/nts_engine/nts_parser_ctrl.v
	$(VLINT) $(VLINT_FLAGS) ../src/rtl/nts_engine/nts_timestamp.v
	$(VLINT) $(VLINT_FLAGS) ../src/rtl/nts_engine/nts_rx_buffer.v src/rtl/memory/bram.v
	-$(VLINT) $(VLINT_FLAGS) ../src/rtl/nts_engine/nts_tx_buffer.v src/rtl/memory/memory_ctrl.v src/rtl/memory/bram_dpge.v
	$(VLINT) $(VLINT_FLAGS) -Wno-UNOPTFLAT ../src/rtl/nts_engine/nts_verify_secure.v ../src/rtl/memory/bram_dp2w.v $(SIV_SRC)
	-$(VLINT) $(VLINT_FLAGS) \
 ../src/rtl/nts_engine/nts_engine.v \
 ../src/rtl/nts_engine/nts_tx_buffer.v \
 ../src/rtl/nts_engine/nts_verify_secure.v \
 ../src/rtl/nts_engine/nts_rx_buffer.v \
 ../src/rtl/nts_engine/nts_parser_ctrl.v \
 ../src/rtl/nts_engine/nts_api.v \
 ../src/rtl/nts_engine/nts_timestamp.v \
 ../src/rtl/memory/memory_ctrl.v \
 ../src/rtl/memory/bram.v \
 ../src/rtl/memory/bram_dpge.v \
 ../src/rtl/memory/bram_dp2w.v \
 ../sub/keymem/src/rtl/nts_keymem.v \
 $(SRC_KEYMEM) \
 $(SIV_SRC)

lint_dispatcher:
	$(VLINT) $(VLINT_FLAGS) ../src/rtl/nts_dispatcher.v ../src/rtl/memory/bram.v

lint_top:
	$(VLINT) $(VLINT_FLAGS) -Wno-UNOPTFLAT ../src/rtl/nts_top.v ../src/rtl/nts_dispatcher.v $(ENGINE_SRC)

lint_tb:
	# Memory testbenches
	$(VLINT) $(VLINT_TESTS_FLAGS) -Wno-STMTDLY \
 ../src/tb/memory/bram_tb.v \
 ../src/rtl/memory/bram.v
	$(VLINT) $(VLINT_TESTS_FLAGS) -Wno-STMTDLY \
 ../src/tb/memory/memory_ctrl_tb.v \
 ../src/rtl/memory/memory_ctrl.v \
 ../src/rtl/memory/bram_dpge.v
	# NTS Engine testbenches
	$(VLINT) $(VLINT_TESTS_FLAGS) -Wno-STMTDLY \
 ../src/tb/nts_engine/nts_api_tb.v \
 ../src/rtl/nts_engine/nts_api.v
	-$(VLINT) $(VLINT_TESTS_FLAGS) -Wno-STMTDLY \
 ../src/tb/nts_engine/nts_rx_buffer_tb.v \
 ../src/rtl/nts_engine/nts_rx_buffer.v \
 ../src/rtl/memory/bram.v
	-$(VLINT) $(VLINT_TESTS_FLAGS) -Wno-STMTDLY \
 ../src/tb/nts_engine/nts_tx_buffer_tb.v \
 ../src/rtl/nts_engine/nts_tx_buffer.v \
 ../src/rtl/memory/memory_ctrl.v \
 ../src/rtl/memory/bram_dpge.v
	$(VLINT) $(VLINT_TESTS_FLAGS) -Wno-STMTDLY -Wno-UNOPTFLAT \
 ../src/tb/nts_engine/nts_parser_ctrl_tb.v \
 ../src/rtl/nts_engine/nts_parser_ctrl.v
	$(VLINT) $(VLINT_TESTS_FLAGS) -Wno-STMTDLY -Wno-UNOPTFLAT \
 ../src/tb/nts_engine/nts_verify_secure_tb.v \
 ../src/rtl/nts_engine/nts_verify_secure.v \
 ../src/rtl/memory/bram_dp2w.v $(SIV_SRC)
	$(VLINT) $(VLINT_TESTS_FLAGS) -Wno-STMTDLY -Wno-UNOPTFLAT \
 ../src/tb/nts_engine/nts_engine_tb.v $(ENGINE_SRC)
	#
	$(VLINT) $(VLINT_TESTS_FLAGS) -Wno-STMTDLY src/tb/nts_dispatcher_tb.v src/rtl/nts_dispatcher.v src/rtl/memory/bram.v

lint-submodules:
	make -C sub/aes/toolruns lint
	make -C sub/aes-siv/toolruns lint
	make -C sub/cmac/toolruns lint
	make -C sub/keymem/toolruns lint
	make -C sub/nts_noncegen/toolruns lint
	make -C sub/siphash/toolruns lint

VVPS: \
 $(OUTPUT)/memory_ctrl_tb.vvp \
 $(OUTPUT)/nts_dispatcher_tb.vvp \
 $(OUTPUT)/nts_api_tb.vvp \
 $(OUTPUT)/nts_timestamp_tb.vvp \
 $(OUTPUT)/nts_rx_buffer_tb.vvp \
 $(OUTPUT)/nts_tx_buffer_tb.vvp \
 $(OUTPUT)/nts_parser_ctrl_tb.vvp \
 $(OUTPUT)/nts_verify_secure_tb.vvp \
 $(OUTPUT)/vvp/nts_engine_tb.vvp

$(OUTPUT)/memory_ctrl_tb.vvp: \
 ../src/tb/memory/memory_ctrl_tb.v \
 ../src/rtl/memory/memory_ctrl.v \
 ../src/rtl/memory/bram_dpge.v
ifeq (,$(NO_VLINT))
	-$(VLINT) $(VLINT_FLAGS) -Wno-STMTDLY $^
endif
	iverilog -o $@ $^

$(OUTPUT)/nts_api_tb.vvp: \
 ../src/tb/nts_engine/nts_api_tb.v \
 ../src/rtl/nts_engine/nts_api.v
ifeq (,$(NO_VLINT))
	$(VLINT) $(VLINT_FLAGS) -Wno-STMTDLY $^
endif
	iverilog -o $@ $^

$(OUTPUT)/nts_timestamp_tb.vvp: \
 ../src/tb/nts_engine/nts_timestamp_tb.v \
 ../src/rtl/nts_engine/nts_timestamp.v
ifeq (,$(NO_VLINT))
	$(VLINT) $(VLINT_FLAGS) -Wno-STMTDLY -Wno-UNOPTFLAT $^
endif
	iverilog -o $@ $^

$(OUTPUT)/nts_parser_ctrl_tb.vvp: \
 ../src/tb/nts_engine/nts_parser_ctrl_tb.v \
 ../src/rtl/nts_engine/nts_parser_ctrl.v
ifeq (,$(NO_VLINT))
	$(VLINT) $(VLINT_FLAGS) -Wno-STMTDLY -Wno-UNOPTFLAT $^
endif
	iverilog -o $@ $^

$(OUTPUT)/nts_rx_buffer_tb.vvp: \
 ../src/tb/nts_engine/nts_rx_buffer_tb.v \
 ../src/rtl/nts_engine/nts_rx_buffer.v \
 ../src/rtl/memory/bram.v
ifeq (,$(NO_VLINT))
	-$(VLINT) $(VLINT_FLAGS) -Wno-STMTDLY $^
endif
	iverilog -o $@ $^

$(OUTPUT)/nts_tx_buffer_tb.vvp: \
 ../src/tb/nts_engine/nts_tx_buffer_tb.v \
 ../src/rtl/nts_engine/nts_tx_buffer.v \
 ../src/rtl/memory/memory_ctrl.v \
 ../src/rtl/memory/bram_dpge.v
ifeq (,$(NO_VLINT))
	-$(VLINT) $(VLINT_FLAGS) -Wno-STMTDLY $^
endif
	iverilog -o $@ $^

$(OUTPUT)/nts_verify_secure_tb.vvp: \
 ../src/tb/nts_engine/nts_verify_secure_tb.v \
 ../src/rtl/nts_engine/nts_verify_secure.v \
 ../src/rtl/memory/bram_dp2w.v \
 $(SIV_SRC)
ifeq (,$(NO_VLINT))
	$(VLINT) $(VLINT_FLAGS) -Wno-STMTDLY -Wno-UNOPTFLAT $^
endif
	iverilog -o $@ $^

$(OUTPUT)/nts_engine_tb.vvp: \
 ../src/tb/nts_engine/nts_engine_tb.v \
 $(ENGINE_SRC)
ifeq (,$(NO_VLINT))
	$(VLINT) $(VLINT_FLAGS) -Wno-STMTDLY -Wno-UNOPTFLAT $^
endif
	iverilog -o $@ $^

$(OUTPUT)/nts_dispatcher_tb.vvp: \
 ../src/tb/nts_dispatcher_tb.v \
 ../src/rtl/nts_dispatcher.v \
 ../src/rtl/memory/bram.v
ifeq (,$(NO_VLINT))
	$(VLINT) $(VLINT_FLAGS) -Wno-STMTDLY $^
endif
	iverilog -o $@ $^

$(OUTPUT)/nts_top_tb.vvp: \
 ../src/tb/nts_top_tb.v \
 ../src/rtl/nts_top.v \
 ../src/rtl/nts_dispatcher.v \
 ../src/rtl/memory/bram.v \
 $(ENGINE_SRC)
ifeq (,$(NO_VLINT))
	$(VLINT) $(VLINT_FLAGS) -Wno-STMTDLY -Wno-UNOPTFLAT $^
endif
	iverilog -o $@ $^
