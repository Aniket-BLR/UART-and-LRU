`timescale 1ns/100ps

module UART_Tx #( //The core transmission unit. 
    parameter integer BAUD_RATE       = 10, 
    parameter integer CLOCK_FREQUENCY = 40, 
    parameter integer DATA_SIZE       = 8,    

    // Derived parameters
    localparam integer CYCLES_PER_BIT = CLOCK_FREQUENCY / BAUD_RATE, 
    localparam integer BIT_WIDTH      = $clog2(CYCLES_PER_BIT), 
    localparam integer BIT_COUNT_WIDTH = $clog2(DATA_SIZE + 3)
) (
    input  logic [DATA_SIZE : 0] Data_in, //Validity bit also enters. So Data + 1 DATA = 8bits. Validity = MSB
    input  logic clk, reset,    
    output logic busy, data_line
); 
    logic [BIT_WIDTH - 1 : 0] baud_counter; 
    logic baud_tick, tx_busy;
    
    logic valid;
    assign valid = Data_in[DATA_SIZE];  

    // Baud Rate Generator Counter
    always_ff @(posedge clk or posedge reset) begin : Baud_Tick
        if (reset) begin
            baud_counter <= '0;
            baud_tick    <= 1'b0;
        end else if (tx_busy) begin
            if (baud_counter == BIT_WIDTH'(CYCLES_PER_BIT - 1)) begin
                baud_counter <= '0;
                baud_tick    <= 1'b1; // 1-cycle active HIGH pulse
            end else begin
                baud_counter <= baud_counter + 1'b1;
                baud_tick    <= 1'b0;
            end
        end else begin
            baud_counter <= '0;
            baud_tick <= 1'b0;
        end
    end

    logic [DATA_SIZE + 2 - 1 : 0] Data_to_push; //1'b1 for stop and 1'b0 for start.
    logic [BIT_COUNT_WIDTH - 1 : 0] bit_count = '0; 

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            Data_to_push <= '1;
            bit_count <= '0;
        end else begin
            if (!tx_busy) begin
                if (valid) begin
                    Data_to_push <= {1'b1, Data_in[DATA_SIZE - 1 : 0], 1'b0};
                    // FIX 2: Set bit_count to (DATA_SIZE + 2) so it counts DOWN to 0
                    bit_count <= (BIT_COUNT_WIDTH)'(DATA_SIZE + 2); 
                end else begin
                    Data_to_push <= '1;
                    bit_count <= '0;
                end
            end else begin
                if (baud_tick) begin
                    Data_to_push <= {1'b1, Data_to_push[DATA_SIZE + 1 : 1]};
                    // FIX 3: Decrement instead of increment to sync with baud_tick
                    bit_count <= bit_count - 1'b1; 
                end else begin
                    Data_to_push <= Data_to_push;
                    bit_count <= bit_count;
                end
            end
        end
    end

    always_comb begin
        if (reset) begin
            tx_busy = 0;
        end else begin
            if (bit_count != '0) begin
                tx_busy = 1;
            end else begin
                tx_busy = 0;
            end
        end
    end

    assign busy = tx_busy;
    assign data_line = Data_to_push[0]; //LSB_first

endmodule

