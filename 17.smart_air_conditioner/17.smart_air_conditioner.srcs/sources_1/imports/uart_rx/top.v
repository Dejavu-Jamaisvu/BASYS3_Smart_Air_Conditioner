`timescale 1ns / 1ps

module top(
    input clk,
    input reset,

    input [2:0] btn,
    input [7:0] sw,
    input [7:0] fault_flags,

    input RsRx,
    output RsTx,

    input s1,
    input s2,
    input key,

    inout dht_data,

    output [7:0] seg,
    output [3:0] an,
    output [15:0] led,

    output uartTx,
    output uartRx,

    output rtc_ce,
    output rtc_sclk,
    inout rtc_io,

    output buzzer_out
    );

    wire [2:0] w_clean_btn;
    wire w_clean_s1;
    wire w_clean_s2;
    wire w_clean_key;

    wire w_dht_mode;

    wire [7:0] w_rx_data;
    wire w_rx_done;

    wire w_uart_set_valid;
    wire [7:0] w_uart_year;
    wire [7:0] w_uart_month;
    wire [7:0] w_uart_date;
    wire [7:0] w_uart_hour;
    wire [7:0] w_uart_minute;
    wire [7:0] w_uart_second;

    wire w_rot_set_valid;
    wire [7:0] w_rot_set_year;
    wire [7:0] w_rot_set_month;
    wire [7:0] w_rot_set_date;
    wire [7:0] w_rot_set_hour;
    wire [7:0] w_rot_set_minute;
    wire [7:0] w_rot_set_second;

    wire w_edit_mode;
    wire w_edit_field;
    wire w_edit_alarm_mode;
    wire [7:0] w_edit_hour;
    wire [7:0] w_edit_minute;

    wire w_alarm_enable_cfg;
    wire [7:0] w_alarm_hour_cfg;
    wire [7:0] w_alarm_minute_cfg;
    wire w_alarm_update_pulse;

    wire [7:0] w_rtc_year;
    wire [7:0] w_rtc_month;
    wire [7:0] w_rtc_date;
    wire [7:0] w_rtc_hour;
    wire [7:0] w_rtc_minute;
    wire [7:0] w_rtc_second;

    wire w_alarm_active;
    wire w_alarm_buzzer_on;
    wire w_alarm_triggered;

    wire w_warning_active;
    wire w_warning_buzzer_on;

    wire [7:0] w_humidity_raw;
    wire [7:0] w_temperature_raw;
    wire w_dht_valid;
    reg [7:0] r_humidity;
    reg [7:0] r_temperature;

    wire [13:0] w_seg_data;
    wire [3:0]  w_seg_blank;

    wire w_tick_1ms;
    wire w_tick_50ms;

    wire w_set_valid;
    wire [7:0] w_set_year;
    wire [7:0] w_set_month;
    wire [7:0] w_set_date;
    wire [7:0] w_set_hour;
    wire [7:0] w_set_minute;
    wire [7:0] w_set_second;

    btn_debouncer u_btn_debouncer(
        .clk(clk),
        .reset(reset),
        .btn(btn),
        .debounced_btn(w_clean_btn)
    );

    // Rotary A/B should be lightly debounced so short transitions are not lost.
    debouncer #(.DEBOUNCE_LIMIT(20'd99_999)) u_deb_s1 (
        .clk(clk),
        .reset(reset),
        .noisy_btn(s1),
        .clean_btn(w_clean_s1)
    );

    debouncer #(.DEBOUNCE_LIMIT(20'd99_999)) u_deb_s2 (
        .clk(clk),
        .reset(reset),
        .noisy_btn(s2),
        .clean_btn(w_clean_s2)
    );

    debouncer u_deb_key (
        .clk(clk),
        .reset(reset),
        .noisy_btn(key),
        .clean_btn(w_clean_key)
    );

    control_tower u_control_tower(
        .clk(clk),
        .reset(reset),
        .btn_mode(w_clean_btn[0]),
        .dht_mode(w_dht_mode)
    );

    uart_controller u_uart_controller(
        .clk(clk),
        .reset(reset),
        .rx(RsRx),
        .tx(RsTx),
        .rtc_hour(w_rtc_hour),
        .rtc_minute(w_rtc_minute),
        .rx_data(w_rx_data),
        .rx_done(w_rx_done)
    );

    rtc_command_parser u_rtc_cmd_parser(
        .clk(clk),
        .reset(reset),
        .rx_data(w_rx_data),
        .rx_done(w_rx_done),
        .set_time_valid(w_uart_set_valid),
        .out_year(w_uart_year),
        .out_month(w_uart_month),
        .out_date(w_uart_date),
        .out_hour(w_uart_hour),
        .out_minute(w_uart_minute),
        .out_second(w_uart_second)
    );

    rotary_time_setter u_rotary_setter(
        .clk(clk),
        .reset(reset),
        .dht_mode(w_dht_mode),
        .rot_a(w_clean_s1),
        .rot_b(w_clean_s2),
        .rot_sw(w_clean_key),
        .alarm_mode_btn(w_clean_btn[1]),
        .dismiss_btn(w_clean_btn[2]),
        .rtc_year(w_rtc_year),
        .rtc_month(w_rtc_month),
        .rtc_date(w_rtc_date),
        .rtc_hour(w_rtc_hour),
        .rtc_minute(w_rtc_minute),
        .edit_mode(w_edit_mode),
        .edit_field(w_edit_field),
        .edit_alarm_mode(w_edit_alarm_mode),
        .edit_hour(w_edit_hour),
        .edit_minute(w_edit_minute),
        .set_time_valid(w_rot_set_valid),
        .set_year(w_rot_set_year),
        .set_month(w_rot_set_month),
        .set_date(w_rot_set_date),
        .set_hour(w_rot_set_hour),
        .set_minute(w_rot_set_minute),
        .set_second(w_rot_set_second),
        .alarm_enable_cfg(w_alarm_enable_cfg),
        .alarm_hour_cfg(w_alarm_hour_cfg),
        .alarm_minute_cfg(w_alarm_minute_cfg),
        .alarm_update_pulse(w_alarm_update_pulse)
    );

    assign w_set_valid  = w_rot_set_valid | w_uart_set_valid;
    assign w_set_year   = w_rot_set_valid ? w_rot_set_year   : w_uart_year;
    assign w_set_month  = w_rot_set_valid ? w_rot_set_month  : w_uart_month;
    assign w_set_date   = w_rot_set_valid ? w_rot_set_date   : w_uart_date;
    assign w_set_hour   = w_rot_set_valid ? w_rot_set_hour   : w_uart_hour;
    assign w_set_minute = w_rot_set_valid ? w_rot_set_minute : w_uart_minute;
    assign w_set_second = w_rot_set_valid ? w_rot_set_second : w_uart_second;

    ds1302_rtc u_ds1302_rtc(
        .clk(clk),
        .reset(reset),
        .set_time_valid(w_set_valid),
        .set_year(w_set_year),
        .set_month(w_set_month),
        .set_date(w_set_date),
        .set_hour(w_set_hour),
        .set_minute(w_set_minute),
        .set_second(w_set_second),
        .r_year(w_rtc_year),
        .r_month(w_rtc_month),
        .r_date(w_rtc_date),
        .r_hour(w_rtc_hour),
        .r_minute(w_rtc_minute),
        .r_second(w_rtc_second),
        .rtc_ce(rtc_ce),
        .rtc_sclk(rtc_sclk),
        .rtc_io(rtc_io)
    );

    alarm_controller u_alarm_controller(
        .clk(clk),
        .reset(reset),
        .rtc_hour(w_rtc_hour),
        .rtc_minute(w_rtc_minute),
        .rtc_second(w_rtc_second),
        .alarm_enable_cfg(w_alarm_enable_cfg),
        .alarm_hour_cfg(w_alarm_hour_cfg),
        .alarm_minute_cfg(w_alarm_minute_cfg),
        .alarm_update_pulse(w_alarm_update_pulse),
        .dismiss_btn(w_clean_btn[2]),
        .alarm_active(w_alarm_active),
        .buzzer_on(w_alarm_buzzer_on),
        .alarm_triggered(w_alarm_triggered)
    );

    warning_controller u_warning_controller(
        .clk(clk),
        .reset(reset),
        .fault_flags(fault_flags),
        .cancel_btn(w_clean_btn[1]),
        .warning_active(w_warning_active),
        .warning_buzzer_on(w_warning_buzzer_on)
    );

    buzzer_driver u_buzzer_driver(
        .clk(clk),
        .reset(reset),
        .alarm_buzzer_on(w_alarm_buzzer_on),
        .warning_buzzer_on(w_warning_buzzer_on),
        .buzzer_out(buzzer_out)
    );

    dht11_controller u_dht11_controller(
        .clk(clk),
        .reset(reset),
        .start(w_tick_50ms),
        .dht_data(dht_data),
        .humidity(w_humidity_raw),
        .temperature(w_temperature_raw),
        .data_valid(w_dht_valid)
    );

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            r_humidity <= 8'd0;
            r_temperature <= 8'd0;
        end else if (w_dht_valid) begin
            r_humidity <= w_humidity_raw;
            r_temperature <= w_temperature_raw;
        end
    end

    rtc_display u_rtc_display(
        .clk(clk),
        .reset(reset),
        .dht_mode(w_dht_mode),
        .edit_mode(w_edit_mode),
        .edit_alarm_mode(w_edit_alarm_mode),
        .edit_field(w_edit_field),
        .rtc_hour(w_rtc_hour),
        .rtc_minute(w_rtc_minute),
        .edit_hour(w_edit_hour),
        .edit_minute(w_edit_minute),
        .alarm_hour(w_alarm_hour_cfg),
        .alarm_minute(w_alarm_minute_cfg),
        .humidity(r_humidity),
        .temperature(r_temperature),
        .seg_data(w_seg_data),
        .seg_blank(w_seg_blank)
    );

    fnd_controller u_fnd_controller(
        .clk(clk),
        .reset(reset),
        .tick_1ms(w_tick_1ms),
        .tick_50ms(w_tick_50ms),
        .circle_mode(1'b0),
        .in_data(w_seg_data),
        .blank_mask(w_seg_blank),
        .an(an),
        .seg(seg)
    );

    tick_generator #(.TICK_Hz(1000)) u_tick_1ms (
        .clk(clk),
        .reset(reset),
        .tick(w_tick_1ms)
    );

    tick_generator #(.TICK_Hz(20)) u_tick_50ms (
        .clk(clk),
        .reset(reset),
        .tick(w_tick_50ms)
    );

    assign led = 16'h0000;

    assign uartTx = RsTx;
    assign uartRx = RsRx;

    // Keep currently unused inputs referenced to avoid optimization warnings.
    wire [7:0] _unused_sw = sw;

endmodule
