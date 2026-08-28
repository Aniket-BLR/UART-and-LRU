`timescale 1ns/100ps

module Register #(
    parameter DATA_WIDTH = 9
) (
    input [DATA_WIDTH - 1 : 0] in_data, 
    input clk, reset, stall, 
    output reg [DATA_WIDTH - 1 : 0] out_data
);
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            out_data <= '0;
        end else begin
            if (!stall) begin
                out_data <= in_data;
            end else begin
                out_data <= out_data;
            end
        end
    end
endmodule

module FIFO_Queue #(
    parameter DATA_WIDTH = 8,
    parameter FIFO_DEPTH = 4
) (
    input slave_ready, master_ready, clk, reset, 
    input [DATA_WIDTH - 1 : 0] data_in,
    output ready_to_receive, ready_to_send,
    output [DATA_WIDTH : 0] data_out //UART requires validity to be clumped with data. 
);
    logic [FIFO_DEPTH + 1 : 0] stall_stat;
    assign stall_stat [FIFO_DEPTH + 1] = ~slave_ready; //slave_ready =1 when ready. 
    assign ready_to_receive = ~stall_stat[0];
    // stall_stat[FIFO_DEPTH + 1] is hold signal from UART. SS[0] is going to be the hold signal to master. 

    logic [FIFO_DEPTH : 0] valid_stat;
    assign valid_stat[0] = master_ready;
    // valid_stat[0] is the master_ready. valid_stat[FIFO_DEPTH] is ready to send. CONCEPT. 
    /*
    The idea:
    Stall_stat[i] goes into the ith FIFO register. To the buffer, it should seem as though it is simply conversing
    with another register. It keeps signals simple, and makes it universal.
    */
    logic [DATA_WIDTH : 0] data_wires [0 : FIFO_DEPTH];
    assign data_wires [0] = {master_ready, data_in};
    assign data_out = data_wires[FIFO_DEPTH];

    generate
        genvar j;
        for (j = 0; j < FIFO_DEPTH; j = j + 1) begin
            assign stall_stat[j] = stall_stat[j + 1] & valid_stat[j];
        end
    endgenerate

    generate
        genvar i;
        for (i = 0; i < FIFO_DEPTH + 2; i = i + 1) begin
            if (i <= FIFO_DEPTH - 1) begin
                Register #(.DATA_WIDTH(DATA_WIDTH + 1)) R (
                    .clk(clk), 
                    .reset(reset), 
                    .stall(stall_stat[i + 1]), 
                    .in_data(data_wires[i]), 
                    .out_data(data_wires[i + 1])
                    );
                assign valid_stat [i + 1] = data_wires [i + 1][DATA_WIDTH]; 
            end
        end
    endgenerate

    assign ready_to_send = valid_stat[FIFO_DEPTH];

endmodule