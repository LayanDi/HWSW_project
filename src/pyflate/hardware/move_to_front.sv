`timescale 1ns/1ps
module move_to_front #(
    parameter int ALPHABET_SIZE=256, SYMBOL_W=8
)(
    input logic clk,rst_n,init,start,
    input logic [$clog2(ALPHABET_SIZE)-1:0] index,
    output logic [SYMBOL_W-1:0] symbol_out,
    output logic done
);
    logic [SYMBOL_W-1:0] mtf [0:ALPHABET_SIZE-1];
    logic [SYMBOL_W-1:0] selected;
    integer i;
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            done<=0; symbol_out<='0;
            for(i=0;i<ALPHABET_SIZE;i=i+1) mtf[i]<=i[SYMBOL_W-1:0];
        end else begin
            done<=0;
            if(init) begin
                for(i=0;i<ALPHABET_SIZE;i=i+1) mtf[i]<=i[SYMBOL_W-1:0];
            end else if(start) begin
                selected=mtf[index];
                for(i=ALPHABET_SIZE-1;i>0;i=i-1)
                    if(i<=index) mtf[i]<=mtf[i-1];
                mtf[0]<=selected;
                symbol_out<=selected;
                done<=1;
            end
        end
    end
endmodule
