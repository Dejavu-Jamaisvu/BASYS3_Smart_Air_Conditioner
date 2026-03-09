`timescale 1ns / 1ps

module data_sender(
    input clk,
    input reset,
    input start_trigger,
    input [15:0] send_data,  // [15:8]: Temp, [7:0]: Humi
    input tx_busy,
    input tx_done,
    output reg tx_start,
    output reg [7:0] tx_data
    );

    reg r_sending;
    reg r_wait_done;
    reg [3:0] r_byte_idx;

    reg [7:0] r_humi;
    reg [7:0] r_temp;

    function [7:0] clamp_99;
        input [7:0] value;
        begin
            if (value > 8'd99)
                clamp_99 = 8'd99;
            else
                clamp_99 = value;
        end
    endfunction

    function [7:0] dec_tens_ascii;
        input [7:0] value;
        begin
            dec_tens_ascii = (clamp_99(value) / 8'd10) + 8'h30;
        end
    endfunction

    function [7:0] dec_ones_ascii;
        input [7:0] value;
        begin
            dec_ones_ascii = (clamp_99(value) % 8'd10) + 8'h30;
        end
    endfunction

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            tx_start <= 1'b0;
            tx_data <= 8'h00;
            r_sending <= 1'b0;
            r_wait_done <= 1'b0;
            r_byte_idx <= 4'd0;
            r_humi <= 8'd0;
            r_temp <= 8'd0;
        end else begin
            tx_start <= 1'b0;

            if (!r_sending) begin
                if (start_trigger) begin
                    // Latch once to prevent value changes while text is being sent.
                    r_humi <= send_data[7:0];
                    r_temp <= send_data[15:8];
                    r_sending <= 1'b1;
                    r_wait_done <= 1'b0;
                    r_byte_idx <= 4'd0;
                end
            end else begin
                if (!r_wait_done && !tx_busy) begin
                    case (r_byte_idx)
                        4'd0:  tx_data <= "H";
                        4'd1:  tx_data <= ":";
                        4'd2:  tx_data <= dec_tens_ascii(r_humi);
                        4'd3:  tx_data <= dec_ones_ascii(r_humi);
                        4'd4:  tx_data <= " ";
                        4'd5:  tx_data <= "/";
                        4'd6:  tx_data <= " ";
                        4'd7:  tx_data <= "T";
                        4'd8:  tx_data <= ":";
                        4'd9:  tx_data <= dec_tens_ascii(r_temp);
                        4'd10: tx_data <= dec_ones_ascii(r_temp);
                        4'd11: tx_data <= 8'h0D; // CR
                        default: tx_data <= 8'h0A; // LF
                    endcase

                    tx_start <= 1'b1;
                    r_wait_done <= 1'b1;
                end else if (r_wait_done && tx_done) begin
                    r_wait_done <= 1'b0;

                    if (r_byte_idx == 4'd12) begin
                        r_sending <= 1'b0;
                    end else begin
                        r_byte_idx <= r_byte_idx + 4'd1;
                    end
                end
            end
        end
    end

endmodule
