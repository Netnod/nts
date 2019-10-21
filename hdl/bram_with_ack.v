// BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
// LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
// CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
// LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
// ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
// POSSIBILITY OF SUCH DAMAGE.
//
//======================================================================

module bram_with_ack #(
  parameter ADDR_WIDTH = 4
) (
                   input wire                     clk,
                   input wire                     areset,

                   input wire                     cs,
                   input wire                     we,
                   output wire                    ack,
                   input wire  [ADDR_WIDTH-1 : 0] addr,
                   input wire           [127 : 0] block_wr,
                   output wire          [127 : 0] block_rd
                  );


  //Parameterized constant
  localparam NUM_WORDS   = 2**ADDR_WIDTH;
  localparam WAIT_CYCLES = 8'h01;


  //----------------------------------------------------------------
  reg [127 : 0] mem [0 : (NUM_WORDS - 1)];
  reg           mem_we;

  //reg [7 : 0]   wait_ctr_reg;
  //reg [7 : 0]   wait_ctr_new;

  //reg           tmp_ack;
  //reg [127 : 0] tmp_block_rd;
  reg [127 : 0] block_rd_reg;

  reg           ack_reg;
  reg           ack_new;


  //----------------------------------------------------------------
  //----------------------------------------------------------------
  assign ack      = ack_reg;
  assign block_rd = block_rd_reg;


  //----------------------------------------------------------------
  // reg_update
  //
  // Update functionality for all registers in the core.
  //----------------------------------------------------------------
  always @ (posedge clk)
    begin: reg_update
/*
      integer i;
*/
      if (areset)
        begin
          block_rd_reg <= 128'h0;
          ack_reg      <= 1'h0;
        end
      else
        begin
          ack_reg      <= ack_new;

          block_rd_reg <= mem[addr];

          if (mem_we) begin
            mem[addr] <= block_wr;
/*
            for (i = 0; i < NUM_WORDS; i = i + 1) begin
              if (i == addr) begin
                $display("%s:%0d WRITE: mem[%h] = %h (old: %h)", `__FILE__, `__LINE__, addr, block_wr, mem[addr]);
              end else begin
                $display("%s:%0d        mem[%h] = %h", `__FILE__, `__LINE__, i[ADDR_WIDTH-1:0], mem[i]);
              end
            end
*/
          end
        end
    end // reg_update


  //----------------------------------------------------------------
  // mem_access
  //----------------------------------------------------------------
  always @*
    begin : mem_access;
      mem_we       = 1'h0;
      //wait_ctr_new = 8'h0;
      ack_new      = 1'h0;
      //tmp_block_rd = 128'h0;

      if (cs)
        begin
          //wait_ctr_new = wait_ctr_reg + 1'h1;

          //if (wait_ctr_reg >= WAIT_CYCLES)
            //begin
              ack_new = 1'h1;
              if (we)
                mem_we = 1'h1;
            //end
        end
    end
endmodule

