`timescale 1ns / 1ps

module top(
    input clk,
    input reset,

    input [2:0] btn,
    input [7:0] sw,
    input [7:0] fault_flags,

    input RsRx,   // UART RX
    output RsTx,  // UART TX

    inout dht_data,

    output rtc_ce,
    output rtc_sclk,
    inout rtc_io,

    input s1,
    input s2,
    input key,

    output buzzer_out,

    output [7:0] seg,
    output [3:0] an,
    output [15:0] led,
    output uartTx,
    output uartRx
    );

    wire [7:0] w_rx_data;
    wire w_rx_done;

    wire [13:0] w_seg_data;
    wire [3:0] w_seg_blank;
    wire [2:0] w_clean_btn;

    // DHT11 path
    wire [7:0] w_humidity;
    wire [7:0] w_temp;
    wire w_dht_valid;
    wire w_dht_error;    // <--- 이 줄을 추가해야 에러 없이 컴파일됩니다!

    wire w_tick_1ms;
    wire w_tick_50ms;
    wire w_tick_1s;

    // Mode from control_tower
    wire [13:0] w_control_seg_data;
    wire [15:0] w_control_led;
    wire w_dht_mode;

    // RTC time
    wire [7:0] w_rtc_year;
    wire [7:0] w_rtc_month;
    wire [7:0] w_rtc_date;
    wire [7:0] w_rtc_hour;
    wire [7:0] w_rtc_minute;
    wire [7:0] w_rtc_second;

    // UART setrtc parser outputs
    wire w_set_time_uart;
    wire [7:0] w_set_year_uart;
    wire [7:0] w_set_month_uart;
    wire [7:0] w_set_date_uart;
    wire [7:0] w_set_hour_uart;
    wire [7:0] w_set_minute_uart;
    wire [7:0] w_set_second_uart;

    // Rotary editor outputs
    wire w_edit_mode;
    wire w_edit_field;
    wire w_edit_alarm_mode;
    wire [7:0] w_edit_hour;
    wire [7:0] w_edit_minute;

    wire w_set_time_rot;
    wire [7:0] w_set_year_rot;
    wire [7:0] w_set_month_rot;
    wire [7:0] w_set_date_rot;
    wire [7:0] w_set_hour_rot;
    wire [7:0] w_set_minute_rot;
    wire [7:0] w_set_second_rot;

    wire w_alarm_enable_cfg;
    wire [7:0] w_alarm_hour_cfg;
    wire [7:0] w_alarm_minute_cfg;
    wire w_alarm_update_pulse;

    // Alarm/Warning/Buzzer
    wire w_alarm_active;
    wire w_alarm_buzzer_on;
    wire w_alarm_triggered;

    wire w_warning_active;
    wire w_warning_buzzer_on;

    // Muxed RTC set inputs
    wire w_set_time_valid = w_set_time_uart | w_set_time_rot;
    wire [7:0] w_set_year   = w_set_time_uart ? w_set_year_uart   : w_set_year_rot;
    wire [7:0] w_set_month  = w_set_time_uart ? w_set_month_uart  : w_set_month_rot;
    wire [7:0] w_set_date   = w_set_time_uart ? w_set_date_uart   : w_set_date_rot;
    wire [7:0] w_set_hour   = w_set_time_uart ? w_set_hour_uart   : w_set_hour_rot;
    wire [7:0] w_set_minute = w_set_time_uart ? w_set_minute_uart : w_set_minute_rot;
    wire [7:0] w_set_second = w_set_time_uart ? w_set_second_uart : w_set_second_rot;

    btn_debouncer u_btn_debouncer(
        .clk(clk),
        .reset(reset),
        .btn(btn),
        .debounced_btn(w_clean_btn)
    );

    // Keep teammate mode behavior and HHMM display rule in this module.
    control_tower u_control_tower(
        .clk(clk),
        .reset(reset),
        .btn(w_clean_btn),
        .humidity(w_humidity),
        .temperature(w_temp),
        .seg_data(w_control_seg_data),
        .led(w_control_led),
        .dht_mode(w_dht_mode)
    );

    // 온습도 측정 주기를 정의
    parameter UPDATE_PERIOD = 4'd10; 

    reg [3:0] interval_cnt;   // 주기를 카운트하는 변수
    reg trigger_update;       // 센서 및 전송 로직을 깨우는 신호

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            // 리셋 직후 첫 1초 틱에서 바로 작동하도록 설정
            interval_cnt <= UPDATE_PERIOD - 1; 
            trigger_update <= 1'b0;
        end else if (w_tick_1s) begin
            if (interval_cnt >= UPDATE_PERIOD - 1) begin
                interval_cnt <= 4'd0;
                trigger_update <= 1'b1; // 10초가 되면 트리거 발생
            end else begin
                interval_cnt <= interval_cnt + 4'd1;
                trigger_update <= 1'b0;
            end
        end else begin
            trigger_update <= 1'b0; // w_tick_1s가 아닐 때는 항상 0 유지
        end
    end


    dht11_controller u_dht11_controller(
        .clk(clk),
        .reset(reset),
        .start(trigger_update),
        .dht_data(dht_data),
        .humidity(w_humidity),
        .temperature(w_temp),
        .data_valid(w_dht_valid),
        .error(w_dht_error)  // [수정] 에러 신호 연결
    );

    // UART 트리거 로직 수정
    reg dht_valid_prev, dht_error_prev;
    wire w_uart_trigger;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            dht_valid_prev <= 1'b0;
            dht_error_prev <= 1'b0;
        end else begin
            dht_valid_prev <= w_dht_valid;
            dht_error_prev <= w_dht_error;
        end
    end

    // [수정] 데이터가 정상이거나(valid), 에러가 발생했을 때(error) 모두 UART 전송을 시작함
    assign w_uart_trigger = (w_dht_valid && !dht_valid_prev) || (w_dht_error && !dht_error_prev);

    uart_controller u_uart_controller(
        .clk(clk),
        .reset(reset),
        .send_data({w_temp, w_humidity}),
        .start_trigger(w_uart_trigger),
        .error_in(w_dht_error), // [추가] 에러 신호를 UART 컨트롤러에 전달
        .rx(RsRx),
        .tx(RsTx),
        .rx_data(w_rx_data),
        .rx_done(w_rx_done)
    );

    rtc_command_parser u_rtc_command_parser(
        .clk(clk),
        .reset(reset),
        .rx_data(w_rx_data),
        .rx_done(w_rx_done),
        .set_time_valid(w_set_time_uart),
        .out_year(w_set_year_uart),
        .out_month(w_set_month_uart),
        .out_date(w_set_date_uart),
        .out_hour(w_set_hour_uart),
        .out_minute(w_set_minute_uart),
        .out_second(w_set_second_uart)
    );

    rotary_time_setter u_rotary_time_setter(
        .clk(clk),
        .reset(reset),
        .dht_mode(w_dht_mode),
        .rot_a(s1),
        .rot_b(s2),
        .rot_sw(key),
        .alarm_mode_btn(1'b0),
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
        .set_time_valid(w_set_time_rot),
        .set_year(w_set_year_rot),
        .set_month(w_set_month_rot),
        .set_date(w_set_date_rot),
        .set_hour(w_set_hour_rot),
        .set_minute(w_set_minute_rot),
        .set_second(w_set_second_rot),
        .alarm_enable_cfg(w_alarm_enable_cfg),
        .alarm_hour_cfg(w_alarm_hour_cfg),
        .alarm_minute_cfg(w_alarm_minute_cfg),
        .alarm_update_pulse(w_alarm_update_pulse)
    );

    ds1302_rtc u_ds1302_rtc(
        .clk(clk),
        .reset(reset),
        .set_time_valid(w_set_time_valid),
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

    // Display: DHT mode => HHTT, clock mode => RTC HHMM (+ blink in edit mode)
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
        .humidity(w_humidity),
        .temperature(w_temp),
        .seg_data(w_seg_data),
        .seg_blank(w_seg_blank)
    );

    fnd_controller u_fnd_controller(
        .clk(clk),
        .reset(reset),
        .tick_1ms(w_tick_1ms),
        .tick_50ms(w_tick_50ms),
        .circle_mode(sw[7]),
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

    tick_generator #(.TICK_Hz(1)) u_tick_1s (
        .clk(clk),
        .reset(reset),
        .tick(w_tick_1s)
    );

    assign uartTx = RsTx;
    assign uartRx = RsRx;

    // Debug/status LEDs
    reg led_toggle;
    reg led_valid_toggle;

    always @(posedge clk or posedge reset) begin
        if (reset)
            led_toggle <= 1'b0;
        else if (w_tick_1s)
            led_toggle <= ~led_toggle;
    end

    always @(posedge clk or posedge reset) begin
        if (reset)
            led_valid_toggle <= 1'b0;
        else if (w_dht_valid)
            led_valid_toggle <= ~led_valid_toggle;
    end

    assign led[15] = led_valid_toggle;
    assign led[14] = led_toggle;
    assign led[13] = dht_data;
    assign led[12] = w_alarm_active;
    assign led[11] = w_warning_active;
    assign led[10] = w_alarm_triggered;
    assign led[9] = w_dht_mode;
    assign led[8] = w_dht_valid;
    assign led[7:0] = 8'h00;

endmodule
