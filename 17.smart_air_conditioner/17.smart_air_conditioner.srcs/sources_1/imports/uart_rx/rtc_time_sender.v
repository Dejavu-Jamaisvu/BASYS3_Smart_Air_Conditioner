`timescale 1ns / 1ps

// Sends "HH:MM\r\n" once per second.
module rtc_time_sender(
    input clk,
    input reset,
    input [7:0] rtc_hour,
    input [7:0] rtc_minute,

    input tx_busy,
    input tx_done,
    output reg tx_start,
    output reg [7:0] tx_data
    );

    localparam integer ONE_SEC_TICKS = 27'd100_000_000;

    reg [26:0] r_tick_cnt;
    reg r_sending;
    reg r_wait_done;
    reg [2:0] r_byte_idx;

    reg [7:0] r_hour;
    reg [7:0] r_min;

    function [7:0] bcd_tens_ascii;
        input [7:0] bcd;
        begin
            bcd_tens_ascii = 8'h30 + bcd[7:4];
        end
    endfunction

    function [7:0] bcd_ones_ascii;
        input [7:0] bcd;
        begin
            bcd_ones_ascii = 8'h30 + bcd[3:0];
        end
    endfunction

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            r_tick_cnt <= 27'd0;
            r_sending <= 1'b0;
            r_wait_done <= 1'b0;
            r_byte_idx <= 3'd0;
            r_hour <= 8'h00;
            r_min <= 8'h00;
            tx_start <= 1'b0;
            tx_data <= 8'h30;
        end else begin
            tx_start <= 1'b0;

            if (!r_sending) begin
                if (r_tick_cnt >= (ONE_SEC_TICKS - 1)) begin
                    r_tick_cnt <= 27'd0;
                    r_sending <= 1'b1;
                    r_wait_done <= 1'b0;
                    r_byte_idx <= 3'd0;
                    r_hour <= rtc_hour;
                    r_min <= rtc_minute;
                end else begin
                    r_tick_cnt <= r_tick_cnt + 27'd1;
                end
            end else begin
                if (!r_wait_done && !tx_busy) begin
                    case (r_byte_idx)
                        3'd0: tx_data <= bcd_tens_ascii(r_hour);
                        3'd1: tx_data <= bcd_ones_ascii(r_hour);
                        3'd2: tx_data <= 8'h3A; // ':'
                        3'd3: tx_data <= bcd_tens_ascii(r_min);
                        3'd4: tx_data <= bcd_ones_ascii(r_min);
                        3'd5: tx_data <= 8'h0D; // CR
                        default: tx_data <= 8'h0A; // LF
                    endcase
                    tx_start <= 1'b1;
                    r_wait_done <= 1'b1;
                end else if (r_wait_done && tx_done) begin
                    r_wait_done <= 1'b0;
                    if (r_byte_idx == 3'd6) begin
                        r_sending <= 1'b0;
                    end else begin
                        r_byte_idx <= r_byte_idx + 3'd1;
                    end
                end
            end
        end
    end

endmodule
