module Universal_Comparator #(
    parameter DATA_WIDTH = 32
) (
    input [DATA_WIDTH - 1 : 0]a, b,
    output hit
);

assign hit = (a == b);

endmodule

module Register #(
    parameter WIDTH = 36
) (
    input Read_sel, Reset, clk, 
    input [WIDTH - 1 : 0]extin_data,
    output logic [WIDTH - 1 : 0]out_data
);

always_ff @(posedge clk) begin
    if (Reset == 1) begin
        out_data <= '0; 
    end
    else begin
        if (Read_sel == 1) begin
            out_data <= extin_data;
        end
    end
end
    
endmodule
