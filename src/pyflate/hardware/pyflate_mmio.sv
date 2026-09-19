`timescale 1ns/1ps
module pyflate_mmio #(
    parameter int ADDR_W=12, DATA_W=64
)(
    input logic clk,rst_n,wr_en,rd_en,
    input logic [ADDR_W-1:0] addr,
    input logic [DATA_W-1:0] wdata,
    input logic accel_busy,accel_done,decoded_valid,
    input logic [7:0] decoded_symbol,
    output logic start_pulse,init_mtf_pulse,
    output logic [DATA_W-1:0] rdata
);
    localparam logic [ADDR_W-1:0] CONTROL=12'h000, STATUS=12'h008, OUTPUT=12'h010;
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin start_pulse<=0; init_mtf_pulse<=0; end
        else begin
            start_pulse<=0; init_mtf_pulse<=0;
            if(wr_en && addr==CONTROL) begin
                start_pulse<=wdata[0];
                init_mtf_pulse<=wdata[1];
            end
        end
    end
    always_comb begin
        rdata='0;
        if(rd_en) case(addr)
            STATUS: begin rdata[0]=accel_busy; rdata[1]=accel_done; rdata[2]=decoded_valid; end
            OUTPUT: rdata[7:0]=decoded_symbol;
            default: rdata='0;
        endcase
    end
endmodule
