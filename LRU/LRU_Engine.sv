`include "Basic_Modules.sv"
// Send data in ascending order always. S0, S1, S2 and I0 I1 I2... so on. 
//LRU has no idea whether data is dirty or not. It's just for LRU purposes. The dirty bit is handled by the cache itself.
module LRUComparator #(
    parameter SIZE_OF_LRU = 8,
    parameter TAG_SIZE = 20,
    parameter INDEX_SIZE = $clog2(SIZE_OF_LRU)
) (
    input [SIZE_OF_LRU - 1 : 0]V_Line_LRUQ, 
    input [(SIZE_OF_LRU * TAG_SIZE) - 1 : 0]data_line,
    input [(INDEX_SIZE * SIZE_OF_LRU) - 1 : 0]index_line,
    input [TAG_SIZE - 1 : 0]tag, 
    output logic [INDEX_SIZE - 1 : 0]index,
    output logic index_valid  
);

logic [INDEX_SIZE - 1 : 0] chunk_index [SIZE_OF_LRU]; 
logic [TAG_SIZE - 1 : 0] chunk_tag [SIZE_OF_LRU];
logic [SIZE_OF_LRU - 1 : 0]decider;
genvar i;
generate
    for (i = 0; i < SIZE_OF_LRU ; i++) begin : loop1
        assign chunk_tag[i] = data_line[i * TAG_SIZE + TAG_SIZE - 1 : i * TAG_SIZE];
    end

    for (i = 0; i < SIZE_OF_LRU ; i++) begin : Comparators
        Universal_Comparator #(.DATA_WIDTH(TAG_SIZE)) UC(
            .a(chunk_tag[SIZE_OF_LRU - 1 - i]), 
            .b(tag), 
            .hit(decider[SIZE_OF_LRU - 1 - i])
        );
    end 
endgenerate

//chunk_tag[7] has S0 decider[7] has for S0. 
genvar j;
generate
    for (j = 0; j < SIZE_OF_LRU ; j++) begin : loop2
        assign chunk_index[j] = index_line [j * INDEX_SIZE + INDEX_SIZE - 1 : j * INDEX_SIZE];
    end
endgenerate

/* 
The following code relies on the logical conclusion that within a Cache set, we cannot have duplicate
tags, since the data for one tag is stored in one cache line.
Also 2 addresses with same SetID, BlockID and ByteID, MUST have distinct tags for them to be unique
adresses. 
Note: BlockID and ByteID are to seek within a single cache line. 
*/

always_comb begin
    index = '0;
    index_valid = '0; 
    for (int k = 0; k < SIZE_OF_LRU; k++) begin
        if ((decider[k] == 1'b1) && (V_Line_LRUQ[k] == 1'b1)) begin
            index = chunk_index[k];
            index_valid = '1;
        end
    end
end

endmodule

module LockGenerator #( //LockID for LRU queue. The max index is the LRU. Size of LRU won't ever be < 2
    parameter SIZE_OF_LRU = 8,
    parameter INDEX_SIZE = $clog2(SIZE_OF_LRU)
) (
    input [INDEX_SIZE - 1 : 0]index,
    input Engine_Lock, is_hit,   
    output logic [SIZE_OF_LRU - 2 : 0]lock_key
);

always_comb begin
    int value;
    value = int '(index);
    lock_key = '1; 
    if (Engine_Lock == 1'b0) begin
        lock_key = '0;
        if (is_hit == 1'b0) begin
            lock_key = '0;
        end
        else begin
            if (value != 0) begin
                for (int a = 0; a < (SIZE_OF_LRU - 1) ; a++ ) begin
                    if (a < value) begin
                        lock_key[SIZE_OF_LRU - 2 - a] = 1'b1;  
                    end
                end
            end
        end           
    end
end
    
endmodule

module LRUQueue #( // [Tag] [Address] [Validity Bit]
    parameter SIZE_OF_LRU = 8,
    parameter SIZE_OF_TAG = 20,
    parameter SIZE_OF_ADDRESS = 15, 
    parameter REG_WIDTH = SIZE_OF_ADDRESS + SIZE_OF_TAG + 1, //+1 for validity bit.
    parameter INDEX_SIZE = $clog2(SIZE_OF_LRU) 
) (
    input [SIZE_OF_LRU - 2 : 0]Lock_ID,
    input Engine_Lock, clk, Reset, is_hit,
    input [REG_WIDTH - 1 : 0] Nova_Tagadv,
    input [REG_WIDTH - 1 : 0] Buff_Tagadv,
    output logic [(SIZE_OF_LRU * SIZE_OF_TAG) - 1 : 0] Tags_to_Comp, 
    output logic [SIZE_OF_LRU - 1 : 0]VLine_to_Comp,
    output logic [REG_WIDTH - 1 : 0] LRUTagadv,
    output logic [REG_WIDTH - 1 : 0] MRUTagadv, 
    output logic [REG_WIDTH * SIZE_OF_LRU - 1 : 0] Tagadv_to_Buff
);

logic [SIZE_OF_LRU - 1 : 0]Master_Lock; 
assign Master_Lock = {Lock_ID, Engine_Lock};
logic [REG_WIDTH - 1 : 0] Mid_wires [SIZE_OF_LRU + 1];

genvar b;
generate
    for (b = 0; b < SIZE_OF_LRU ; b++) begin :Reg_Instantiation
        Register #(.WIDTH(REG_WIDTH)) R(
            .Read_sel(~Master_Lock[SIZE_OF_LRU - 1 - b]), //changes
            .Reset(Reset), 
            .clk(clk), 
            .extin_data(Mid_wires[b + 1]), 
            .out_data(Mid_wires[b])
        );
    end
endgenerate

assign Mid_wires[SIZE_OF_LRU] = is_hit ? Buff_Tagadv : Nova_Tagadv; 

//S0 in 1st size of tag chunk of Tags_to_Comp and so on. 
always_comb begin
    for (int c = 0; c < SIZE_OF_LRU ; c++) begin
        Tags_to_Comp[c * SIZE_OF_TAG +: SIZE_OF_TAG] = Mid_wires[SIZE_OF_LRU - 1 - c][REG_WIDTH - 1 -: SIZE_OF_TAG]; //chnges
    end

    for (int d = 0; d < SIZE_OF_LRU ; d++) begin
        VLine_to_Comp[d] = Mid_wires[SIZE_OF_LRU - 1 - d][0]; //Validity bit is the LSB of the register.
    end
end

assign LRUTagadv = Mid_wires[0]; 
assign MRUTagadv = Mid_wires[SIZE_OF_LRU - 1];

always_comb begin
    for (int e = 0; e < SIZE_OF_LRU ; e++) begin
        Tagadv_to_Buff[e * REG_WIDTH +: REG_WIDTH] = Mid_wires[SIZE_OF_LRU - 1 - e];
    end
end
    
endmodule

module QBuff #(
    parameter SIZE_OF_LRU = 8,
    parameter SIZE_OF_TAG = 20,
    parameter SIZE_OF_ADDRESS = 15,
    parameter REG_WIDTH = SIZE_OF_ADDRESS + SIZE_OF_TAG + 1, //+1 for validity bit.
    parameter INDEX_SIZE = $clog2(SIZE_OF_LRU)
) (
    input [REG_WIDTH * SIZE_OF_LRU - 1 : 0] data_choices,
    input [INDEX_SIZE - 1 : 0] index,
    output logic [REG_WIDTH - 1 : 0] data_out
);

// The left most chunk must be outputted when index = 0, and so on.
always_comb begin
    data_out = data_choices[(REG_WIDTH * SIZE_OF_LRU) - 1 - (index * REG_WIDTH) -: REG_WIDTH];
end
    
endmodule

/*
Overall the engine will request for service only in the following conditions:
1. If it is a hit and LRU Queue needs to be updated.
In this case no writing to the LRU Queue is done, only the order of the queue is updated.
2. Cache was missed and the engine needs to update the LRU Queue with the new tag and address.
In case of Cache miss, the LRU is evicted and new data is written to the Q. 
*/
module ELock #(
    parameter SIZE_OF_TAG = 20,
    parameter SIZE_OF_ADDRESS = 15,
    parameter REG_WIDTH = SIZE_OF_ADDRESS + SIZE_OF_TAG + 1 //+1 for validity bit.
) (
    input Service_Status, 
    input [REG_WIDTH - 1 : 0] MRUTagadv,
    input [REG_WIDTH - 1 : 0] TargetTagadv,
    output logic Engine_Lock
);

always_comb begin : ELockSystem
    Engine_Lock = 1'b1; 
    if (Service_Status == 1'b1) begin
        Engine_Lock = 1'b0;
        if (MRUTagadv == TargetTagadv) begin
            Engine_Lock = 1'b1; 
        end
    end
end
    
endmodule

// 2 pins are empty: Service_Status and index_valid.
//Thinking of some handshake FSM for Service_Status. index_valid is pretty useless (no usecase in mind).
module LRUEngine #(
    parameter  SIZE_OF_LRU = 8,
    parameter  SIZE_OF_TAG = 20,
    parameter  SIZE_OF_ADDRESS = 15,
    parameter  REG_WIDTH = SIZE_OF_ADDRESS + SIZE_OF_TAG + 1, //+1 for validity bit.
    parameter  INDEX_SIZE = $clog2(SIZE_OF_LRU)
) (
    input [REG_WIDTH - 1 : 0] Tagadv_in,
    input hit_miss, service_request, clk, Reset, //hit_miss = 1 => hit, 0 => miss.
    output logic [REG_WIDTH - 1 : 0] Tagadv_out 
    // IDEA: If service_request redundant make Tagadv_in's validity bit equivalent to service request??
);

//Gonna hardcode the index line, because that's what it's meant to be. 
logic [(INDEX_SIZE * SIZE_OF_LRU) - 1 : 0] index_line;
always_comb begin
    for (int e = 0; e < SIZE_OF_LRU ; e++) begin
        index_line[e * INDEX_SIZE +: INDEX_SIZE] = INDEX_SIZE'(SIZE_OF_LRU - 1 - e);
    end
end

logic [SIZE_OF_LRU - 1 : 0]V_Line;
logic [SIZE_OF_LRU * SIZE_OF_TAG - 1 : 0]Data_Bus;
logic [REG_WIDTH * SIZE_OF_LRU - 1 : 0]Tagadv_Bus;
logic [INDEX_SIZE - 1 : 0]Comp_to_LockBuff;
logic MasterL_from_Elock, useless;
logic [REG_WIDTH - 1 : 0]MRUTagadv, Buff_to_Q;
logic [SIZE_OF_LRU - 2 : 0]Lock_ID; 

QBuff #(
    .SIZE_OF_LRU(SIZE_OF_LRU), 
    .SIZE_OF_TAG(SIZE_OF_TAG), 
    .SIZE_OF_ADDRESS(SIZE_OF_ADDRESS)
) QBuff1 (
    .data_choices(Tagadv_Bus), 
    .index(Comp_to_LockBuff), 
    .data_out(Buff_to_Q)
);

ELock #(
    .SIZE_OF_TAG(SIZE_OF_TAG), 
    .SIZE_OF_ADDRESS(SIZE_OF_ADDRESS), 
    .REG_WIDTH(REG_WIDTH)
) Lock (
    .Service_Status(service_request), 
    .MRUTagadv(MRUTagadv), 
    .TargetTagadv(Tagadv_in), 
    .Engine_Lock(MasterL_from_Elock)
);

LRUComparator #(
    .SIZE_OF_LRU(SIZE_OF_LRU),
    .TAG_SIZE(SIZE_OF_TAG)
) LRUComp (
    .V_Line_LRUQ(V_Line), 
    .data_line(Data_Bus), 
    .index_line(index_line), 
    .tag(Tagadv_in[REG_WIDTH - 1 : REG_WIDTH - SIZE_OF_TAG]), 
    .index(Comp_to_LockBuff), 
    .index_valid(useless)
);

LockGenerator #(
    .SIZE_OF_LRU(SIZE_OF_LRU)
) LockGen (
    .index(Comp_to_LockBuff), 
    .Engine_Lock(MasterL_from_Elock), 
    .is_hit(hit_miss), 
    .lock_key(Lock_ID)
);

LRUQueue #(
    .SIZE_OF_LRU(SIZE_OF_LRU), 
    .SIZE_OF_TAG(SIZE_OF_TAG), 
    .SIZE_OF_ADDRESS(SIZE_OF_ADDRESS)
) LRUQ (
    .Lock_ID(Lock_ID), 
    .Engine_Lock(MasterL_from_Elock), 
    .clk(clk), 
    .Reset(Reset), 
    .is_hit(hit_miss), 
    .Nova_Tagadv(Tagadv_in), 
    .Buff_Tagadv(Buff_to_Q), 
    .Tags_to_Comp(Data_Bus), 
    .VLine_to_Comp(V_Line), 
    .LRUTagadv(Tagadv_out),
    .MRUTagadv(MRUTagadv), 
    .Tagadv_to_Buff(Tagadv_Bus)
);
    
endmodule