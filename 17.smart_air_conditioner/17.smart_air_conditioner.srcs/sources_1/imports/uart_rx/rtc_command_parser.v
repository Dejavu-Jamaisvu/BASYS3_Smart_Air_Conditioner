`timescale 1ns / 1ps

// Parses ASCII command: setrtcYYMMDDHHMMSS
// Example: setrtc260306091330
module rtc_command_parser(
    input clk,
    input reset,
    input [7:0] rx_data,
    input rx_done,

    output reg set_time_valid,
    output reg [7:0] out_year,
    output reg [7:0] out_month,
    output reg [7:0] out_date,
    output reg [7:0] out_hour,
    output reg [7:0] out_minute,
    output reg [7:0] out_second
    );

    reg [4:0] r_idx;
    reg [3:0] r_digits [0:11];

    integer i;

    function [7:0] pair_to_bin;
        input [3:0] t;
        input [3:0] o;
        begin
            pair_to_bin = (t * 8'd10) + o;
        end
    endfunction

    function is_digit;
        input [7:0] ch;
        begin
            is_digit = (ch >= 8'h30) && (ch <= 8'h39);
        end
    endfunction

    function is_setrtc_char;
        input [2:0] pos;
        input [7:0] ch;
        begin
            case (pos)
                3'd0: is_setrtc_char = (ch == 8'h73) || (ch == 8'h53); // s/S
                3'd1: is_setrtc_char = (ch == 8'h65) || (ch == 8'h45); // e/E
                3'd2: is_setrtc_char = (ch == 8'h74) || (ch == 8'h54); // t/T
                3'd3: is_setrtc_char = (ch == 8'h72) || (ch == 8'h52); // r/R
                3'd4: is_setrtc_char = (ch == 8'h74) || (ch == 8'h54); // t/T
                default: is_setrtc_char = (ch == 8'h63) || (ch == 8'h43); // c/C
            endcase
        end
    endfunction

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            r_idx <= 5'd0;
            set_time_valid <= 1'b0;

            out_year <= 8'h00;
            out_month <= 8'h01;
            out_date <= 8'h01;
            out_hour <= 8'h00;
            out_minute <= 8'h00;
            out_second <= 8'h00;

            for (i = 0; i < 12; i = i + 1)
                r_digits[i] <= 4'd0;
        end else begin
            set_time_valid <= 1'b0;

            if (rx_done) begin
                // Ignore LF/CR at command boundary.
                if ((r_idx == 5'd0) && ((rx_data == 8'h0A) || (rx_data == 8'h0D))) begin
                    r_idx <= 5'd0;
                end else begin
                    case (r_idx)
                        5'd0, 5'd1, 5'd2, 5'd3, 5'd4, 5'd5: begin
                            if (is_setrtc_char(r_idx[2:0], rx_data)) begin
                                r_idx <= r_idx + 5'd1;
                            end else if ((rx_data == 8'h73) || (rx_data == 8'h53)) begin
                                r_idx <= 5'd1;
                            end else begin
                                r_idx <= 5'd0;
                            end
                        end

                        5'd6, 5'd7, 5'd8, 5'd9, 5'd10, 5'd11,
                        5'd12, 5'd13, 5'd14, 5'd15, 5'd16, 5'd17: begin
                            if (is_digit(rx_data)) begin
                                r_digits[r_idx - 5'd6] <= rx_data[3:0];

                                if (r_idx == 5'd17) begin
                                    if ((pair_to_bin(r_digits[2],  r_digits[3])  >= 8'd1) &&
                                        (pair_to_bin(r_digits[2],  r_digits[3])  <= 8'd12) &&
                                        (pair_to_bin(r_digits[4],  r_digits[5])  >= 8'd1) &&
                                        (pair_to_bin(r_digits[4],  r_digits[5])  <= 8'd31) &&
                                        (pair_to_bin(r_digits[6],  r_digits[7])  <= 8'd23) &&
                                        (pair_to_bin(r_digits[8],  r_digits[9])  <= 8'd59) &&
                                        (pair_to_bin(r_digits[10], rx_data[3:0]) <= 8'd59)) begin
                                        out_year   <= {r_digits[0],  r_digits[1]};
                                        out_month  <= {r_digits[2],  r_digits[3]};
                                        out_date   <= {r_digits[4],  r_digits[5]};
                                        out_hour   <= {r_digits[6],  r_digits[7]};
                                        out_minute <= {r_digits[8],  r_digits[9]};
                                        out_second <= {r_digits[10], rx_data[3:0]};
                                        set_time_valid <= 1'b1;
                                    end
                                    r_idx <= 5'd0;
                                end else begin
                                    r_idx <= r_idx + 5'd1;
                                end
                            end else if ((rx_data == 8'h73) || (rx_data == 8'h53)) begin
                                r_idx <= 5'd1;
                            end else begin
                                r_idx <= 5'd0;
                            end
                        end

                        default: begin
                            r_idx <= 5'd0;
                        end
                    endcase
                end
            end
        end
    end

endmodule
