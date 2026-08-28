`timescale 1ns/100ps

module UART_Unit #(
    parameter integer BAUD_RATE = 10, 
    parameter integer CLOCK_FREQUENCY = 40, 
    parameter integer DATA_SIZE = 8,
    parameter FIFO_DEPTH = 4
) (
    input [DATA_SIZE - 1 : 0] data_in,
    input clk, reset, data_valid,
    output ready, data_line
);

logic [DATA_SIZE : 0] tdata_buff_to_uart;
logic tbusy_uart_to_buff, tuseless;

FIFO_Queue #(
    .DATA_WIDTH(DATA_SIZE), 
    .FIFO_DEPTH(FIFO_DEPTH)
) Buffer (
    .slave_ready(~tbusy_uart_to_buff), 
    .master_ready(data_valid), 
    .clk(clk), 
    .reset(reset), 
    .data_in(data_in),
    .ready_to_receive(ready), 
    .ready_to_send(tuseless),
    .data_out(tdata_buff_to_uart)
);

UART_Tx #(
    .BAUD_RATE(BAUD_RATE), 
    .CLOCK_FREQUENCY(CLOCK_FREQUENCY),
    .DATA_SIZE(DATA_SIZE)
) Transmitter (
    .Data_in(tdata_buff_to_uart), 
    .clk(clk), 
    .reset(reset),    
    .busy(tbusy_uart_to_buff), 
    .data_line(data_line)
);
    
endmodule