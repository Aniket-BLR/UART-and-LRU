// `timescale 1ns/100ps
// module testbench;
//   reg [8:0]data_from_queue;
//   reg clk, reset, ready;
//   wire hold, data_line; 
//   Tx_Unit DUT ( 
//     .data_line(data_line),
//     .clk(clk), 
//     .reset(reset),
//     .hold(hold), 
//     .data_from_queue(data_from_queue), 
//     .ready(ready)
//     );

//   initial begin
//     $dumpfile("wave.vcd");
//     $dumpvars(0, testbench);

//     $monitor("Data_Out: %b,", data_line);
//   end

//   initial clk = 1'b0;
//   always #(1) clk = ~clk;

//   initial begin
//     reset = 1'b1;
//     data_from_queue = '0;   
//   end

//   initial begin
//     #1 ready = 1'b1; 
//     data_from_queue = 9'b1_11001101; 
//     #4 reset = 1'b0; 
//     #800 $finish;
//   end
// endmodule

// `timescale 1ns/100ps

// module tb_Tx_Unit;

//     // Testbench Parameters
//     parameter integer BAUD_RATE       = 10;
//     parameter integer CLOCK_FREQUENCY = 40;
//     parameter integer DATA_SIZE       = 8;

//     // Derived Timing Constants
//     localparam integer CYCLES_PER_BIT = CLOCK_FREQUENCY / BAUD_RATE;
//     localparam real    CLK_PERIOD     = 1000.0 / CLOCK_FREQUENCY; // ns
//     localparam real    BIT_PERIOD     = CLK_PERIOD * CYCLES_PER_BIT;

//     // Interface Signals
//     logic [DATA_SIZE : 0] data_from_queue;
//     logic clk;
//     logic reset;
//     logic ready;
//     logic hold;
//     logic data_line;

//     // Test stimulus queue (3 test bytes)
//     bit [7:0] test_queue[$] = '{8'hA5, 8'h3C, 8'hFF};
//     bit [7:0] current_test_byte;

//     // Instantiate Device Under Test (DUT)
//     Tx_Unit #(
//         .BAUD_RATE(BAUD_RATE),
//         .CLOCK_FREQUENCY(CLOCK_FREQUENCY),
//         .DATA_SIZE(DATA_SIZE)
//     ) dut (
//         .data_from_queue(data_from_queue),
//         .clk(clk),
//         .reset(reset),
//         .ready(ready),
//         .hold(hold),
//         .data_line(data_line)
//     );

//     // Clock Generation (40 Hz equivalent timing)
//     initial begin
//         clk = 0;
//         forever #(CLK_PERIOD / 2.0) clk = ~clk;
//     end

//     // Input Driver Task
//     initial begin
//         // Initial state
//         reset           = 1'b1;
//         ready           = 1'b1;
//         data_from_queue = '0;

//         // Apply Reset
//         #(CLK_PERIOD * 2);
//         reset = 1'b0;
//         #(CLK_PERIOD * 2);

//         $display("\n--- STARTING UART TX TESTBENCH ---");

//         // Process test vectors sequentially
//         while (test_queue.size() > 0) begin
//             current_test_byte = test_queue.pop_front();

//             // Drive Data with Validity Bit set at MSB (data_from_queue[8] = 1)
//             @(posedge clk);
//             data_from_queue <= {1'b1, current_test_byte};
//             $display("[TB DRIVER] Driven to Queue Input: 0x%02X at time %0t ns", current_test_byte, $time);

//             // Wait until DUT loads data into buffer and asserts hold
//             wait(hold == 1'b1);
            
//             // Clear input after buffer captures it
//             @(posedge clk);
//             wait(hold == 1'b0);
//             data_from_queue <= '0;

//             // Wait for transmission of current frame to finish
//             #(BIT_PERIOD * 11);
//         end

//         $display("\n--- ALL TEST VECTORS PROCESSED ---");
//         $finish;
//     end

//     // Monitor & Automatic Receiver Task
//     initial begin
//         bit [7:0] rx_payload;
//         bit       start_bit;
//         bit       stop_bit;

//         // Synchronize monitoring after reset release
//         @(negedge reset);

//         forever begin
//             // 1. Detect Start Bit Falling Edge on data_line
//             @(negedge data_line);
//             $display("[TB MONITOR] Start Bit detected at %0t ns", $time);

//             // 2. Sample Start Bit at midpoint
//             #(BIT_PERIOD / 2.0);
//             start_bit = data_line;
//             if (start_bit != 1'b0) begin
//                 $error("[TB ERROR] False Start Bit detected!");
//             end

