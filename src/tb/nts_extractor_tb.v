//======================================================================
//
// nts_extractor_tb.v
// ------------------
// Testbench for the NTS packet extractor.
//
// Author: Peter Magnusson
//
//
//
// Copyright 2019 Netnod Internet Exchange i Sverige AB
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions
// are met:
//
// 1. Redistributions of source code must retain the above copyright
//    notice, this list of conditions and the following disclaimer.
//
// 2. Redistributions in binary form must reproduce the above copyright
//    notice, this list of conditions and the following disclaimer in
//    the documentation and/or other materials provided with the
//    distribution.
//
// 3. Neither the name of the copyright holder nor the names of its
//    contributors may be used to endorse or promote products derived
//    from this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
// "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
// LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
// FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
// COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
// INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
// BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
// LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
// CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
// LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
// ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
// POSSIBILITY OF SUCH DAMAGE.
//
//======================================================================

module nts_extractor_tb;
  integer test_success;
  integer test_fail;

  //----------------------------------------------------------------
  // network_path_shared.v swap bytes function
  //----------------------------------------------------------------

  function [63:0] mac_swap_bytes;
    input [63:0] data;
    input [7:0]  mask;
    begin
      mac_swap_bytes[ 0+:8] = data[56+:8] & {8{mask[7]}};
      mac_swap_bytes[ 8+:8] = data[48+:8] & {8{mask[6]}};
      mac_swap_bytes[16+:8] = data[40+:8] & {8{mask[5]}};
      mac_swap_bytes[24+:8] = data[32+:8] & {8{mask[4]}};
      mac_swap_bytes[32+:8] = data[24+:8] & {8{mask[3]}};
      mac_swap_bytes[40+:8] = data[16+:8] & {8{mask[2]}};
      mac_swap_bytes[48+:8] = data[ 8+:8] & {8{mask[1]}};
      mac_swap_bytes[56+:8] = data[ 0+:8] & {8{mask[0]}};
    end
  endfunction

  //----------------------------------------------------------------
  // nts_extractor.v swap bytes function
  //----------------------------------------------------------------

  function [63:0] mac_byte_txreverse( input [63:0] txd, input [7:0] txv );
  begin : txreverse
    reg [63:0] out;
    out[0+:8]  = txv[0] ? txd[56+:8] : 8'h00;
    out[8+:8]  = txv[1] ? txd[48+:8] : 8'h00;
    out[16+:8] = txv[2] ? txd[40+:8] : 8'h00;
    out[24+:8] = txv[3] ? txd[32+:8] : 8'h00;
    out[32+:8] = txv[4] ? txd[24+:8] : 8'h00;
    out[40+:8] = txv[5] ? txd[16+:8] : 8'h00;
    out[48+:8] = txv[6] ? txd[8+:8]  : 8'h00;
    out[56+:8] = txv[7] ? txd[0+:8]  : 8'h00;
    mac_byte_txreverse = out;
  end
  endfunction

  `define assert(condition) if(!(condition)) begin $display("ASSERT FAILED: %s %d %s", `__FILE__, `__LINE__, `"condition`"); $finish(1); end

  `define test(condition) if((condition)) begin test_success = test_success + 1; end else begin test_fail = test_fail + 1; $display("WARNING TEST FAILED: %s %d %s", `__FILE__, `__LINE__, `"condition`"); end


  //----------------------------------------------------------------
  // test_swap_bytes_equiv
  // * Implementations are only equivalent for 8'hff and 8'h00.
  // * mac_swap_bytes is used with 8'hff in network path shared
  //                  for TX order.
  // * mac_swap_bytes is primarily intended for RX order swap.
  // * mac_byte_txreverse is intended for TX order swap.
  //----------------------------------------------------------------

  task test_swap_bytes_equiv;
  begin : test_swap_bytes_equiv
    reg [63:0] data;
    reg [63:0] v1;
    reg [63:0] v2;
    reg [7:0] mask;
    integer i;
    mask = 0;
    data = 64'h5d41_402a_bc4b_2a76;
    v1 = mac_swap_bytes(data, mask);
    v2 = mac_byte_txreverse(data, mask);
    //$display("%s:%0d mask:%b %h %h", `__FILE__, `__LINE__, mask, v1, v2);
    `test(v1 === v2);
    for (i = 0; i < 8; i = i + 1) begin
      mask[i[2:0]] = 1;
      v1 = mac_swap_bytes(data, mask);
      v2 = mac_byte_txreverse(data, mask);
      //$display("%s:%0d mask:%b %h %h", `__FILE__, `__LINE__, mask, v1, v2);
      if (mask === 8'hff) begin
        //network path uses mac_swap_bytes(pp_mactx_data, 8'hff), so must be equivalent
        `test(v1 === v2);
      end
    end
  end
  endtask

  initial begin
    $display("%s:%0d Test start", `__FILE__, `__LINE__);
    test_success = 0;
    test_fail = 0;

    test_swap_bytes_equiv();

    $display("%s:%0d Test stop. Sucess: %0d, failure: %0d.", `__FILE__, `__LINE__, test_success, test_fail);
    $finish;
  end
endmodule
