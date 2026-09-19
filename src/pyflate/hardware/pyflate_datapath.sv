`timescale 1ns/1ps
// ============================================================
// pyflate_datapath.sv - FIXED

module pyflate_datapath #(
    parameter int MAX_CODE_LEN=24, MAX_ENTRIES=512, SYMBOL_W=8
)(
    input logic clk,rst_n,init_mtf,input_bit,input_valid,
    input logic clear_code,load_bit,do_lookup,do_mtf,
    input logic load_table_entry,
    input logic [$clog2(MAX_ENTRIES)-1:0] table_index,
    input logic [$clog2(MAX_CODE_LEN+1)-1:0] table_length,
    input logic [MAX_CODE_LEN-1:0] table_code,
    input logic [SYMBOL_W-1:0] table_symbol,
    output logic symbol_match,mtf_done,
    output logic [SYMBOL_W-1:0] decoded_symbol
);
    logic [MAX_CODE_LEN-1:0] code_value;
    logic [$clog2(MAX_CODE_LEN+1)-1:0] code_length;
    logic [SYMBOL_W-1:0] huffman_symbol, mtf_symbol;

    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin code_value<='0; code_length<='0; end
        else if(clear_code) begin code_value<='0; code_length<='0; end
        else if(load_bit) begin
            // FIXED: no longer also requires input_valid (see header
            // comment) - load_bit alone, as asserted by the
            // controller's S_READ_BIT state, is sufficient and correct.
            code_value <= (code_value<<1) | input_bit;
            code_length <= code_length + 1'b1;
        end
    end

    huffman_lookup #(.MAX_ENTRIES(MAX_ENTRIES),.MAX_CODE_LEN(MAX_CODE_LEN),.SYMBOL_W(SYMBOL_W))
    u_lookup(
        .clk,.rst_n,.load_entry(load_table_entry),.load_index(table_index),
        .load_length(table_length),.load_code(table_code),.load_symbol(table_symbol),
        .lookup_en(do_lookup),.code_length,.code_value,
        .match(symbol_match),.symbol(huffman_symbol)
    );

    move_to_front #(.ALPHABET_SIZE(256),.SYMBOL_W(SYMBOL_W))
    u_mtf(
        .clk,.rst_n,.init(init_mtf),.start(do_mtf && symbol_match),
        .index(huffman_symbol),.symbol_out(mtf_symbol),.done(mtf_done)
    );

    assign decoded_symbol = mtf_symbol;
endmodule
