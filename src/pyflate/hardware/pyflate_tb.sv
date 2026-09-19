`timescale 1ns/1ps
module pyflate_tb;
    localparam int MAX_CODE_LEN=8, MAX_ENTRIES=8, SYMBOL_W=8;
    logic clk=0,rst_n=0,start=0,init_mtf=0,input_bit=0,input_valid=0,end_of_stream=0;
    logic load_table_entry=0,output_ready=1;
    logic [$clog2(MAX_ENTRIES)-1:0] table_index;
    logic [$clog2(MAX_CODE_LEN+1)-1:0] table_length;
    logic [MAX_CODE_LEN-1:0] table_code;
    logic [SYMBOL_W-1:0] table_symbol,decoded_symbol;
    logic decoded_valid,busy,done;

    pyflate_accelerator #(.MAX_CODE_LEN(MAX_CODE_LEN),.MAX_ENTRIES(MAX_ENTRIES),.SYMBOL_W(SYMBOL_W)) dut(
        .clk,.rst_n,.start,.init_mtf,.input_bit,.input_valid,.end_of_stream,
        .load_table_entry,.table_index,.table_length,.table_code,.table_symbol,
        .output_ready,.decoded_symbol,.decoded_valid,.busy,.done
    );

    always #5 clk=~clk;

    task automatic program_entry(input int idx,input int len,input logic [MAX_CODE_LEN-1:0] code,input logic [7:0] sym);
        begin
            @(posedge clk); load_table_entry<=1; table_index<=idx; table_length<=len; table_code<=code; table_symbol<=sym;
            @(posedge clk); load_table_entry<=0;
        end
    endtask

    task automatic send_bit(input logic b);
        begin
            @(posedge clk); input_bit<=b; input_valid<=1;
            @(posedge clk); input_valid<=0;
        end
    endtask

    initial begin
        $dumpfile("pyflate_tb.vcd");
        $dumpvars(0,pyflate_tb);

        #20; rst_n=1;

        // Example Huffman table: 0->index0, 10->index1, 11->index2
        program_entry(0,1,8'b00000000,8'd0);
        program_entry(1,2,8'b00000010,8'd1);
        program_entry(2,2,8'b00000011,8'd2);

        @(posedge clk); init_mtf<=1;
        @(posedge clk); init_mtf<=0;

        @(posedge clk); start<=1;
        @(posedge clk); start<=0;

        send_bit(0);
        wait(decoded_valid); $display("decoded=%0d",decoded_symbol);

        send_bit(1); send_bit(0);
        wait(decoded_valid); $display("decoded=%0d",decoded_symbol);

        send_bit(1); send_bit(1);
        wait(decoded_valid); $display("decoded=%0d",decoded_symbol);

        @(posedge clk); end_of_stream<=1;
        @(posedge clk); end_of_stream<=0;

        wait(done);
        $display("Pyflate accelerator test completed");
        #20; $finish;
    end
endmodule
