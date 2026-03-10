`timescale 1ns / 1ps

module control_tower(
    input clk,
    input reset,
    input [4:0] btn,         // btn[0] toggles mode
    input [7:0] humidity,    // DHT11 humidity
    input [7:0] temperature, // DHT11 temperature
    output reg [13:0] seg_data,
    output reg [15:0] led,
    output dht_mode
    );

    // Mode definition
    parameter MODE_CLOCK = 1'b0;
    parameter MODE_DHT11 = 1'b1;

    reg r_mode = MODE_CLOCK;
    reg [2:0] r_btn_prev;

    // Local display clock
    reg [31:0] r_tick_cnt;
    reg [4:0] r_hour = 0;
    reg [5:0] r_min = 0;
    reg [5:0] r_sec = 0;

    assign dht_mode = (r_mode == MODE_DHT11);

    // 1) Mode toggle logic (edge detect)
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            r_mode <= MODE_CLOCK;
            r_btn_prev <= 3'b000;
        end else begin
            r_btn_prev <= btn;
            if (btn[0] && !r_btn_prev[0]) begin
                r_mode <= ~r_mode;
            end
        end
    end

    // 2) HH:MM:SS counter (1 second tick)
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            r_tick_cnt <= 0;
            r_hour <= 0;
            r_min <= 0;
            r_sec <= 0;
        end else begin
            if (r_tick_cnt >= 100_000_000 - 1) begin
                r_tick_cnt <= 0;
                if (r_sec >= 59) begin
                    r_sec <= 0;
                    if (r_min >= 59) begin
                        r_min <= 0;
                        if (r_hour >= 23)
                            r_hour <= 0;
                        else
                            r_hour <= r_hour + 1;
                    end else begin
                        r_min <= r_min + 1;
                    end
                end else begin
                    r_sec <= r_sec + 1;
                end
            end else begin
                r_tick_cnt <= r_tick_cnt + 1;
            end
        end
    end

    // 3) FND output selection
    always @(*) begin
        led = 16'h0000;
        if (r_mode == MODE_CLOCK) begin
            // Clock mode: HHMM
            seg_data = (r_hour * 14'd100) + r_min;
            led[0] = 1'b1;
        end else begin
            // DHT mode: HHTT (unchanged)
            seg_data = (humidity * 14'd100) + temperature;
            led[1] = 1'b1;
        end
    end

endmodule
