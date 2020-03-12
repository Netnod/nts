//
// Copyright (c) 2016-2019, The Swedish Post and Telecom Authority (PTS)
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//
// 1. Redistributions of source code must retain the above copyright notice, this
//    list of conditions and the following disclaimer.
//
// 2. Redistributions in binary form must reproduce the above copyright notice,
//    this list of conditions and the following disclaimer in the documentation
//    and/or other materials provided with the distribution.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
// FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
// DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
// SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
// CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
// OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//

//
// Author: Peter Magnusson, Assured AB
//

module nts_engine_tb #( parameter integer verbose_output = 'h3);

  //----------------------------------------------------------------
  // Test bench constants
  //----------------------------------------------------------------

  localparam        ADDR_WIDTH                  = 7;

  localparam [31:0] NTS_TESTKEY0                = 32'h2b3076b5;
  localparam [31:0] NTS_TESTKEY1                = 32'h2b30d49a;

  localparam [11:0] API_ADDR_ENGINE_BASE        = 12'h000;
  localparam [11:0] API_ADDR_ENGINE_NAME0       = API_ADDR_ENGINE_BASE;
  localparam [11:0] API_ADDR_ENGINE_NAME1       = API_ADDR_ENGINE_BASE + 1;
  localparam [11:0] API_ADDR_ENGINE_VERSION     = API_ADDR_ENGINE_BASE + 2;
  localparam [11:0] API_ADDR_ENGINE_CTRL        = API_ADDR_ENGINE_BASE + 8;

  localparam [11:0] API_ADDR_NONCEGEN_BASE     = 12'h020;
  localparam [11:0] API_ADDR_NONCEGEN_CTRL     = API_ADDR_NONCEGEN_BASE + 'h08;
  localparam [11:0] API_ADDR_NONCEGEN_KEY0     = API_ADDR_NONCEGEN_BASE + 'h10;
  localparam [11:0] API_ADDR_NONCEGEN_KEY1     = API_ADDR_NONCEGEN_BASE + 'h11;
  localparam [11:0] API_ADDR_NONCEGEN_KEY2     = API_ADDR_NONCEGEN_BASE + 'h12;
  localparam [11:0] API_ADDR_NONCEGEN_KEY3     = API_ADDR_NONCEGEN_BASE + 'h13;
  localparam [11:0] API_ADDR_NONCEGEN_LABEL    = API_ADDR_NONCEGEN_BASE + 'h20;
  localparam [11:0] API_ADDR_NONCEGEN_CONTEXT0 = API_ADDR_NONCEGEN_BASE + 'h40;
  localparam [11:0] API_ADDR_NONCEGEN_CONTEXT1 = API_ADDR_NONCEGEN_BASE + 'h41;
  localparam [11:0] API_ADDR_NONCEGEN_CONTEXT2 = API_ADDR_NONCEGEN_BASE + 'h42;
  localparam [11:0] API_ADDR_NONCEGEN_CONTEXT3 = API_ADDR_NONCEGEN_BASE + 'h43;
  localparam [11:0] API_ADDR_NONCEGEN_CONTEXT4 = API_ADDR_NONCEGEN_BASE + 'h44;
  localparam [11:0] API_ADDR_NONCEGEN_CONTEXT5 = API_ADDR_NONCEGEN_BASE + 'h45;

  localparam [11:0] API_ADDR_DEBUG_BASE         = 12'h180;
  localparam [11:0] API_ADDR_DEBUG_ERR_CRYPTO   = API_ADDR_DEBUG_BASE + 'h20;
  localparam [11:0] API_ADDR_DEBUG_ERR_TXBUF    = API_ADDR_DEBUG_BASE + 'h22;

  localparam [11:0] API_ADDR_CLOCK_BASE         = 12'h010;
  localparam [11:0] API_ADDR_CLOCK_NAME0        = API_ADDR_CLOCK_BASE + 0;
  localparam [11:0] API_ADDR_CLOCK_NAME1        = API_ADDR_CLOCK_BASE + 1;

  localparam [11:0] API_ADDR_KEYMEM_BASE        = 12'h080;
  localparam [11:0] API_ADDR_KEYMEM_NAME0       = API_ADDR_KEYMEM_BASE + 0;
  localparam [11:0] API_ADDR_KEYMEM_NAME1       = API_ADDR_KEYMEM_BASE + 1;
  localparam [11:0] API_ADDR_KEYMEM_ADDR_CTRL   = API_ADDR_KEYMEM_BASE + 12'h08;
  localparam [11:0] API_ADDR_KEYMEM_KEY0_ID     = API_ADDR_KEYMEM_BASE + 12'h10;
  localparam [11:0] API_ADDR_KEYMEM_KEY0_START  = API_ADDR_KEYMEM_BASE + 12'h40;
  localparam [11:0] API_ADDR_KEYMEM_KEY0_END    = API_ADDR_KEYMEM_BASE + 12'h4f;
  localparam [11:0] API_ADDR_KEYMEM_KEY1_ID     = API_ADDR_KEYMEM_BASE + 12'h12;
  localparam [11:0] API_ADDR_KEYMEM_KEY1_START  = API_ADDR_KEYMEM_BASE + 12'h50;
  localparam [11:0] API_ADDR_KEYMEM_KEY1_END    = API_ADDR_KEYMEM_BASE + 12'h5f;
  localparam [11:0] API_ADDR_KEYMEM_KEY2_ID     = API_ADDR_KEYMEM_BASE + 12'h14;
  localparam [11:0] API_ADDR_KEYMEM_KEY2_START  = API_ADDR_KEYMEM_BASE + 12'h60;
  localparam [11:0] API_ADDR_KEYMEM_KEY2_END    = API_ADDR_KEYMEM_BASE + 12'h6f;
  localparam [11:0] API_ADDR_KEYMEM_KEY3_ID     = API_ADDR_KEYMEM_BASE + 12'h16;
  localparam [11:0] API_ADDR_KEYMEM_KEY3_START  = API_ADDR_KEYMEM_BASE + 12'h70;
  localparam [11:0] API_ADDR_KEYMEM_KEY3_END    = API_ADDR_KEYMEM_BASE + 12'h7f;


  localparam integer ETHIPV4_NTS_TESTPACKETS_BITS=5488;
  localparam integer ETHIPV6_NTS_TESTPACKETS_BITS=5648;


  localparam  [719:0] ntp_legacy_packet = { 64'h2c768aadf786902b, 64'h3431273408004500, 64'h004c000040004011, 64'h1573c0a80101a0b1, 64'hc2d30abc007b0038, 64'h453e23000a001215, 64'h3524bbbbbbbb0000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h00000123456789ab, 16'hcdef };

  localparam [5487:0] nts_packet_ipv4_response1 = { 64'hfe5400a6ab8d5254, 64'h00ab4ff908004500, 64'h02a0558c40004011, 64'h6d46c0a87a28c0a8, 64'h7a01007bb562028c, 64'h7818240400e60000, 64'h0c8a000000391f0e, 64'h83bce10908460b93, 64'h9a21e3f82e7eb74a, 64'h9f6ae10909b47081, 64'h1a35e10909b47088, 64'h333a01040024c186, 64'h0fbe6268f9374950, 64'h5a7ba4b50307df91, 64'hfe02f08b1146a062, 64'he1f87880fa540404, 64'h0230001002183e83, 64'h0616b8fead9a5d2c, 64'h0c2d3ca182a5e96c, 64'h62a5effa54f553f7, 64'h23886ce066068f91, 64'hcae6b73290b62ab2, 64'hd81a8ff06de30cef, 64'h9b4ba0efb47f600a, 64'h922647bd7f7f8838, 64'h07f4ca4d61fc285a, 64'h868ab7f071187a2f, 64'h3fcc4fd13dbc2e18, 64'hcb8986453f357c3c, 64'h9270aa21e668dbd3, 64'h3f8232200e753c11, 64'he63895c5b61f3c1f, 64'h123906d7442f94bc, 64'h6ea991a2d73a6766, 64'hb16e160ecc30c3a4, 64'hdda45c2af6a165dd, 64'h76bd40e6bb51491d, 64'h63ff0f78e115200f, 64'h1042baba7c4965fe, 64'h204d685c550718ad, 64'hf4dc2ce9679a75ae, 64'haf5cd5ab286bf95d, 64'h56b3d798b92b1fd5, 64'h90285ed5a82df100, 64'hc67036e9f819ac28, 64'h3e10d57331de9a4e, 64'hda1103b0657077b8, 64'hb619f4433a9871b8, 64'hbdd63960eecf3902, 64'h81d3dac87677c215, 64'h4e354268c905e17e, 64'he897eddc99653708, 64'h88935b411a8da4ef, 64'hefb7d075b83c01f8, 64'h6e2a14d53ad01df9, 64'hab831ca751ea9f55, 64'h3706bbe026f35044, 64'h9761095a14e3a33d, 64'h9c717e6c53c66154, 64'h219dca89eb17c9aa, 64'he32331cc2a1c0fca, 64'h66462a379bcb0717, 64'hf9c3640829342a1e, 64'hf5340b79a1c9291d, 64'h60d92f3fe60f98a7, 64'ha23da91a3774c6a5, 64'h172565f547391daa, 64'he45a49e46e04f7e5, 64'h53d30660cb79a9b1, 64'ha86fef58230a5e37, 64'h6e290ac55f516a3d, 64'h4d5dbbb16a2e14c4, 64'h70b339292bc7b972, 64'h0d982132a71d57d4, 64'ha8c313fbdbe1f02a, 64'hf2d9454eb0048865, 64'h8c91ff388287f7df, 64'h809e8ca6aea664e5, 64'h39d4ae129bcb1bfa, 64'h6a150b4f44875be3, 64'h149f94258cc0eaad, 64'h1da92a64c3bb4faf, 64'h06302113076e3443, 64'h9f326416d51040a2, 64'h33ff5138d8c1a283, 48'hc719450556f7 };

  localparam [ETHIPV4_NTS_TESTPACKETS_BITS-1:0] nts_packet_ipv4_response2 = { 64'hfe5400a6ab8d5254, 64'h00ab4ff908004500, 64'h02a0a9c840004011, 64'h190ac0a87a28c0a8, 64'h7a01007ba24e028c, 64'h7818240400e60000, 64'h0c8a000000401f0e, 64'h83bce10908460b93, 64'h9a21356fa54c089a, 64'h143ce1090a11f0a1, 64'h4fd8e1090a11f0ab, 64'hbeb801040024dde4, 64'hdbeb1963d1a5fcf2, 64'h9256daba4a9917e0, 64'hbaa8e51a7401366b, 64'h75e18512dead0404, 64'h02300010021834c8, 64'h39711a027c8a68b7, 64'hdc3cfd9df233bbfd, 64'h21d4c4b8b8340de3, 64'h02bcd638ead234e9, 64'h81e43ebfaacded9d, 64'he30356ba353de5dd, 64'h10f9b4b59ff9da3e, 64'h4a9cd7a4a341322c, 64'h6dd38fca610ee799, 64'hd372b44767ce4147, 64'hf635786e76bbb9ae, 64'hd475299ba5c894db, 64'h21319392776ed78a, 64'h8121a4eb1c4ca6cc, 64'h74112c820478e8cc, 64'h97538d22e02d5eaf, 64'h23ea33b0d0f0e6c7, 64'h5b2b718f82bb07a4, 64'h763da21c6ed93e07, 64'h10b05c53dc1f372c, 64'h123af5a06884d6e0, 64'hf0a433d6c0876556, 64'hcf7294d7846cd34d, 64'h1136546f81f972c2, 64'h8a29ca55df766bb0, 64'h80fca38aa2128abe, 64'h7b59964c88fe75ae, 64'ha12f927220086540, 64'h6d4a70b5baa07e18, 64'h5014199b499eb9b0, 64'h305b3f85bf9eed00, 64'h4891c494b2732b3f, 64'hcbb67f867962c5cc, 64'h29ea1624d44e6a3a, 64'h474358d27860c73c, 64'he45a13bb8d3cefc3, 64'h8d1403187efbd782, 64'h231613181ee48c90, 64'h29eda2d7779fd7bd, 64'hac2bdd262fe9c73f, 64'h5d0530b859048dc8, 64'hd71d6d56623e7b05, 64'h84e4b3b134055460, 64'h0e4caa795ded6ef2, 64'h1d8c36eb495cefc0, 64'h7d2e4696dfa5d8f2, 64'h50ad96aa82126f5d, 64'hc18fb9fa36d7d001, 64'he1a6ec4fc5859b30, 64'hda8b425ae761b4aa, 64'h791096a8bf33a3f3, 64'h37ded08d578e4bfb, 64'h846a6546381e3bda, 64'hb5c181f3b6e7cf2c, 64'hbbfbc97427b81dee, 64'ha6c0f6f4aed1b803, 64'h4eda786f1a410233, 64'hbd8a688add4bf752, 64'h1a7b4881bf6d334f, 64'h42e0e0915de39919, 64'h494c551fc6bb8071, 64'h1bfc48a9de20a17e, 64'he5941ff57639b6f3, 64'h79de52181507dbdd, 64'ha82682aee21d98a0, 64'ha079bc635a8bd1aa, 64'h5a731d2479bbe12c, 64'hf9040b8872fdf4ad, 48'hf996410bcfd8 };

  localparam [ETHIPV4_NTS_TESTPACKETS_BITS-1:0] nts_packet_ipv4_response3 = { 64'hfe5400a6ab8d5254, 64'h00ab4ff908004500, 64'h02a0ae0b40004011, 64'h14c7c0a87a28c0a8, 64'h7a01007b98a5028c, 64'h7818240400e60000, 64'h0c8a000000411f0e, 64'h83bce10908460b93, 64'h9a21eb71fb26d69a, 64'h6444e1090a1cdfae, 64'h5739e1090a1cdfb9, 64'hf04601040024c477, 64'h9861c58286f503cb, 64'hd910354b85038e4a, 64'h3bb7826b00aabfc1, 64'h5bf45b2b43400404, 64'h023000100218867a, 64'h39b5645c96a8b43d, 64'hd6b8a7985a13b5b5, 64'h61ee989d5fbd4052, 64'h4ef919ef8b0d5392, 64'ha0b54f40fd7f15db, 64'hb63de0cc4ec04958, 64'h039712565f037384, 64'h3a0b7f8b26a9779f, 64'h62dab2c8abceeea0, 64'h3858aaf4c4dbe8cc, 64'ha058f6c7998a9bf2, 64'hb7139d619bef9457, 64'h6f12373deb195937, 64'hf79ca4df668bb8b0, 64'hce5c3f20a7620d82, 64'h03bc6459a8321bdc, 64'h793d5c1dc7c74abe, 64'h0ead5f9fc5326eab, 64'h1df3b5a04c537aee, 64'he94a30a465cab94e, 64'h0dae2812a446cb35, 64'h67eeb9a9ae4ffed9, 64'hf8e2f4823c3eb5c6, 64'h685197cbf4163176, 64'hc01e1ed7213f978b, 64'h1a6de7f45712714d, 64'h5aae104d684242fb, 64'hcb00f95538c6f4c3, 64'hed4ea8293b64c443, 64'hdb454132ea307c24, 64'hde979a78b5bba1b5, 64'hacec4ecdf2e41ea6, 64'h62ce47d8a62a301d, 64'hd4f4fdfbc2d74b46, 64'ha0e47f5217d070c3, 64'h2317b4ccb10c3d21, 64'h900ecdd81764aaab, 64'ha83e6d736c4df61f, 64'h03f77d5f3752f7ed, 64'hdf69daeb623fcb3a, 64'hd1b340e7f0b8e67e, 64'h2aac50f424ad6ac2, 64'h4b67300fd2384493, 64'hc96d9c0bea0b4445, 64'h8778a6aab9c73223, 64'h3c71e27fdbb4da56, 64'h23dec7d475b5e440, 64'h2074556071a48692, 64'h10b459bda7feb809, 64'h7d50bbf070363c1d, 64'hda5029b8558700b6, 64'hb57101215eae3677, 64'ha81d2f450dbb1178, 64'h78a4010b8fd0143c, 64'h98baabb41ed3a11d, 64'h2cfa0e4a8f79ca7a, 64'h36c0b283be945262, 64'h91dbce3c06414f1b, 64'hd2111a5e952683a2, 64'hb99359f0bae1ab27, 64'h40b8c65e5b0e1e80, 64'had50dc4215a6fbe8, 64'hbef43ca4114d3362, 64'h35bc7fd46cc1ee29, 64'h50a732dc8d4e3448, 64'hdb0ab8edd1ac1fa6, 64'ha5b7e0b3fa9bfc43, 64'hc52dfb342716d1a4, 48'he4e1590e0225 };

  localparam [ETHIPV4_NTS_TESTPACKETS_BITS-1:0] nts_packet_ipv4_response4 = { 64'hfe5400a6ab8d5254, 64'h00ab4ff908004500, 64'h02a0af1140004011, 64'h13c1c0a87a28c0a8, 64'h7a01007bb673028c, 64'h7818240400e60000, 64'h0c8a000000411f0e, 64'h83bce10908460b93, 64'h9a210caa0df97388, 64'h0014e1090a23473e, 64'h79d6e1090a234745, 64'hd670010400247876, 64'h7a8dcc0bed79d3f9, 64'h15e7a1687462bdf2, 64'h4551a72b8811f4f0, 64'hfff60a3f5f3a0404, 64'h0230001002184c98, 64'h841d4c4d6650413e, 64'h7e6ef3c02a95158c, 64'h0ca6c0697eeda65d, 64'hc43b2010d501be10, 64'hb7885861057daa1f, 64'h9846198e2c11859e, 64'h866b46cddd1b8d0b, 64'hf9bc6f8f73a90738, 64'h945544c7a2d2669a, 64'h57358ab0087dde93, 64'hc5c847fb0e79541e, 64'hc4478eb0d5debe06, 64'h8ac4658057b92a8d, 64'h72b6261555250a80, 64'hd105e7c74ecfdc35, 64'h5c7293b31b2b2870, 64'h36fd2d996d596c38, 64'h18ee16f05c99f2a2, 64'h0e45407c0f3c41d9, 64'hb66df99fbe66d55a, 64'h1ae2e29e65e07049, 64'hfa815c28caf9386f, 64'h60b027da6144de90, 64'h776ffe871328cf73, 64'h736686d6174e9b93, 64'h6a55a02306669324, 64'hac32815ac873ac09, 64'h2e5660dfec376fab, 64'h6022f75c9522a73a, 64'h1d09b2851f1a299a, 64'hcf1277f1cfd0a08c, 64'h8156dd8371978808, 64'hb10f8b9d61e84293, 64'h5e91439e49b9996e, 64'h35e6afeb90f4864b, 64'h7928370f80e027e6, 64'h4f571594f9135bed, 64'hdeb870fd1917db87, 64'hb1bf664e3e0a4709, 64'h92c6332942b3f11f, 64'h63ea4c2078090c78, 64'hc38cef99aa1f05ff, 64'h097b6b9375c5e115, 64'hd4f19ae5aebf69ff, 64'h47f6c3c356d17698, 64'hf576bc08f2240b7b, 64'h2a33357fb904c22b, 64'hf9782c961c3b5687, 64'h7f644b7e17c1ebbe, 64'h8905b533dc0ecd1a, 64'h2bd8d511c9ea52cc, 64'hb12738a0975c340c, 64'h32eab2f2244d05cf, 64'h18befe2b80a28c9d, 64'h2af727b6bda67acb, 64'h7ecc5e52fe073433, 64'h1292419d903e7415, 64'h9f978ecda5d867f3, 64'h17cf1c90d0202c69, 64'h9504bc5443cd2760, 64'h833578e8b5d1f9eb, 64'h29b53819409917e5, 64'h6a6477a032be781f, 64'hed5c4624b074b7e9, 64'h85c4ddb63f4c78e4, 64'h32f033202e284282, 64'ha121e52d7ab1a8ee, 64'hf832119af7c40023, 48'hbd782703fba3 };

  localparam [ETHIPV4_NTS_TESTPACKETS_BITS-1:0] nts_packet_ipv4_response5 = { 64'h0000000000000000, 64'h0000000008004500, 64'h02a0c4ac40004011, 64'h759e7f0000017f00, 64'h0001101eccc0028c, 64'h00a0240500f60000, 64'h0000000000000000, 64'h0000e1208dcbdd35, 64'h1000eb3f7b35711a, 64'h50d6e1208dcbdd35, 64'h1000e1208dcbdd35, 64'h100001040024f7d4, 64'h2b2df5367ab1e4ba, 64'h70b9f848cec24727, 64'hb8da97007037b202, 64'h81f1dd7db8730404, 64'h0230001002187334, 64'h78edfea58be84234, 64'h573949977b4124e1, 64'h3be1e3a2230643fb, 64'heac4fac5470fba5d, 64'hc60afcbea8396e8f, 64'ha989e2d40a541e26, 64'h919e945fcaeded79, 64'hd93e7528380bde9c, 64'h8194d6785fb57b74, 64'h50573ef0968b2230, 64'hf583c105066fbb13, 64'h99242c7bc795c211, 64'h2782786577bdd6dd, 64'h736ed668939d9512, 64'hcfe98c992ee15507, 64'h95ac2f9e44cfc9a7, 64'h6aba555d34cee69c, 64'h9413d619bffa2580, 64'h3387140c4c56f91a, 64'ha43f0f572b672c06, 64'ha3ac03d0a4aae34b, 64'hf242e062df3a6d1e, 64'h1227c18b466568aa, 64'h54c526ee6c3937cd, 64'h9355a16828d28d20, 64'hf136a8ab54dce22c, 64'h763b63d325a3f00c, 64'h20ccec46d0aa7851, 64'h35d804b85d460207, 64'h90ab804ed10a3f16, 64'h0e1f6d4ccda20c09, 64'h6a1742665189df7d, 64'h57bb45edbe40b595, 64'h41f74ae453534bfe, 64'h7cb7e91a364a0ae2, 64'h951551eb74e6518c, 64'h2564320ea5290a78, 64'hd1b28679e7ee4860, 64'h679684498064527b, 64'hb79049074fd54282, 64'h3002c02d3a2bdb65, 64'hd2f3356ab9c8e956, 64'hbd40705d9b433728, 64'h21c65bea7067d5db, 64'h9fa0f1f08a867410, 64'hc584890d5d4c2a60, 64'h5dea1c5cc6f307df, 64'h014659f6bd98c8b6, 64'hd8cbc783ce35d54c, 64'h2da06c4d932f3e94, 64'hd57d233b9fba98ae, 64'h7b32e250396488af, 64'h646449aa0ca7519e, 64'h426299ff70d1326c, 64'h9abfcc4d9c8f857d, 64'hd9232b9b2bb05448, 64'hc0c058f4be620a19, 64'he0a216a2db9e7c4c, 64'h7c2d0082ee4c540f, 64'h3748c971720ded5a, 64'h3549b026a2dd8459, 64'h0a5f91c867231c3f, 64'h903f6854a5042835, 64'h32a3723e5d38da11, 64'he5dca475565fcde1, 64'ha90dd90049e196ed, 64'he6b1c878cda606f6, 64'h2608760f3aee28ad, 48'h7f24e6b06ad8 };

  localparam [ETHIPV4_NTS_TESTPACKETS_BITS-1:0] nts_packet_ipv4_response6 = { 64'h0000000000000000, 64'h0000000008004500, 64'h02a0131640004011, 64'h27357f0000017f00, 64'h0001101eebf2028c, 64'h00a0240500f60000, 64'h0000000000000000, 64'h0000e1208ec0fafe, 64'h780009d5cdfe2669, 64'hecdee1208ec0fafe, 64'h7800e1208ec0fafe, 64'h7800010400243655, 64'h6f163ebfae3276b5, 64'haff192a6028098fe, 64'hb8983255de2cdfda, 64'ha57de4d567640404, 64'h0230001002185f05, 64'heae41b465fd15848, 64'hdc6a28236595494c, 64'h29d95ad87378e804, 64'h18ed39600744719a, 64'h373aaf8633158394, 64'ha072a83b576c006a, 64'hf3a89cc61988c861, 64'h7be011b8d51f56a7, 64'h7a9bd8b19df0b18a, 64'h4ecd2d2dcecaa159, 64'h9fd54449f45add80, 64'hf6ff27687cf03f9a, 64'h139828a469991139, 64'hb8a4dc6c20581834, 64'h9f43cca59bb9471e, 64'h3b7776d20a6908da, 64'h5d79c3c260c0881e, 64'hee27121832d39ef2, 64'he0ffdfa4f8f7c6ce, 64'h7056f3ba1ec3d123, 64'h95bc72229c888671, 64'h1f3a8ec7722ec444, 64'hce528b93fe91744a, 64'he7553c405908e4b5, 64'ha586f423dd77aa73, 64'hcd0bb7b8e08a4466, 64'hfddff8e86295ec74, 64'h126d949889705785, 64'h31d7faedf3129759, 64'hcdcefd4379d808ff, 64'h048ed87fc80f2040, 64'hc82565c85c7821e2, 64'h7357b8157e590e55, 64'hc3532445747bdf89, 64'hcf4dec799e0a7ad4, 64'hed6416a54ced42c9, 64'hc49b91e3d97a56f4, 64'hb81bb1871aac2888, 64'h7841cec6366eb5e5, 64'h1af70353ae1c9ba1, 64'h32fdef20cb19f19a, 64'hdd71b219414bdb58, 64'h58f79435b9a46f8e, 64'hb009a7b34813205f, 64'h028b757f3bcff161, 64'h5861c62bebd3d2ac, 64'h53b81dca4c598c6a, 64'h3c207a665bf338db, 64'h19443645d67be57d, 64'he6e91404d5022f81, 64'h44b43085e280a03f, 64'hc0dc9b5b09cd1eb2, 64'h6768de0e33c8b129, 64'he80c6f714f6a634b, 64'h583c6b6aab6c9ff6, 64'h919be96fe8b7f273, 64'h57686ddd776ea965, 64'h2528ff7c5fce67dd, 64'hd88cd73dd02ec41f, 64'heccffed107afa0b8, 64'hcb75d2c9334178d1, 64'h98218e5162fc0d98, 64'hddf267f35a4ad73e, 64'h290998aa8a09eb18, 64'h0a6e4e0d4d35c3bf, 64'he67446b08a7c939f, 64'h7e0e977d012e8c86, 64'h0a3f56fc18efb0d8, 48'heb74a61fbe94 };

  localparam [ETHIPV4_NTS_TESTPACKETS_BITS-1:0] nts_packet_ipv4_request1 = { 64'h0000000000000000, 64'h0000000008004500, 64'h02a0c4ab40004011, 64'h759f7f0000017f00, 64'h0001ccc0101e028c, 64'h00a0230000200000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000eb3f7b35711a, 64'h50d601040024f7d4, 64'h2b2df5367ab1e4ba, 64'h70b9f848cec24727, 64'hb8da97007037b202, 64'h81f1dd7db8730204, 64'h00682b30980579b0, 64'h9bd394da6aa4b0cd, 64'h4989c356c64cb031, 64'h64c0c23fa1d61579, 64'hc7dbb78496bc1f95, 64'h27189fd0b4f5ada4, 64'h4ecf5052dcc33bab, 64'h2a90ca4c5011f2e6, 64'he64b9d6dc9dc7b5e, 64'h43011d5e3846cf4e, 64'h94ca4843e6b473eb, 64'h8adb80fc5c8366bd, 64'hfe8b69b8b5bb0304, 64'h0068000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000304, 64'h0068000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000304, 64'h0068000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000304, 64'h0068000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000404, 64'h002800100010adf1, 64'h62d91c6b9894501d, 64'h4b102ce39fbc2537, 64'hd84ea25db8498682, 48'h10558dfe3707 };

  localparam [ETHIPV4_NTS_TESTPACKETS_BITS-1:0] nts_packet_ipv4_request2 = { 64'h0000000000000000, 64'h0000000008004500, 64'h02a0131540004011, 64'h27367f0000017f00, 64'h0001ebf2101e028c, 64'h00a0230000200000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h000009d5cdfe2669, 64'hecde010400243655, 64'h6f163ebfae3276b5, 64'haff192a6028098fe, 64'hb8983255de2cdfda, 64'ha57de4d567640204, 64'h00682b3076b5e7b6, 64'h048efa30d87888d2, 64'h709614c3cda4c841, 64'h48ce1d9ecfaf395d, 64'h7625d735009621a7, 64'h8c7a5430ca40b636, 64'haaf6fcfe8815437f, 64'hb00761607149e425, 64'h6b10b925ab96e59b, 64'hef9eccf720386318, 64'h96e02a0ba2479796, 64'hbedc0bcb1673017f, 64'hd76d0d9b05c40304, 64'h0068000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000304, 64'h0068000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000304, 64'h0068000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000304, 64'h0068000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000404, 64'h0028001000109c20, 64'ha5628e63642e446f, 64'hb15ae6459ee56f39, 64'ha9cdc5d14a8506b9, 48'h1d90d7056363 };

  localparam [ETHIPV6_NTS_TESTPACKETS_BITS-1:0] nts_packet_ipv6_request1 = { 64'h0000000000000000, 64'h0000000086dd6000, 64'h0000028c11400000, 64'h0000000000000000, 64'h0000000000010000, 64'h0000000000000000, 64'h000000000001c528, 64'h101e028c029f2300, 64'h0020000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h000000000000d28a, 64'h27e711a7c03d0104, 64'h002481c0511c3e5e, 64'heb916a896c27b3b6, 64'hb48178eb79d3611a, 64'hb4b009c034bb89dc, 64'h1311020400682b30, 64'h934e47ee4ef90bcd, 64'h2db5548f21b0ca97, 64'hec8115349f734c47, 64'h9256e70e1e7e9e9a, 64'h241dcf30448b2ec2, 64'h33d1393f5f256526, 64'hd61d5e790aeeeae3, 64'h73ca8cc2354afa5d, 64'h2a0f2e4b3eada37f, 64'hb2351a6e3c27fa6d, 64'he917584462e3e6e7, 64'hf6912b95cfcc63ee, 64'h9eae030400680000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000030400680000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000030400680000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000030400680000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000040400280010, 64'h0010bcde5b727894, 64'hd1474b7ebb548ade, 64'hb20ce193a04aef41, 64'h91a4c7866b201516, 16'h6eaf };

  localparam [ETHIPV6_NTS_TESTPACKETS_BITS-1:0] nts_packet_ipv6_request2 = { 64'h0000000000000000, 64'h0000000086dd6000, 64'h0000028c11400000, 64'h0000000000000000, 64'h0000000000010000, 64'h0000000000000000, 64'h000000000001a481, 64'h101e028c029f2300, 64'h0020000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000009006, 64'h7ae76b0e7c8f0104, 64'h002442c6f064b709, 64'h5020fe86a9a3ee40, 64'h24873e09427a8bda, 64'h42913ac7a4210292, 64'h5605020400682b30, 64'hd49a5da26e878c97, 64'h95a0e8d0be12c940, 64'h8d3335fe04d25f97, 64'h615b4b9955786ce6, 64'h8c20a76268775cc5, 64'h64444dfa8b32b61b, 64'h6902f7bc1345b6e1, 64'h55d30a580e7db691, 64'he627d22e0b0a768b, 64'h3ae3c420e8fe60bb, 64'hcd44679ddb4c66ca, 64'h192adbb6440f0f28, 64'h6ebd030400680000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000030400680000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000030400680000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000030400680000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, 64'h0000040400280010, 64'h001077615f9af204, 64'h4b9b0bdc77ea2105, 64'h1d0b8d0db8249882, 64'h3565bbd1515ff270, 16'h1883 };

  localparam [ETHIPV6_NTS_TESTPACKETS_BITS-1:0] nts_packet_ipv6_response1 = { 64'h0000000000000000, 64'h0000000086dd6000, 64'h0000028c11400000, 64'h0000000000000000, 64'h0000000000010000, 64'h0000000000000000, 64'h000000000001101e, 64'hc528028c029f2405, 64'h00f6000000000000, 64'h000000000000e120, 64'h90f1f3e33000d28a, 64'h27e711a7c03de120, 64'h90f1f3e33000e120, 64'h90f1f3e330000104, 64'h002481c0511c3e5e, 64'heb916a896c27b3b6, 64'hb48178eb79d3611a, 64'hb4b009c034bb89dc, 64'h1311040402300010, 64'h02184ef5b1a46be4, 64'h878088c4d9f0e1e9, 64'h56e6a320e30dac6f, 64'h5784a71972d3336b, 64'h73a2558e7bc28871, 64'h9845a645301922e4, 64'hb851e2d4ad0f8f97, 64'h6342bf694d255d9d, 64'hadf49af2b29cf2f4, 64'he2fa6543aaf85a91, 64'heba73c3289fc7d2d, 64'h1cfc8a14d11f4c99, 64'hebfd468f13cd446a, 64'hdad455aa1603f09b, 64'h75b0a60be7b3b626, 64'h4b13145d1efa33bd, 64'hd642b48f2b54cd6d, 64'h9f643cd7ca1fb00c, 64'hacbd9418e6503924, 64'h0cf88cc1e2cb779c, 64'h2238fa6af1353511, 64'h6c5d0c0374f02f06, 64'h9d8637f45cc94c36, 64'h14f0dbda0809fdca, 64'hd70989d701201c97, 64'h9c46cc94202b2e33, 64'hd3b4006b16d4ee94, 64'h0cbf5568950edcba, 64'h74a417de7290b00d, 64'hbe61f163288f8abc, 64'h05c73063379ebe5a, 64'hf9f0a9120954937d, 64'hba230c96ac7c6c7c, 64'hfa27bfa75b535fcd, 64'hd8b9838c3fc6cec7, 64'h065b69a24f6c8098, 64'haa6aef2f37757ea7, 64'hd753d590de93568c, 64'h865013d0dad2ab2d, 64'h137af8d0c5798f47, 64'h2fd9e960cd149c70, 64'hdb8cc837adbfdde2, 64'hab612248f3afa7de, 64'h4ffd15314c74cf79, 64'h0147035468212612, 64'h6ace8b65cbecce33, 64'ha3b37f1410a5485d, 64'haff29e80f360455d, 64'h24f3e5a24ab7b78a, 64'h268cf42e419bf6dc, 64'h127e4c1b4fe59d41, 64'h44f80fe66dc57c33, 64'hdc4cdbdc1bc58c4d, 64'h66d87be0bec838a9, 64'hc15770613ec7b5c9, 64'hb4b7a17e9493054b, 64'heec3499f1125098a, 64'h9e53eec273daeb73, 64'ha51dd35d401507ed, 64'h723ed46d30a58825, 64'h1d9dcdc2973a3bdd, 64'h350a4d51989f7c01, 64'hfe6f5eeef4b4f265, 64'he217131a40ce5f22, 64'h8ca7210eb5f39026, 64'hcf2893e52371ce41, 64'h30ed76173b233a79, 64'h91aa2a299bbddff4, 64'he59400a03c71752e, 16'hf710 };

  localparam [ETHIPV6_NTS_TESTPACKETS_BITS-1:0] nts_packet_ipv6_response2 = { 64'h0000000000000000, 64'h0000000086dd6000, 64'h0000028c11400000, 64'h0000000000000000, 64'h0000000000010000, 64'h0000000000000000, 64'h000000000001101e, 64'ha481028c029f2405, 64'h00f6000000000000, 64'h000000000000e120, 64'h90f4652ed0009006, 64'h7ae76b0e7c8fe120, 64'h90f4652ed000e120, 64'h90f4652ed0000104, 64'h002442c6f064b709, 64'h5020fe86a9a3ee40, 64'h24873e09427a8bda, 64'h42913ac7a4210292, 64'h5605040402300010, 64'h021887a2b4e0cc9c, 64'h6743ff66ca1d8bcd, 64'h4a6737b70f40b3a7, 64'ha66d21066344d1ab, 64'h092442ae690fc3bb, 64'h1c6a5f6a62780a55, 64'h40f2c2532af4f355, 64'h7d75d32faa38f7f6, 64'hb3ea3516495ceeac, 64'h08a690372263f28d, 64'h23c1f545fea99cea, 64'hdf133abac6ee742a, 64'h828af076e710277b, 64'h8d3c79334ec3a7fd, 64'h2cf4ab961195f3f1, 64'hf0dffb092f6c360f, 64'h5a7b5fed3d484854, 64'hf6ce5b7451f2d8b4, 64'h29f20fa911a5890b, 64'hf5c87290a1ceec6d, 64'h039b833857d1885d, 64'hb36dc72db9e76b37, 64'h48c043fd18b7c0b8, 64'h44ee4183ca9982bb, 64'h84e9f7e92580a660, 64'ha3f6400e1961d5ba, 64'h5461da1178e97737, 64'h1f24aab8be3b04b2, 64'h305452d6dafde4fe, 64'hd347caee01e9c81d, 64'haee47b3a35291f75, 64'hf12fcbb2d4e8e35c, 64'hdede4d59a2fd9dc0, 64'hbac3008ef6d82923, 64'hca55b05d7216f8f3, 64'h90b14f60da316597, 64'h7b18458aa95bf4a5, 64'h4b53bb67afdfc42e, 64'he577ae9a0550e5b1, 64'hb6c0f68c835f336c, 64'h8bd28efc7558fb12, 64'he6f6ad21f0e338c1, 64'h267f5dc507ec745c, 64'h301dec40caa76c36, 64'h8b29a2b6b0ac4d29, 64'hd0ca6d3120d232b0, 64'h9c374ab32f35b6a3, 64'hab90a6f23ea6490f, 64'h1efc8550ad51650c, 64'h00ddfc190a0426eb, 64'h67c458317958991d, 64'hc67bdf833740f0a7, 64'h09c28988bba01d78, 64'hf33e314a11650b3b, 64'h3694cc426e48fb0e, 64'hfddff08ee22a9239, 64'hb9f985b2fe487b8e, 64'h91b50274abf25111, 64'h2dc8948e88649119, 64'h0d02f9e1b8b9f3dd, 64'hd33a06c1d427baf7, 64'h95f6278ccf1a2b6f, 64'ha146e7e470b52e0f, 64'h24034578bfe80688, 64'hd88799bd7560e595, 64'h0355c3b79f46ce55, 64'h2fe0307c0a16a603, 64'h93b6b1c2bb59e06a, 64'h480235d64bfdc1a5, 16'hd657 };

  localparam[31:0] NTS_TEST_REQUEST_MASTER_KEY_ID_1=32'h30a8dce1;
  localparam[255:0] NTS_TEST_REQUEST_MASTER_KEY_1=256'h6d1e7f51_f64876ba_68d4669e_649ad613_402bf7bb_5cf275a9_83a28dab_5e416314;
  localparam[255:0] NTS_TEST_REQUEST_C2S_KEY_1=256'hf6467017_5420ab7e_2952fc90_fff2649e_e9ae6707_05d32341_94e72f48_6618a5b5;
  localparam[255:0] NTS_TEST_REQUEST_S2C_KEY_1=256'hfa8ac687_49e3d765_618b2e63_496a5b6f_20baf052_148863bb_49555ac0_88fc5c44;
  localparam[1839:0] NTS_TEST_REQUEST_WITH_KEY_IPV4_1=1840'h001c7300_00995254_00cdcd23_08004500_00d80001_00004011_bc3f4d48_e37ec23a_cad31267_101b00c4_3a272300_00200000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00002d88_68987dd0_23a60104_0024d406_12b0c40f_353d6afc_d5709668_cd4ebceb_cd8ab0aa_4fd63533_3e8491dc_9f0d0204_006830a8_dce151bd_4e5aa6e3_e577ab41_30e77bc7_cd5ab785_9283e20b_49d8f6bb_89a5b313_4cc92a3d_5eef1f45_3930d7af_f838eec7_99876905_a470e88b_1c57a85a_93fab799_a47c1b7c_8706604f_de780bf9_84394999_d7d59abc_5468cfec_5b261efe_d850618e_91c5;
  localparam[1999:0] NTS_TEST_REQUEST_WITH_KEY_IPV6_1=2000'h001c7300_00995254_00cdcd23_86dd6000_000000c4_11402a01_03f00001_00085063_d01c72c6_ab922a01_03f70002_00520000_00000000_00111267_101b00c4_5ccc2300_00200000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00002d88_68987dd0_23a60104_0024d406_12b0c40f_353d6afc_d5709668_cd4ebceb_cd8ab0aa_4fd63533_3e8491dc_9f0d0204_006830a8_dce151bd_4e5aa6e3_e577ab41_30e77bc7_cd5ab785_9283e20b_49d8f6bb_89a5b313_4cc92a3d_5eef1f45_3930d7af_f838eec7_99876905_a470e88b_1c57a85a_93fab799_a47c1b7c_8706604f_de780bf9_84394999_d7d59abc_5468cfec_5b261efe_d850618e_91c5;


  localparam[31:0] NTS_TEST_REQUEST_MASTER_KEY_ID_2=32'h13fe78e9;
  localparam[255:0] NTS_TEST_REQUEST_MASTER_KEY_2=256'hfeb10c69_9c6435be_5a9ee521_e40e420c_f665d8f7_a969302a_63b9385d_353ae43e;
  localparam[255:0] NTS_TEST_REQUEST_C2S_KEY_2=256'h8b61a5d5_b5d13237_2272b0e7_59938580_1cbbdfd6_d2f59fe4_8c11551d_8c724265;
  localparam[255:0] NTS_TEST_REQUEST_S2C_KEY_2=256'h55b99245_5a4c8089_e6a1281a_f8a2842d_443ea9ac_34646e84_dca14456_6f7b908c;
  localparam[2159:0] NTS_TEST_REQUEST_WITH_KEY_IPV4_2=2160'h001c7300_00995254_00cdcd23_08004500_01000001_00004011_bc174d48_e37ec23a_cad31267_101b00ec_8c5b2300_00200000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_000071cc_4c8cdb00_980b0104_002492ae_9b06e29f_638497f0_18b58124_85cbef5f_811f516a_620ed802_4546bb3e_db590204_006813fe_78e93426_b1f08926_0a257d85_5c533225_c7540952_f35b63d9_f6f6fb4c_69dbc025_3c869740_6b59c01c_d297755c_960a2532_7d40ad6f_41a636d1_4f8a584e_6414f559_3a0912fd_8a7e4b69_88be44ea_97f6f60f_b3d799f9_293e5852_d40fa062_4038e0fc_a5d90404_00280010_00107812_c6677d04_a1c0ac02_0219687c_17d5ca94_9acd04b0_ac8d8d82_d6c71f3f_8518;
  localparam[2319:0] NTS_TEST_REQUEST_WITH_KEY_IPV6_2=2320'h001c7300_00995254_00cdcd23_86dd6000_000000ec_11402a01_03f00001_00085063_d01c72c6_ab922a01_03f70002_00520000_00000000_00111267_101b00ec_af002300_00200000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_000071cc_4c8cdb00_980b0104_002492ae_9b06e29f_638497f0_18b58124_85cbef5f_811f516a_620ed802_4546bb3e_db590204_006813fe_78e93426_b1f08926_0a257d85_5c533225_c7540952_f35b63d9_f6f6fb4c_69dbc025_3c869740_6b59c01c_d297755c_960a2532_7d40ad6f_41a636d1_4f8a584e_6414f559_3a0912fd_8a7e4b69_88be44ea_97f6f60f_b3d799f9_293e5852_d40fa062_4038e0fc_a5d90404_00280010_00107812_c6677d04_a1c0ac02_0219687c_17d5ca94_9acd04b0_ac8d8d82_d6c71f3f_8518;


  //----------------------------------------------------------------
  // Test bench input output regs, wires etc
  //----------------------------------------------------------------

  reg                  i_areset;
  reg                  i_clk;

  reg [63:0]           i_ntp_time;

  wire                 o_dispatch_rx_packet_read_discard;
  reg                  i_dispatch_rx_packet_available;
  reg [3:0]            i_dispatch_rx_data_last_valid;
  reg                  i_dispatch_rx_fifo_empty;
  wire                 o_dispatch_rx_fifo_rd_start;
  reg                  i_dispatch_rx_fifo_rd_valid;
  reg [63:0]           i_dispatch_rx_fifo_rd_data;

  reg                  i_api_cs;
  reg                  i_api_we;
  reg [11:0]           i_api_address;
  reg [31:0]           i_api_write_data;
  wire                 o_api_busy;
  wire                 o_api_read_data_valid;
  wire [31:0]          o_api_read_data;


  reg          [3 : 0] detect_bits;

  reg                  tx_receiving;

  wire                 detect_unique_identifier;
  wire                 detect_nts_cookie;
  wire                 detect_nts_cookie_placeholder;
  wire                 detect_nts_authenticator;

  wire                 o_busy;

  reg                  i_dispatch_tx_packet_read;
  reg                  i_dispatch_tx_fifo_rd_start;

  wire                 o_dispatch_tx_packet_available;
  wire                 o_dispatch_tx_fifo_empty;
  /* verilator lint_off UNUSED */
  wire                 o_dispatch_tx_fifo_rd_valid;
  wire [63:0]          o_dispatch_tx_fifo_rd_data;    //TODO implement test support
  wire  [3:0]          o_dispatch_tx_bytes_last_word; //TODO implement test support
  /* verilator lint_on UNUSED */

  //----------------------------------------------------------------
  // Test bench macros
  //----------------------------------------------------------------

  `define assert(condition) if(!(condition)) begin $display("ASSERT FAILED: %s:%0d %s", `__FILE__, `__LINE__, `"condition`"); $finish(1); end

  //----------------------------------------------------------------
  // Test bench tasks
  //----------------------------------------------------------------

  reg [63:0] packet [0:99];
  integer packet_available;

  task send_packet (
    input [65535:0] source,
    input    [31:0] length,
    output    [3:0] detect_bits
  );
    integer i;
    integer packet_ptr;
    integer source_ptr;
    begin
      if (verbose_output > 0) $display("%s:%0d Send packet!", `__FILE__, `__LINE__);
      detect_bits = 'b0;
      `assert( (0==(length%8)) ); // byte aligned required
      for (i=0; i<100; i=i+1) begin
        packet[i] = 64'habad_1dea_f00d_cafe;
      end
      packet_ptr = 1;
      source_ptr = (length % 64);
/*
      case (source_ptr)
         56: packet[0] = { 8'b0, source[55:0] };
         48: packet[0] = { 16'b0, source[47:0] };
         32: packet[0] = { 32'b0, source[31:0] };
         24: packet[0] = { 40'b0, source[23:0] };
         16: packet[0] = { 48'b0, source[15:0] };
          8: packet[0] = { 56'b0, source[7:0] };
          0: packet_ptr = 0;
        default:
          `assert(0)
      endcase
*/
      case (source_ptr)
         56: packet[0] = { source[55:0], 8'b0 };
         48: packet[0] = { source[47:0], 16'b0 };
         32: packet[0] = { source[31:0], 32'b0 };
         24: packet[0] = { source[23:0], 40'b0 };
         16: packet[0] = { source[15:0], 48'b0 };
          8: packet[0] = { source[7:0], 56'b0 };
          0: packet_ptr = 0;
        default:
          `assert(0)
      endcase
      if (verbose_output > 2) $display("%s:%0d length=%0d packet_ptr=%0d packet=%h", `__FILE__, `__LINE__, length, 0, packet[0]);
      for (i=0; i<length/64; i=i+1) begin
         packet[packet_ptr] = source[source_ptr+:64];
         if (verbose_output > 2) $display("%s:%0d length=%0d packet_ptr=%0d packet=%h", `__FILE__, `__LINE__, length, packet_ptr, packet[packet_ptr]);
         source_ptr = source_ptr + 64;
         packet_ptr = packet_ptr + 1;
      end

      #10
      //i_dispatch_rx_packet_available = 0;
      i_dispatch_rx_data_last_valid  = 'b0;
      //i_dispatch_rx_fifo_empty       = 'b1;
      //i_dispatch_rx_fifo_rd_data     = 'b0;
      `assert( o_busy == 'b0 );
      `assert( o_dispatch_rx_packet_read_discard == 'b0 );
      //`assert( o_dispatch_rx_fifo_rd_en == 'b0 );


      #10
      //i_dispatch_rx_packet_available = 'b1;

      case ((length/8) % 8)
        0: i_dispatch_rx_data_last_valid  = 8; //all bytes valid
        1: i_dispatch_rx_data_last_valid  = 1; //last byte valid
        2: i_dispatch_rx_data_last_valid  = 2;
        3: i_dispatch_rx_data_last_valid  = 3;
        4: i_dispatch_rx_data_last_valid  = 4;
        5: i_dispatch_rx_data_last_valid  = 5;
        6: i_dispatch_rx_data_last_valid  = 6;
        7: i_dispatch_rx_data_last_valid  = 7;
        default:
          begin
            $display("length:%0d", length);
            `assert(0);
          end
      endcase

      `assert( o_busy == 'b0 );
      `assert( o_dispatch_rx_packet_read_discard == 'b0 );
      //`assert( o_dispatch_rx_fifo_rd_en == 'b0 );

      packet_available = packet_ptr-1;
      #40 ;
      packet_available = 0;
      //for (packet_ptr=packet_ptr-1; packet_ptr>=0; packet_ptr=packet_ptr-1) begin
        //i_dispatch_rx_fifo_empty = 'b0;
        //i_dispatch_rx_fifo_rd_data[63:0] = packet[packet_ptr];
        //if (verbose_output > 2) $display("%s:%0d i_dispatch_rx_fifo_rd_data = %h", `__FILE__, `__LINE__, packet[packet_ptr]);
        //if (o_dispatch_rx_fifo_rd_en == 'b0) begin
        //  while ( o_dispatch_rx_fifo_rd_en == 'b0 ) begin
        //    if (verbose_output > 1) $display("%s:%0d waiting for dut to wake up...", `__FILE__, `__LINE__);
        //    #10 ;
        //  end
        //end else #10 ;
      //end
      //i_dispatch_rx_fifo_empty = 'b1;
      //#10
      //`assert( o_busy );
      //`assert( o_dispatch_rx_packet_read_discard == 'b1 );
      //`assert( o_dispatch_rx_fifo_rd_en == 'b0 );
      while (o_dispatch_rx_packet_read_discard == 'b0) #10;

      `assert( o_dispatch_rx_packet_read_discard == 'b1 );
      `assert( o_busy );
      //`assert( o_dispatch_rx_fifo_rd_en == 'b0 );

      while (o_busy == 'b1) begin
         detect_bits = {detect_unique_identifier, detect_nts_cookie, detect_nts_cookie_placeholder, detect_nts_authenticator};
        #10 ;
      end

      `assert( o_busy == 'b0 );
      `assert( o_dispatch_rx_packet_read_discard == 'b0 );
      //`assert( o_dispatch_rx_fifo_rd_en == 'b0 );

    end
  endtask

  reg rx_receiving;
  integer rx_counter;
/*
  always @*
    begin
      i_dispatch_rx_fifo_empty = 0;
      if (o_dispatch_rx_fifo_rd_en) begin
        i_dispatch_rx_fifo_rd_data = packet[rx_counter-1];
        if (rx_counter == 1) i_dispatch_rx_fifo_empty = 1;
      end else begin
        i_dispatch_rx_fifo_rd_data = packet[rx_counter];
        if (rx_counter == 0) i_dispatch_rx_fifo_empty = 1;
      end
    end
*/
  reg rx_start_recieved;
  reg rx_transmit_empty;
  always @(posedge i_clk or posedge i_areset)
  begin
    if (i_areset) begin
      i_dispatch_rx_fifo_empty <= 0;
      i_dispatch_rx_fifo_rd_valid <= 0;
      i_dispatch_rx_fifo_rd_data <= 0;
      i_dispatch_rx_packet_available <= 0;
      rx_receiving <= 0;
      rx_start_recieved <= 0;
      rx_counter <= 0;
    end else begin
      i_dispatch_rx_fifo_rd_valid <= 0;
      i_dispatch_rx_fifo_rd_data <= 0;

      if (rx_receiving) begin
        i_dispatch_rx_packet_available <= 1;
        i_dispatch_rx_fifo_empty <= 0;

        if (o_dispatch_rx_fifo_rd_start) begin
          rx_start_recieved <= 1;
        end else if (rx_start_recieved) begin
          i_dispatch_rx_fifo_rd_valid <= 1;
          i_dispatch_rx_fifo_rd_data <= packet[rx_counter];
          if (verbose_output > 2) $display("%s:%0d i_dispatch_rx_fifo_rd_data = %h", `__FILE__, `__LINE__, packet[rx_counter]);
          if (rx_counter == 0) begin
            rx_transmit_empty <= 1;
            rx_receiving <= 0;
          end else begin
            //i_dispatch_rx_fifo_rd_data <= packet[rx_counter-1];
            rx_counter <= rx_counter-1;
          end
        end else begin
          if (verbose_output > 1) $display("%s:%0d waiting for dut to wake up...", `__FILE__, `__LINE__);
        end
      end // rx_receiving
      else if (packet_available != 0) begin
        rx_receiving <= 1;
        rx_counter <= packet_available;
      end
    end
    if (rx_transmit_empty) begin
      i_dispatch_rx_fifo_empty <= 1;
      rx_transmit_empty <= 0;
    end
    if (o_dispatch_rx_packet_read_discard) begin
      i_dispatch_rx_packet_available <= 0;
      rx_start_recieved <= 0;
      rx_receiving <= 0;
    end
  end

  //----------------------------------------------------------------
  // Test bench Design Under Test (DUT) instantiation
  //----------------------------------------------------------------

  nts_engine #(.ADDR_WIDTH(ADDR_WIDTH)) dut (
    .i_areset(i_areset),
    .i_clk(i_clk),

    .i_ntp_time(i_ntp_time),

    .o_busy(o_busy),

    .i_dispatch_rx_packet_available(i_dispatch_rx_packet_available),
    .o_dispatch_rx_packet_read_discard(o_dispatch_rx_packet_read_discard),
    .i_dispatch_rx_data_last_valid(i_dispatch_rx_data_last_valid),
    .i_dispatch_rx_fifo_empty(i_dispatch_rx_fifo_empty),
    .o_dispatch_rx_fifo_rd_start(o_dispatch_rx_fifo_rd_start),
    .i_dispatch_rx_fifo_rd_valid(i_dispatch_rx_fifo_rd_valid),
    .i_dispatch_rx_fifo_rd_data(i_dispatch_rx_fifo_rd_data),

    .o_dispatch_tx_packet_available(o_dispatch_tx_packet_available),
    .i_dispatch_tx_packet_read(i_dispatch_tx_packet_read),
    .i_dispatch_tx_fifo_rd_start(i_dispatch_tx_fifo_rd_start),
    .o_dispatch_tx_fifo_empty(o_dispatch_tx_fifo_empty),
    .o_dispatch_tx_fifo_rd_valid(o_dispatch_tx_fifo_rd_valid),
    .o_dispatch_tx_fifo_rd_data(o_dispatch_tx_fifo_rd_data),
    .o_dispatch_tx_bytes_last_word(o_dispatch_tx_bytes_last_word),

    .i_api_cs(i_api_cs),
    .i_api_we(i_api_we),
    .i_api_address(i_api_address),
    .i_api_write_data(i_api_write_data),
    .o_api_read_data(o_api_read_data),
    .o_api_read_data_valid(o_api_read_data_valid),
    .o_api_busy(o_api_busy),

    .o_detect_unique_identifier(detect_unique_identifier),
    .o_detect_nts_cookie(detect_nts_cookie),
    .o_detect_nts_cookie_placeholder(detect_nts_cookie_placeholder),
    .o_detect_nts_authenticator(detect_nts_authenticator)
  );

  //----------------------------------------------------------------
  // Task for simplifying updating API signals
  //----------------------------------------------------------------

  task api_set;
    input         i_cs;
    input         i_we;
    input  [11:0] i_addr;
    input  [31:0] i_data;
    output        o_cs;
    output        o_we;
    output [11:0] o_addr;
    output [31:0] o_data;
  begin
    o_cs   = i_cs;
    o_we   = i_we;
    o_addr = i_addr;
    o_data = i_data;
    //if (verbose > 0)
    //  $display("%s:%0d cs=%h we=%h addr=%h data=%h", `__FILE__, `__LINE__, i_cs, i_we, i_addr, i_data);
  end
  endtask

  task api_write32( input [31:0] data, input [11:0] addr );
  begin : api_read32_
    while (o_api_busy) #10;
    api_set(1, 1, addr, data, i_api_cs, i_api_we, i_api_address, i_api_write_data);
    #10;
    api_set(0, 0, 0, 0, i_api_cs, i_api_we, i_api_address, i_api_write_data);
    while (o_api_busy) #10;
  end
  endtask

  task api_read32( output [31:0] data, input [11:0] addr );
  begin : api_read32_
    reg [31:0] result;
    result = 0;
    while (o_api_busy) #10;
    api_set(1, 0, addr, 0, i_api_cs, i_api_we, i_api_address, i_api_write_data);
    #10;
    api_set(0, 0, 0, 0, i_api_cs, i_api_we, i_api_address, i_api_write_data);
    while (o_api_busy) #10;
    `assert(o_api_read_data_valid);
    result = o_api_read_data;
    #10;
    `assert(o_api_read_data_valid == 0);
    `assert(o_api_busy == 0);
    data = result;
  end
  endtask

  task api_read64( output [63:0] data, input [11:0] addr );
  begin : api_read64_
    reg [63:0] result;
    result = 0;
    result[63:32] = o_api_read_data;
    api_read32( result[63:32], addr );
    api_read32( result[31:0], addr + 1);
    data = result;
  end
  endtask

  //----------------------------------------------------------------
  // Install key
  //----------------------------------------------------------------

  task install_key_256bit(
    input  [31:0] keyid,
    input [255:0] key,
    input   [1:0] key_index );
  begin : install_key_256bit
    reg [11:0] addr_key;
    reg [11:0] addr_keyid;
    reg [31:0] tmp;
    reg [3:0] i;
    reg [2:0] index;
    case (key_index)
      0:
        begin
          addr_key = API_ADDR_KEYMEM_KEY0_START;
          addr_keyid = API_ADDR_KEYMEM_KEY0_ID;
        end
      1:
        begin
          addr_key = API_ADDR_KEYMEM_KEY1_START;
          addr_keyid = API_ADDR_KEYMEM_KEY1_ID;
        end
      2:
        begin
          addr_key = API_ADDR_KEYMEM_KEY2_START;
          addr_keyid = API_ADDR_KEYMEM_KEY2_ID;
        end
      3:
        begin
          addr_key = API_ADDR_KEYMEM_KEY3_START;
          addr_keyid = API_ADDR_KEYMEM_KEY3_ID;
        end
      default: ;
    endcase
    api_read32(tmp, API_ADDR_KEYMEM_ADDR_CTRL);
    tmp = tmp & ~ (1<<key_index);
    api_write32(tmp, API_ADDR_KEYMEM_ADDR_CTRL);
    #10;
    api_write32(keyid, addr_keyid);
    #10;
    for (i = 0; i < 8; i = i + 1) begin
      index = i[2:0];
      api_write32(key[32*index+:32], addr_key + {8'b00, index});
      #10;
    end
    tmp = tmp | (1<<key_index);
    api_write32(tmp, API_ADDR_KEYMEM_ADDR_CTRL);
  end
  endtask

  task enable_engine;
  begin
    api_write32( 32'h0000_0001, API_ADDR_ENGINE_CTRL);
  end
  endtask


  task init_noncegen;
  begin
    api_write32( 32'h5eb6_3bbb, API_ADDR_NONCEGEN_KEY0);
    api_write32( 32'he01e_eed0, API_ADDR_NONCEGEN_KEY1);
    api_write32( 32'h93cb_22bb, API_ADDR_NONCEGEN_KEY2);
    api_write32( 32'h8f5a_cdc3, API_ADDR_NONCEGEN_KEY3);
    api_write32( 32'h6adf_b183, API_ADDR_NONCEGEN_CONTEXT0);
    api_write32( 32'ha4a2_c94a, API_ADDR_NONCEGEN_CONTEXT1);
    api_write32( 32'h2f92_dab5, API_ADDR_NONCEGEN_CONTEXT2);
    api_write32( 32'hade7_62a4, API_ADDR_NONCEGEN_CONTEXT3);
    api_write32( 32'h7889_a5a1, API_ADDR_NONCEGEN_CONTEXT4);
    api_write32( 32'hdead_beef, API_ADDR_NONCEGEN_CONTEXT5);
    api_write32( {20'h000_0, 12'h000}, API_ADDR_NONCEGEN_LABEL);
    api_write32( 32'h0000_0001, API_ADDR_NONCEGEN_CTRL);
  end
  endtask

  task set_current_key( input [1:0] current_key );
  begin : set_current_key_
    reg [31:0] tmp;
    api_read32(tmp, API_ADDR_KEYMEM_ADDR_CTRL);
    tmp = { tmp[31:18], current_key, tmp[15:0] };
    api_write32(tmp, API_ADDR_KEYMEM_ADDR_CTRL);
  end
  endtask

  //----------------------------------------------------------------
  // Test bench code
  //----------------------------------------------------------------

  initial begin
    $display("Test start: %s:%0d", `__FILE__, `__LINE__);
    i_clk    = 0;
    i_areset = 1;

    i_dispatch_rx_packet_available = 0;
    i_dispatch_rx_data_last_valid  = 'b0;
    i_dispatch_rx_fifo_empty       = 'b1;
    i_dispatch_rx_fifo_rd_valid    = 'b0;
    i_dispatch_rx_fifo_rd_data     = 'b0;

    i_api_cs         = 0;
    i_api_we         = 0;
    i_api_address    = 0;
    i_api_write_data = 0;


    #10
    i_areset = 0;
    `assert( o_dispatch_rx_packet_read_discard == 'b0 );
    `assert( o_dispatch_rx_fifo_rd_start == 'b0 );

    begin : engine_sanity_check
      reg [63:0] name_engine;
      reg [63:0] name_keymem;
      reg [63:0] name_timestamp;
      api_read64(name_engine, API_ADDR_ENGINE_NAME0);
      api_read64(name_keymem, API_ADDR_KEYMEM_NAME0);
      api_read64(name_timestamp, API_ADDR_CLOCK_NAME0);
      $display("%s:%0d Core: engine %h %s", `__FILE__, `__LINE__, name_engine, name_engine);
      $display("%s:%0d Core: keymem %h %s", `__FILE__, `__LINE__, name_keymem, name_keymem);
      `assert( name_engine == 64'h4e_54_53_5f_45_4e_47_4e ); // "NTS_ENGN"
      `assert( name_keymem == 64'h6b_65_79_5f_6d_65_6d_20 ); // "key_mem "
      `assert( name_timestamp == 64'h74_69_6d_65_73_74_6d_70 );  // "timestmp"
    end

    install_key_256bit( NTS_TEST_REQUEST_MASTER_KEY_ID_2, NTS_TEST_REQUEST_MASTER_KEY_2, 3 );
    init_noncegen();
    set_current_key(3);
    enable_engine();

    #20
    $display("%s:%0d o_busy=%h", `__FILE__, `__LINE__, o_busy);
    while (o_busy) #10;
    $display("%s:%0d o_busy=%h", `__FILE__, `__LINE__, o_busy);
    `assert( o_busy == 'b0 );


    //install_key_256bit( NTS_TEST_REQUEST_MASTER_KEY_ID_1, NTS_TEST_REQUEST_MASTER_KEY_1, 0 );
    //install_key_256bit( NTS_TESTKEY0, 256'h00000000_00000001_00000002_00000003_00000004_00000005_00000006_00000007, 2 );
    //install_key_256bit( NTS_TESTKEY1, 256'hFF000000_FF000001_FF000002_FF000003_FF000004_FF000005_FF000006_FF000007, 3 );
/*
    begin : initilize_keymem_with_dummies
      reg [11:0] i;
      for (i = API_ADDR_KEYMEM_KEY0_START; i <= API_ADDR_KEYMEM_KEY0_END; i = i + 1) begin
        api_set(1, 1, i[11:0], { 28'hdeadbee, i[3:0] }, i_api_cs, i_api_we, i_api_address, i_api_write_data);
        #10;
      end
      api_set(1, 1, API_ADDR_KEYMEM_KEY0_ID, NTS_TESTKEY0, i_api_cs, i_api_we, i_api_address, i_api_write_data);
      #10;
      api_set(1, 1, API_ADDR_KEYMEM_KEY0_LENGTH, 32'b0, i_api_cs, i_api_we, i_api_address, i_api_write_data);
      #10;
      for (i = API_ADDR_KEYMEM_KEY1_START; i <= API_ADDR_KEYMEM_KEY1_END; i = i + 1) begin
        api_set(1, 1, i[11:0], { 28'hdeadbee, i[3:0] }, i_api_cs, i_api_we, i_api_address, i_api_write_data);
        #10;
      end
      api_set(1, 1, API_ADDR_KEYMEM_KEY1_ID, NTS_TESTKEY1, i_api_cs, i_api_we, i_api_address, i_api_write_data);
      #10;
      api_set(1, 1, API_ADDR_KEYMEM_KEY1_LENGTH, 32'b1, i_api_cs, i_api_we, i_api_address, i_api_write_data);
      #10;
    end
    api_set(1, 1, API_ADDR_KEYMEM_ADDR_CTRL, 32'b11, i_api_cs, i_api_we, i_api_address, i_api_write_data);
    #10;
*/
/*
    begin : initilize_keymem_with_real_keys
      reg |255:0] key;
      reg [31:0] key_id;
      reg [1:0] j;
      reg [11:0] i;
      reg [11:0] key_start;
      reg [11:0] key_end;
      for (j = 0; j < 2: j = j + 1) begin
        case (j)
          0:
            begin
            end
          1:
            begin
            end
          default: ;
        endcase
      end
   end
*/
    $display("%s:%0d Send legacy NTP", `__FILE__, `__LINE__);
    send_packet({64816'b0, ntp_legacy_packet}, 720, detect_bits);
    `assert(detect_bits == 0);

    //----------------------------------------------------------------
    // IPv4 Responses
    //----------------------------------------------------------------

    $display("%s:%0d Send NTS IPv4 responses", `__FILE__, `__LINE__);
    #10
    send_packet({60048'b0, nts_packet_ipv4_response1}, ETHIPV4_NTS_TESTPACKETS_BITS, detect_bits);
    `assert(detect_bits == 'b1001);

    #100
    send_packet({60048'b0, nts_packet_ipv4_response2}, ETHIPV4_NTS_TESTPACKETS_BITS, detect_bits);
    `assert(detect_bits == 'b1001);

    #10
    send_packet({60048'b0, nts_packet_ipv4_response3}, ETHIPV4_NTS_TESTPACKETS_BITS, detect_bits);
    `assert(detect_bits == 'b1001);

    send_packet({60048'b0, nts_packet_ipv4_response4}, ETHIPV4_NTS_TESTPACKETS_BITS, detect_bits);
    `assert(detect_bits == 'b1001);

    #10
    send_packet({60048'b0, nts_packet_ipv4_response5}, ETHIPV4_NTS_TESTPACKETS_BITS, detect_bits);
    `assert(detect_bits == 'b1001);

    send_packet({60048'b0, nts_packet_ipv4_response6}, ETHIPV4_NTS_TESTPACKETS_BITS, detect_bits);
    `assert(detect_bits == 'b1001);

    //----------------------------------------------------------------
    // IPv4 Requests
    //----------------------------------------------------------------

    $display("%s:%0d Send NTS IPv4 requests", `__FILE__, `__LINE__);
    #20
    send_packet({60048'b0, nts_packet_ipv4_request1}, ETHIPV4_NTS_TESTPACKETS_BITS, detect_bits);
    `assert(detect_bits == 'b1111);

    send_packet({60048'b0, nts_packet_ipv4_request2}, ETHIPV4_NTS_TESTPACKETS_BITS, detect_bits);
    `assert(detect_bits == 'b1111);

    //----------------------------------------------------------------
    // IPv6 Request
    //----------------------------------------------------------------

    $display("%s:%0d Send NTS IPv6 requests", `__FILE__, `__LINE__);

    send_packet({59888'b0, nts_packet_ipv6_request1}, ETHIPV6_NTS_TESTPACKETS_BITS, detect_bits);
    `assert(detect_bits == 'b1111);

    send_packet({59888'b0, nts_packet_ipv6_request2}, ETHIPV6_NTS_TESTPACKETS_BITS, detect_bits);
    `assert(detect_bits == 'b1111);

    //----------------------------------------------------------------
    // IPv6 Responses
    //----------------------------------------------------------------

    $display("%s:%0d Send NTS IPv6 responses", `__FILE__, `__LINE__);

    send_packet({59888'b0, nts_packet_ipv6_response1}, ETHIPV6_NTS_TESTPACKETS_BITS, detect_bits);
    `assert(detect_bits == 'b1001);

    send_packet({59888'b0, nts_packet_ipv6_response2}, ETHIPV6_NTS_TESTPACKETS_BITS, detect_bits);
    `assert(detect_bits == 'b1001);

    //----------------------------------------------------------------
    // Packets with proper keys!
    //----------------------------------------------------------------

    $display("%s:%0d ===> Send NTS requests missing authenticator <===", `__FILE__, `__LINE__);

    send_packet({63696'b0, NTS_TEST_REQUEST_WITH_KEY_IPV4_1}, 1840, detect_bits);
    `assert(detect_bits == 'b1100);

    $display("%s:%0d ===> Send NTS requests with proper keys <===", `__FILE__, `__LINE__);

    send_packet({63376'b0, NTS_TEST_REQUEST_WITH_KEY_IPV4_2}, 2160, detect_bits);
    //`assert(detect_bits == 0); //TODO cleared upon success. Add a better detection of success.

    //----------------------------------------------------------------
    // Human readable Debug
    //----------------------------------------------------------------

    #100 ;
  //$display("%s:%0d: *** CORE: %s %s", `__FILE__, `__LINE__, api_read64(API_ADDR_ENGINE_NAME0), api_read32(API_ADDR_ENGINE_VERSION));
  //$display("%s:%0d: *** CORE: %s", `__FILE__, `__LINE__, api_read64(API_ADDR_CLOCK_NAME0));
  //$display("%s:%0d: *** CORE: %s", `__FILE__, `__LINE__, api_read64(API_ADDR_KEYMEM_NAME0));
  //$display("%s:%0d: *** DEBUG, Errors Crypto: %0d", `__FILE__, `__LINE__, api_read64(API_ADDR_DEBUG_ERR_CRYPTO));
  //$display("%s:%0d: *** DEBUG, Errors TxBuf: %0d", `__FILE__, `__LINE__, api_read64(API_ADDR_DEBUG_ERR_TXBUF));


    $display("Test stop: %s:%0d", `__FILE__, `__LINE__);
    $finish;
  end

  //----------------------------------------------------------------
  // Testbench model: TX
  //----------------------------------------------------------------

  always @(posedge i_clk or posedge i_areset)
  begin
    if (i_areset) begin
      i_dispatch_tx_packet_read   <= 'b0;
      i_dispatch_tx_fifo_rd_start <= 'b0;
      tx_receiving                <= 'b0;

    end else begin
      i_dispatch_tx_packet_read   <= 'b0;
      i_dispatch_tx_fifo_rd_start <= 'b0;
      if (tx_receiving) begin
        if (o_dispatch_tx_fifo_empty) begin
          i_dispatch_tx_packet_read <= 'b1;
          tx_receiving <= 'b0;
        end
      end else if (o_dispatch_tx_packet_available) begin
        tx_receiving <= 'b1;
        i_dispatch_tx_fifo_rd_start <= 'b1;
      end
    end
  end

  //----------------------------------------------------------------
  // Testbench model: NTP clock
  //----------------------------------------------------------------

  always  @(posedge i_clk or posedge i_areset)
  begin
    if (i_areset) begin
      i_ntp_time = 64'h0000_0001_0000_0000;
    end else begin
      i_ntp_time = i_ntp_time + 1;
    end
  end

  //----------------------------------------------------------------
  // Debug debug debug
  //----------------------------------------------------------------

  reg leaving_reset;
  always @(posedge i_clk or posedge i_areset)
  if (i_areset) begin
    leaving_reset <= 1;
    if (verbose_output > 2) $display("%s:%0d reset", `__FILE__, `__LINE__);
  end else if (leaving_reset) begin
    leaving_reset <= 0;
    if (verbose_output > 2) $display("%s:%0d reset no more, normal cycles", `__FILE__, `__LINE__);
  end

  if (verbose_output > 2) begin


      always @*
        $display("%s:%0d dut.parser_muxctrl_crypto: %h", `__FILE__, `__LINE__, dut.parser_muxctrl_crypto);
      always @*
       $display("%s:%0d rx_buf.memctrl: %h", `__FILE__, `__LINE__, dut.rx_buffer.memctrl_reg);
      always @*
        $display("%s:%0d CRYPTO_RX: (AD,NONCE,PC,TAG)=%b %h.%h", `__FILE__, `__LINE__,
        {
          dut.parser_crypto_rx_op_copy_ad,
          dut.parser_crypto_rx_op_copy_nonce,
          dut.parser_crypto_rx_op_copy_pc,
          dut.parser_crypto_rx_op_copy_tag
        },
        dut.parser_crypto_rx_addr, dut.parser_crypto_rx_bytes);
      always @*
        $display("%s:%0d AP WAIT: %h ADDR: %h WS: %h RD_EN: %h, RD_DV: %h RD_DATA: %h (async)", `__FILE__, `__LINE__,
         dut.access_port_wait,
         dut.access_port_addr,
         dut.access_port_wordsize,
         dut.access_port_rd_en,
         dut.access_port_rd_dv,
         dut.access_port_rd_data
       );
      always @(posedge i_clk or posedge i_areset)
        if (i_areset) ; else if (dut.access_port_wait == 0 && dut.access_port_rd_dv == 1)
        $display("%s:%0d AP WAIT: %h ADDR: %h WS: %h RD_EN: %h, RD_DV: %h RD_DATA: %h (clocked)", `__FILE__, `__LINE__,
          dut.access_port_wait,
          dut.access_port_addr,
          dut.access_port_wordsize,
          dut.access_port_rd_en,
          dut.access_port_rd_dv,
          dut.access_port_rd_data
        );
      always @*
        $display("%s:%0d dut.crypto.key_master_reg: %h", `__FILE__, `__LINE__, dut.crypto.key_master_reg);
      always @*
        $display("%s:%0d dut.crypto.key_current_reg: %h", `__FILE__, `__LINE__, dut.crypto.key_current_reg);
      always @*
        $display("%s:%0d dut.crypto.key_c2s_reg: %h", `__FILE__, `__LINE__, dut.crypto.key_c2s_reg);
      always @*
        $display("%s:%0d dut.crypto.key_s2c_reg: %h", `__FILE__, `__LINE__, dut.crypto.key_s2c_reg);
      always @*
        $display("%s:%0d word: %h valid: %h key: %h", `__FILE__, `__LINE__, dut.keymem_internal_key_word, dut.keymem_internal_key_valid, dut.keymem_internal_key_data);
      always @(posedge i_clk or posedge i_areset)
        if (i_areset) ;
        else begin
          if (dut.crypto.ram_a_en && dut.crypto.ram_a_we && dut.crypto.ram_b_en && dut.crypto.ram_b_we)
            $display("%s:%0d crypto write128[%h,%h]: %h%h", `__FILE__, `__LINE__, dut.crypto.ram_a_addr, dut.crypto.ram_b_addr, dut.crypto.ram_a_wdata, dut.crypto.ram_b_wdata);
          else if (dut.crypto.ram_a_en && dut.crypto.ram_a_we==0 && dut.crypto.ram_b_en && dut.crypto.ram_b_we==0)
            $display("%s:%0d crypto read128[%h,%h]", `__FILE__, `__LINE__, dut.crypto.ram_a_addr, dut.crypto.ram_b_addr);
          else if (dut.crypto.ram_a_en && dut.crypto.ram_a_we)
            $display("%s:%0d crypto write64[%h]: %h", `__FILE__, `__LINE__, dut.crypto.ram_a_addr, dut.crypto.ram_a_wdata);
          else if (dut.crypto.ram_a_en && dut.crypto.ram_a_we==0)
            $display("%s:%0d crypto read64[%h]", `__FILE__, `__LINE__, dut.crypto.ram_a_addr);
          else if (dut.crypto.ram_b_en && dut.crypto.ram_b_we)
            $display("%s:%0d crypto write64: %h", `__FILE__, `__LINE__, dut.crypto.ram_b_wdata);
          else if (dut.crypto.ram_b_en && dut.crypto.ram_b_we==0)
            $display("%s:%0d crypto read64[%h]", `__FILE__, `__LINE__, dut.crypto.ram_b_addr);
        end
      always @*
        $display("%s:%0d parser_crypto_op_cookie_loadkeys %h", `__FILE__, `__LINE__, dut.parser_crypto_op_cookie_loadkeys);
      always @(posedge i_clk)
        if (dut.parser_crypto_op_cookie_loadkeys)
          $display("%s:%0d parser_crypto_op_cookie_loadkeys %h (clocked)", `__FILE__, `__LINE__, dut.parser_crypto_op_cookie_loadkeys);
      always @*
        $display("%s:%0d crypto.tag_in: %h", `__FILE__, `__LINE__, dut.crypto.core_tag_in);
    end

  //----------------------------------------------------------------
  // Testbench model: System Clock
  //----------------------------------------------------------------

  always begin
    #5 i_clk = ~i_clk;
  end

endmodule
