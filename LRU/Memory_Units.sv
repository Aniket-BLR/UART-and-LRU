// All the BRAMs we may ever need. 
module RAM_AsyncReadSyncWrite #( 
    parameter integer DATA_WIDTH = 32,
    parameter integer ADDR_WIDTH = 5,
    localparam integer RAM_DEPTH = 2 ** ADDR_WIDTH
)(
    input clk,
    input we,
    input  [ADDR_WIDTH - 1 : 0] a,
    input  [ADDR_WIDTH - 1 : 0] dpra,
    input  [DATA_WIDTH - 1 : 0] di,
    output [DATA_WIDTH - 1 : 0] spo,
    output [DATA_WIDTH - 1 : 0] dpo
); 

reg [DATA_WIDTH - 1 : 0] ram [RAM_DEPTH - 1 : 0];

initial begin
    for (int i = 0; i < RAM_DEPTH; i++) begin
        ram[i] = DATA_WIDTH'(0);
    end
end

always @(posedge clk) begin
    if (we) begin
        ram[a] <= di;
    end
end

assign spo = ram[a]; //spo contains data just overwritten. 
assign dpo = ram[dpra];

endmodule

