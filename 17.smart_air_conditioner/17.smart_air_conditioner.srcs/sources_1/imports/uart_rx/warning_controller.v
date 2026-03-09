`timescale 1ns / 1ps

module warning_controller(
    input clk,
    input reset,
    input [7:0] fault_flags,
    input cancel_btn,

    output reg warning_active,
    output reg warning_buzzer_on
    );

    reg r_prev_cancel;
    reg r_buzzer_muted;

    wire w_has_fault = |fault_flags;
    wire w_cancel_rise = cancel_btn && !r_prev_cancel;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            r_prev_cancel <= 1'b0;
            r_buzzer_muted <= 1'b0;
            warning_active <= 1'b0;
            warning_buzzer_on <= 1'b0;
        end else begin
            r_prev_cancel <= cancel_btn;
            warning_active <= w_has_fault;

            if (!w_has_fault) begin
                r_buzzer_muted <= 1'b0;
                warning_buzzer_on <= 1'b0;
            end else begin
                if (w_cancel_rise)
                    r_buzzer_muted <= ~r_buzzer_muted;

                warning_buzzer_on <= !r_buzzer_muted;
            end
        end
    end

endmodule
