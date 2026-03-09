`timescale 1ns / 1ps

module buzzer_driver(
    input clk,
    input reset,
    input alarm_buzzer_on,
    input warning_buzzer_on,
    output reg buzzer_out
    );

    localparam integer TONE_HALF_PERIOD = 16'd25_000;   // 2kHz tone @ 100MHz
    localparam integer WARN_GATE_TICKS  = 25'd25_000_000; // 250ms on/off

    reg [15:0] r_tone_cnt;
    reg [24:0] r_warn_gate_cnt;
    reg r_warn_gate_on;

    wire w_warning_gated = warning_buzzer_on && r_warn_gate_on;
    wire w_sound_enable = alarm_buzzer_on || w_warning_gated;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            r_tone_cnt <= 16'd0;
            r_warn_gate_cnt <= 25'd0;
            r_warn_gate_on <= 1'b1;
            buzzer_out <= 1'b0;
        end else begin
            if (alarm_buzzer_on) begin
                r_warn_gate_cnt <= 25'd0;
                r_warn_gate_on <= 1'b1;
            end else if (warning_buzzer_on) begin
                if (r_warn_gate_cnt >= (WARN_GATE_TICKS - 1)) begin
                    r_warn_gate_cnt <= 25'd0;
                    r_warn_gate_on <= ~r_warn_gate_on;
                end else begin
                    r_warn_gate_cnt <= r_warn_gate_cnt + 25'd1;
                end
            end else begin
                r_warn_gate_cnt <= 25'd0;
                r_warn_gate_on <= 1'b1;
            end

            if (w_sound_enable) begin
                if (r_tone_cnt >= (TONE_HALF_PERIOD - 1)) begin
                    r_tone_cnt <= 16'd0;
                    buzzer_out <= ~buzzer_out;
                end else begin
                    r_tone_cnt <= r_tone_cnt + 16'd1;
                end
            end else begin
                r_tone_cnt <= 16'd0;
                buzzer_out <= 1'b0;
            end
        end
    end

endmodule