//             // 3. Sample 8 Data Bits (LSB First)
//             for (int i = 0; i < DATA_SIZE; i++) begin
//                 #(BIT_PERIOD);
//                 rx_payload[i] = data_line;
//             end

//             // 4. Sample Stop Bit
//             #(BIT_PERIOD);
//             stop_bit = data_line;

//             // 5. Check Received Frame
//             if (stop_bit != 1'b1) begin
//                 $error("[TB ERROR] Framing Error: Missing Stop Bit at %0t ns", $time);
//             end else if (rx_payload == current_test_byte) begin
//                 $display("[TB SUCCESS] Correctly Received UART Frame: 0x%02X", rx_payload);
//             end else begin
//                 $error("[TB ERROR] Mismatch! Expected: 0x%02X, Received: 0x%02X", current_test_byte, rx_payload);
//             end
//         end
//     end

// endmodule

`timescale 1ns / 1ps

module tb_UART_Tx;

    parameter integer BAUD_RATE       = 10;
    parameter integer CLOCK_FREQUENCY = 40;
    parameter integer DATA_SIZE       = 8;
    
    logic [DATA_SIZE : 0] Data_in;
    logic clk;
    logic reset;
    logic busy;
    logic data_line;

    UART_Tx #(
        .BAUD_RATE(BAUD_RATE),
        .CLOCK_FREQUENCY(CLOCK_FREQUENCY),
        .DATA_SIZE(DATA_SIZE)
    ) uut (
        .Data_in(Data_in),
        .clk(clk),
        .reset(reset),
        .busy(busy),
        .data_line(data_line)
    );

    // 40 MHz Clock Generation (25ns period)
    always #12.5 clk = ~clk;

    localparam integer CYCLES_PER_BIT = CLOCK_FREQUENCY / BAUD_RATE;
    localparam time    BIT_PERIOD     = (CYCLES_PER_BIT * 25) * 1ns;

    logic [DATA_SIZE-1:0] test_byte = 8'hA5; // Binary: 1010_0101
    logic [DATA_SIZE-1:0] rx_byte;

    initial begin
        // 1. Initialize
        clk     = 0;
        reset   = 1;
        Data_in = '0;
        
        // Hold reset across multiple edges
        repeat (4) @(posedge clk);
        reset   = 0;
        repeat (2) @(posedge clk);

        $display("--------------------------------------------------");
        $display("[TB] Starting UART Tx Test with Data: 0x%0h", test_byte);
        $display("--------------------------------------------------");

        // 2. Drive inputs on the NEGEDGE (falling edge) to meet setup time for posedge
        @(negedge clk);
        Data_in = {1'b1, test_byte}; // MSB=1 (valid), Payload=0xA5

        // Wait for DUT to latch the data on posedge clk
        @(posedge clk);
        
        // Clear valid flag on the next falling edge
        @(negedge clk);
        Data_in = '0;

        // Check busy status after DUT processed posedge
        #1;
        if (!busy) begin
            $display("[FAIL] DUT did not assert busy after data drive!");
            $finish;
        end else begin
            $display("[TB] Transmitter busy asserted successfully.");
        end

        // 3. Align sampling timing to the middle of the Start Bit
        #(BIT_PERIOD / 2);

        if (data_line !== 1'b0) begin
            $display("[FAIL] Expected Start Bit = 0, Got = %b", data_line);
        end else begin
            $display("[TB] Start bit OK (0)");
        end

        // 4. Sample Data Bits (LSB First)
        for (int i = 0; i < DATA_SIZE; i++) begin
            #BIT_PERIOD;
            rx_byte[i] = data_line;
            $display("[TB] Bit [%0d] = %b (Expected: %b)", i, data_line, test_byte[i]);
        end

        // 5. Sample Stop Bit
        #BIT_PERIOD;
        if (data_line !== 1'b1) begin
            $display("[FAIL] Expected Stop Bit = 1, Got = %b", data_line);
        end else begin
            $display("[TB] Stop bit OK (1)");
        end

        // 6. Wait for busy to clear
        wait(busy == 0);
        #50;

        if (rx_byte === test_byte) begin
            $display("--------------------------------------------------");
            $display("[SUCCESS] Transmitted Byte 0x%0h correctly!", rx_byte);
            $display("--------------------------------------------------");
        end else begin
            $display("--------------------------------------------------");
            $display("[FAIL] Received 0x%0h != Expected 0x%0h", rx_byte, test_byte);
            $display("--------------------------------------------------");
        end

        $finish;
    end

endmodule