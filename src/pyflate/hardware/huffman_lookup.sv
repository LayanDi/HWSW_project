`timescale 1ns/1ps
module huffman_lookup #(
    parameter int MAX_ENTRIES=512, MAX_CODE_LEN=24, SYMBOL_W=8
)(
    input logic clk,rst_n,
    input logic load_entry,
    input logic [$clog2(MAX_ENTRIES)-1:0] load_index,
    input logic [$clog2(MAX_CODE_LEN+1)-1:0] load_length,
    input logic [MAX_CODE_LEN-1:0] load_code,
    input logic [SYMBOL_W-1:0] load_symbol,
    input logic lookup_en,
    input logic [$clog2(MAX_CODE_LEN+1)-1:0] code_length,
    input logic [MAX_CODE_LEN-1:0] code_value,
    output logic match,
    output logic [SYMBOL_W-1:0] symbol
);
    logic [$clog2(MAX_CODE_LEN+1)-1:0] length_mem [0:MAX_ENTRIES-1];
    logic [MAX_CODE_LEN-1:0] code_mem [0:MAX_ENTRIES-1];
    logic [SYMBOL_W-1:0] symbol_mem [0:MAX_ENTRIES-1];
    logic valid_mem [0:MAX_ENTRIES-1];
    integer i;

    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) for(i=0;i<MAX_ENTRIES;i=i+1) valid_mem[i]<=0;
        else if(load_entry) begin
            length_mem[load_index]<=load_length;
            code_mem[load_index]<=load_code;
            symbol_mem[load_index]<=load_symbol;
            valid_mem[load_index]<=1;
        end
    end

    always_comb begin
        match=0; symbol='0;
        if(lookup_en) begin
            for(i=0;i<MAX_ENTRIES;i=i+1)
                if(!match && valid_mem[i] &&
                   length_mem[i]==code_length && code_mem[i]==code_value) begin
                    match=1; symbol=symbol_mem[i];
                end
        end
    end
endmodule
