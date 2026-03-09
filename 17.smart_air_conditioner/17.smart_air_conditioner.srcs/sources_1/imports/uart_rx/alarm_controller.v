`timescale 1ns / 1ps

module alarm_controller(
    input clk,
    input reset,

    input [7:0] rtc_hour,
    input [7:0] rtc_minute,
    input [7:0] rtc_second,

    input alarm_enable_cfg,
    input [7:0] alarm_hour_cfg,
    input [7:0] alarm_minute_cfg,
    input alarm_update_pulse,

    input dismiss_btn,

    output reg alarm_active,
    output reg buzzer_on,
    output reg alarm_triggered
    );

    reg [7:0] r_alarm_hour;
    reg [7:0] r_alarm_minute;
    reg r_alarm_enable;

    reg [6:0] r_prev_second;
    reg r_prev_dismiss;

    wire w_dismiss_rise = dismiss_btn && !r_prev_dismiss;
    wire w_second_tick = (rtc_second[6:0] != r_prev_second);
    wire w_time_slot_match = (rtc_hour == r_alarm_hour) && (rtc_minute == r_alarm_minute);

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            r_alarm_hour <= 8'h07;
            r_alarm_minute <= 8'h00;
            r_alarm_enable <= 1'b0;

            r_prev_second <= 7'd0;
            r_prev_dismiss <= 1'b0;

            alarm_active <= 1'b0;
            buzzer_on <= 1'b0;
            alarm_triggered <= 1'b0;
        end else begin
            r_prev_second <= rtc_second[6:0];
            r_prev_dismiss <= dismiss_btn;

            if (alarm_update_pulse) begin
                r_alarm_hour <= alarm_hour_cfg;
                r_alarm_minute <= alarm_minute_cfg;
            end
            r_alarm_enable <= alarm_enable_cfg;

            if (w_dismiss_rise)
                alarm_active <= 1'b0;

            if (!r_alarm_enable) begin
                alarm_active <= 1'b0;
                alarm_triggered <= 1'b0;
            end else if (w_second_tick) begin
                if (w_time_slot_match) begin
                    if ((rtc_second[6:0] == 7'd0) && !alarm_triggered) begin
                        alarm_active <= 1'b1;
                        alarm_triggered <= 1'b1;
                    end
                end else begin
                    alarm_triggered <= 1'b0;
                end
            end

            buzzer_on <= alarm_active;
        end
    end

endmodule
