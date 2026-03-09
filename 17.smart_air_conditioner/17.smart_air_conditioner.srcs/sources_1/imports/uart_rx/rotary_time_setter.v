`timescale 1ns / 1ps

module rotary_time_setter(
    input clk,
    input reset,

    input dht_mode,
    input rot_a,
    input rot_b,
    input rot_sw,
    input alarm_mode_btn,
    input dismiss_btn,

    input [7:0] rtc_year,
    input [7:0] rtc_month,
    input [7:0] rtc_date,
    input [7:0] rtc_hour,
    input [7:0] rtc_minute,

    output reg edit_mode,
    output reg edit_field,      // 0: hour, 1: minute
    output reg edit_alarm_mode, // 0: time edit, 1: alarm edit

    output reg [7:0] edit_hour,
    output reg [7:0] edit_minute,

    output reg set_time_valid,
    output reg [7:0] set_year,
    output reg [7:0] set_month,
    output reg [7:0] set_date,
    output reg [7:0] set_hour,
    output reg [7:0] set_minute,
    output reg [7:0] set_second,

    output reg alarm_enable_cfg,
    output reg [7:0] alarm_hour_cfg,
    output reg [7:0] alarm_minute_cfg,
    output reg alarm_update_pulse
    );

    // Basys3 rotary push switch is pulled-up on many boards, so press = low.
    localparam ROT_SW_ACTIVE_LOW = 1'b1;

    // FSM: IDLE → ALARM_HOUR (HH blinks) → ALARM_MIN (MM blinks) → IDLE (save alarm)
    localparam [1:0] ST_IDLE       = 2'd0;
    localparam [1:0] ST_ALARM_HOUR = 2'd1;   // editing alarm hour   → HH digits blink
    localparam [1:0] ST_ALARM_MIN  = 2'd2;   // editing alarm minute → MM digits blink

    reg [1:0] r_state;

    reg [1:0] r_prev_ab;
    reg [1:0] r_curr_ab;
    reg r_prev_sw;
    reg r_prev_alarm_btn;
    reg r_prev_dismiss;

    reg r_step_cw;
    reg r_step_ccw;
    reg r_sw_click;

    function [7:0] bcd_to_bin;
        input [7:0] bcd;
        begin
            bcd_to_bin = (bcd[7:4] * 8'd10) + bcd[3:0];
        end
    endfunction

    function [7:0] bin_to_bcd;
        input [7:0] bin;
        begin
            bin_to_bcd = ((bin / 8'd10) << 4) | (bin % 8'd10);
        end
    endfunction

    function [7:0] bcd_inc_wrap;
        input [7:0] bcd;
        input [7:0] max_val;
        reg [7:0] v;
        begin
            v = bcd_to_bin(bcd);
            if (v >= max_val)
                v = 8'd0;
            else
                v = v + 8'd1;
            bcd_inc_wrap = bin_to_bcd(v);
        end
    endfunction

    function [7:0] bcd_dec_wrap;
        input [7:0] bcd;
        input [7:0] max_val;
        reg [7:0] v;
        begin
            v = bcd_to_bin(bcd);
            if (v == 8'd0)
                v = max_val;
            else
                v = v - 8'd1;
            bcd_dec_wrap = bin_to_bcd(v);
        end
    endfunction

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            r_state <= ST_IDLE;

            r_prev_ab <= 2'b00;
            r_curr_ab <= 2'b00;
            r_prev_sw <= 1'b0;
            r_prev_alarm_btn <= 1'b0;
            r_prev_dismiss <= 1'b0;
            r_step_cw <= 1'b0;
            r_step_ccw <= 1'b0;
            r_sw_click <= 1'b0;

            edit_mode <= 1'b0;
            edit_field <= 1'b0;
            edit_alarm_mode <= 1'b0;

            edit_hour <= 8'h00;
            edit_minute <= 8'h00;

            set_time_valid <= 1'b0;
            set_year <= 8'h00;
            set_month <= 8'h01;
            set_date <= 8'h01;
            set_hour <= 8'h00;
            set_minute <= 8'h00;
            set_second <= 8'h00;

            // Alarm config defaults
            alarm_enable_cfg <= 1'b0;
            alarm_hour_cfg <= 8'h07;
            alarm_minute_cfg <= 8'h00;
            alarm_update_pulse <= 1'b0;
        end else begin
            set_time_valid <= 1'b0;
            alarm_update_pulse <= 1'b0;

            r_curr_ab = {rot_a, rot_b};
            r_step_cw = 1'b0;
            r_step_ccw = 1'b0;
            r_sw_click = 1'b0;

            if (ROT_SW_ACTIVE_LOW) begin
                if (!rot_sw && r_prev_sw)
                    r_sw_click = 1'b1; // falling edge = pressed
            end else begin
                if (rot_sw && !r_prev_sw)
                    r_sw_click = 1'b1; // rising edge = pressed
            end

            case ({r_prev_ab, r_curr_ab})
                4'b0001, 4'b0111, 4'b1110, 4'b1000: r_step_cw = 1'b1;
                4'b0010, 4'b1011, 4'b1101, 4'b0100: r_step_ccw = 1'b1;
                default: begin
                    r_step_cw = 1'b0;
                    r_step_ccw = 1'b0;
                end
            endcase

            if (dht_mode) begin
                r_state <= ST_IDLE;
                edit_mode <= 1'b0;
                edit_field <= 1'b0;
                edit_alarm_mode <= 1'b0;
            end else begin
                case (r_state)
                    // ──────────────────────────────────────────────────
                    ST_IDLE: begin
                        edit_mode       <= 1'b0;
                        edit_field      <= 1'b0;
                        edit_alarm_mode <= 1'b0;

                        // Rotary key press → enter alarm time edit mode
                        if (r_sw_click) begin
                            r_state         <= ST_ALARM_HOUR;
                            edit_mode       <= 1'b1;
                            edit_alarm_mode <= 1'b1;
                            edit_field      <= 1'b0;   // HH blinks first
                            // Pre-load previously saved alarm time
                            edit_hour   <= alarm_hour_cfg;
                            edit_minute <= alarm_minute_cfg;
                        end
                    end

                    // ──────────────────────────────────────────────────
                    // ALARM HOUR: HH digits blink, rotate to change alarm hour
                    ST_ALARM_HOUR: begin
                        edit_mode  <= 1'b1;
                        edit_field <= 1'b0;            // blink HH

                        if (r_step_cw)
                            edit_hour <= bcd_inc_wrap(edit_hour, 8'd23);
                        else if (r_step_ccw)
                            edit_hour <= bcd_dec_wrap(edit_hour, 8'd23);

                        // Key press → advance to minute field
                        if (r_sw_click) begin
                            r_state    <= ST_ALARM_MIN;
                            edit_field <= 1'b1;        // MM will blink
                        end
                    end

                    // ──────────────────────────────────────────────────
                    // ALARM MIN: MM digits blink, rotate to change alarm minute
                    ST_ALARM_MIN: begin
                        edit_mode  <= 1'b1;
                        edit_field <= 1'b1;            // blink MM

                        if (r_step_cw)
                            edit_minute <= bcd_inc_wrap(edit_minute, 8'd59);
                        else if (r_step_ccw)
                            edit_minute <= bcd_dec_wrap(edit_minute, 8'd59);

                        // Key press → save alarm and return to normal display
                        if (r_sw_click) begin
                            r_state          <= ST_IDLE;
                            edit_mode        <= 1'b0;
                            edit_field       <= 1'b0;
                            edit_alarm_mode  <= 1'b0;
                            alarm_hour_cfg   <= edit_hour;
                            alarm_minute_cfg <= edit_minute;
                            alarm_enable_cfg <= 1'b1;
                            alarm_update_pulse <= 1'b1;   // one-cycle pulse to alarm_controller
                        end
                    end

                    default: begin
                        r_state         <= ST_IDLE;
                        edit_mode       <= 1'b0;
                        edit_field      <= 1'b0;
                        edit_alarm_mode <= 1'b0;
                    end
                endcase
            end

            r_prev_ab <= r_curr_ab;
            r_prev_sw <= rot_sw;
            r_prev_alarm_btn <= alarm_mode_btn;
            r_prev_dismiss <= dismiss_btn;
        end
    end

endmodule
