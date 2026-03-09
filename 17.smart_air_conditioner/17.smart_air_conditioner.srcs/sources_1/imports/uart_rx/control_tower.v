`timescale 1ns / 1ps

// System mode manager:
// - Default boot mode: RTC/Alarm screen
// - btnL rising edge: toggle RTC <-> DHT display mode
module control_tower(
    input clk,
    input reset,
    input btn_mode,
    output reg dht_mode
    );

    reg r_prev_btn_mode;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            dht_mode <= 1'b0;
            r_prev_btn_mode <= 1'b0;
        end else begin
            if (btn_mode && !r_prev_btn_mode)
                dht_mode <= ~dht_mode;
            r_prev_btn_mode <= btn_mode;
        end
    end

endmodule
