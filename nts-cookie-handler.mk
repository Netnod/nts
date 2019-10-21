#===================================================================
#
# Makefile
# --------
# Makefile for building the siv_cmac core and
# top level simulation.
#
#
# Author: Joachim Strombergson
#
# Copyright (c) 2019, The Swedish Post and Telecom Authority (PTS)
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
#
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
#
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in
#    the documentation and/or other materials provided with the
#    distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
# FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
# COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
# INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
# BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
# ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
#
#===================================================================



AES_SRC_PATH = sub/aes/src/rtl
AES_SRC = $(AES_SRC_PATH)/aes_core.v $(AES_SRC_PATH)/aes_decipher_block.v $(AES_SRC_PATH)/aes_encipher_block.v $(AES_SRC_PATH)/aes_inv_sbox.v $(AES_SRC_PATH)/aes_key_mem.v  $(AES_SRC_PATH)/aes_sbox.v

CMAC_SRC = sub/cmac/src/rtl/cmac_core.v $(AES_SRC)
TB_CMAC_SRC = sub/cmac/src/tb/tb_cmac_core.v

CORE_SRC = sub/aes-siv/src/rtl/aes_siv_core.v $(CMAC_SRC)
TB_CORE_SRC = sub/aes-siv/src/tb/tb_aes_siv_core.v ../src/tb/tb_core_mem.v

TOP_SRC = sub/aes-siv/src/rtl/aes_siv.v sub/aes-siv/src/tb/tb_core_mem.v $(CORE_SRC)

WRAPPER_SRC = sub/aes-siv/src/util/wrapper_aes_siv_core.v $(CORE_SRC)

CC = iverilog
CC_FLAGS = -Wall

LINT = verilator
LINT_FLAGS = +1364-2001ext+ --lint-only  -Wall -Wno-fatal -Wno-DECLFILENAME

all: lint output/vvp/nts_cookie_handler_tb.vvp
	vvp output/vvp/nts_cookie_handler_tb.vvp

output/vvp/nts_cookie_handler_tb.vvp: tb/nts_cookie_handler_tb.v hdl/nts_cookie_handler.v hdl/bram_with_ack.v $(CORE_SRC)
	iverilog -o $@ $^


lint:  $(CORE_SRC)
	$(LINT) $(LINT_FLAGS) -Wno-UNOPTFLAT $(CORE_SRC)
	$(LINT) $(LINT_FLAGS) hdl/bram_with_ack.v
	$(LINT) $(LINT_FLAGS) -Wno-UNOPTFLAT hdl/nts_cookie_handler.v hdl/bram_with_ack.v $(CORE_SRC)
	$(LINT) $(LINT_FLAGS) -Wno-UNOPTFLAT -Wno-STMTDLY tb/nts_cookie_handler_tb.v hdl/nts_cookie_handler.v hdl/bram_with_ack.v $(CORE_SRC)
