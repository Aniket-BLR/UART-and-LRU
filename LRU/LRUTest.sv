`timescale 1ns/1ps
//`include "LRU_Engine.sv"
module LRU_testbench #(
    parameter SIZE_OF_LRU = 8,
    parameter SIZE_OF_TAG = 20,
    parameter SIZE_OF_ADDRESS = 15,
    parameter REG_WIDTH = SIZE_OF_ADDRESS + SIZE_OF_TAG + 1, //+1 for validity bit.
    parameter INDEX_SIZE = $clog2(SIZE_OF_LRU)
);
  reg [REG_WIDTH - 1: 0] Tagadv_in, Tagadv_out;
  reg clk, Reset, service_request, hit_miss; 

  LRUEngine DUT(
    .Tagadv_in(Tagadv_in), 
    .Tagadv_out(Tagadv_out), 
    .clk(clk), 
    .Reset(Reset), 
    .service_request(service_request), 
    .hit_miss(hit_miss)
    );

  initial begin
    $dumpfile("wave.vcd");
    $dumpvars(0, LRU_testbench);
  end

  initial clk = 0;
  always #(1) clk = ~clk;

  initial begin
    Reset = 1;
    service_request = 0;
    hit_miss = 0;
  end

/* 
I work under the assumptuin that at the start, Cache contains no valid data, so the first service 
request will always be a miss. 
Tagadv = [Tag][Address][Valid bit]
*/
  initial begin
    #2 Reset = 0;
    #2 service_request = 1;
    Tagadv_in = 36'b00000000000000000001_000000000000001_1; //First service request, miss.
    #2 service_request = 0;
    Tagadv_in = 36'b00000000000000000010_000000000000010_1; //This time service request is 0. SHOULD NOT WRITE.
    #1 service_request = 1;
    Tagadv_in = 36'b00000000000000000010_000000000000010_1;
    #2 service_request = 0;
    #2 service_request = 1;
    hit_miss = 1;
    Tagadv_in = 36'b00000000000000000001_000000000000001_1;
    #8 $finish;
  end
endmodule