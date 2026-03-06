`timescale 1ns / 1ps

module data_sender(
    input clk,
    input reset,
    input start_trigger,
    input [7:0] send_data,   // 1 byte
    input tx_busy,
    input tx_done,
    output reg tx_start,
    output reg [7:0] tx_data
    );

    reg [6:0] r_send_byte_cnt=7'd0;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            tx_start <= 1'b0;
            r_send_byte_cnt <= 7'd0;
        end else begin
            if (start_trigger && !tx_busy) begin
                tx_start <= 1;
                if (r_send_byte_cnt >= 7'd9) begin   // '0' ~ '9' : 10자 
                    r_send_byte_cnt <= 7'd0;
                    tx_data <= send_data;
                end else  begin
                    tx_data <= send_data + r_send_byte_cnt;
                    r_send_byte_cnt <= r_send_byte_cnt + 1;
                end 
            end else begin
               tx_start <= 1'b0; 
            end 
        end 
    end 

endmodule
