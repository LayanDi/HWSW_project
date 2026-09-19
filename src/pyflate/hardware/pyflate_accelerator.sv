`timescale 1ns/1ps
module pyflate_accelerator #(
    parameter int MAX_CODE_LEN=24, MAX_ENTRIES=512, SYMBOL_W=8
)(
    input logic clk,rst_n,start,init_mtf,
    input logic input_bit,input_valid,end_of_stream,
    input logic load_table_entry,
    input logic [$clog2(MAX_ENTRIES)-1:0] table_index,
    input logic [$clog2(MAX_CODE_LEN+1)-1:0] table_length,
    input logic [MAX_CODE_LEN-1:0] table_code,
    input logic [SYMBOL_W-1:0] table_symbol,
    input logic output_ready,
    output logic [SYMBOL_W-1:0] decoded_symbol,
    output logic decoded_valid,busy,done
);
    logic clear_code,load_bit,do_lookup,do_mtf,symbol_match,mtf_done;

    pyflate_controller u_controller(
        .clk,.rst_n,.start,.input_valid,.symbol_match,.mtf_done,
        .output_ready,.end_of_stream,
        .clear_code,.load_bit,.do_lookup,.do_mtf,.decoded_valid,.busy,.done
    );

    pyflate_datapath #(.MAX_CODE_LEN(MAX_CODE_LEN),.MAX_ENTRIES(MAX_ENTRIES),.SYMBOL_W(SYMBOL_W))
    u_datapath(
        .clk,.rst_n,.init_mtf,.input_bit,.input_valid,
        .clear_code,.load_bit,.do_lookup,.do_mtf,
        .load_table_entry,.table_index,.table_length,.table_code,.table_symbol,
        .symbol_match,.mtf_done,.decoded_symbol
    );
endmodule
