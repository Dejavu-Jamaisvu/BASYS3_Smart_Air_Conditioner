`timescale 1ns / 1ps

module rtc_display(
    input clk,
    input reset,

    input dht_mode,
    input edit_mode,
    input edit_alarm_mode,
    input edit_field,

    input [7:0] rtc_hour,
    input [7:0] rtc_minute,
    input [7:0] edit_hour,
    input [7:0] edit_minute,
    input [7:0] alarm_hour,
    input [7:0] alarm_minute,

    input [7:0] humidity,
    input [7:0] temperature,

    output reg [13:0] seg_data,

    // Blank mask for each digit position (active-high).
    // bit[3]=d1000(HH tens)  bit[2]=d100(HH ones)
    // bit[1]=d10(MM tens)    bit[0]=d1(MM ones)
    output reg [3:0] seg_blank
    );

    localparam integer BLINK_TOGGLE_TICKS = 25_000_000; // 0.25s @100MHz

    reg [24:0] r_blink_cnt;
    reg r_blink_on;

    function [3:0] safe_nibble;
        input [3:0] n;
        begin
            if (n <= 4'd9)
                safe_nibble = n;
            else
                safe_nibble = 4'd0;
        end
    endfunction

    function [13:0] hhmm_value;
        input [7:0] h;
        input [7:0] m;
        reg [3:0] ht;
        reg [3:0] ho;
        reg [3:0] mt;
        reg [3:0] mo;
        begin
            ht = safe_nibble(h[7:4]);
            ho = safe_nibble(h[3:0]);
            mt = safe_nibble(m[7:4]);
            mo = safe_nibble(m[3:0]);
            hhmm_value = (ht * 14'd1000) + (ho * 14'd100) + (mt * 14'd10) + mo;
        end
    endfunction

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            r_blink_cnt <= 25'd0;
            r_blink_on <= 1'b1;
        end else begin
            if (r_blink_cnt >= (BLINK_TOGGLE_TICKS - 1)) begin
                r_blink_cnt <= 25'd0;
                r_blink_on <= ~r_blink_on;
            end else begin
                r_blink_cnt <= r_blink_cnt + 25'd1;
            end
        end
    end

    always @(*) begin
        seg_blank = 4'b0000; // default: no blanking

        if (dht_mode) begin
            seg_data = (humidity * 14'd100) + temperature;
        end else begin
            if (edit_mode) begin
                // Always show the actual edit values (never substitute 8'h00).
                seg_data = hhmm_value(edit_hour, edit_minute);

                // Blink: turn OFF the active field's digit positions via blank_mask.
                if (!r_blink_on) begin
                    if (edit_field == 1'b0)
                        seg_blank = 4'b1100; // blank d1000+d100 = HH digits
                    else
                        seg_blank = 4'b0011; // blank d10+d1   = MM digits
                end
            end else begin
                // Default display: current RTC HHMM.
                seg_data = hhmm_value(rtc_hour, rtc_minute);
            end

            // Keep currently unused ports referenced.
            if (edit_alarm_mode || alarm_hour[0] || alarm_minute[0])
                seg_data = seg_data;
        end
    end

endmodule
