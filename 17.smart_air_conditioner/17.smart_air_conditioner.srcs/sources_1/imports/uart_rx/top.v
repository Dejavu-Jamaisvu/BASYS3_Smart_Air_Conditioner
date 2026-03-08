`timescale 1ns / 1ps

module top(
    input clk,
    input reset,
    
    input [2:0]  btn,
    input [7:0] sw,
    input RsRx,    // UART rx
    output RsTx,   // UART tx

    inout dht_data,

    output [7:0] seg,
    output [3:0] an,
    output [15:0]  led,
    output uartTx,   // JB1   for 오실로스코프
    output uartRx
    );


    wire [7:0] w_rx_data;
    wire w_rx_done;
    wire [13:0] w_seg_data;
    wire [2:0] w_clean_btn;


    // DHT11 및 FND용 와이어
    wire [7:0] w_humidity, w_temp;
    wire w_dht_valid;
    wire w_tick_1ms, w_tick_50ms;



    btn_debouncer u_btn_debouncer(
        .clk(clk),
        .reset(reset),
        .btn(btn),   // 3개의 버튼 입력: btn[2:0] → 각각 btnL, btnC, btnR
        .debounced_btn(w_clean_btn)
    );

    control_tower u_control_tower(
        .clk(clk),
        .reset(reset),  // sw[15]
        .btn(w_clean_btn),   // btn[0]: btnL btn[1]: btnC btn[2]: btnR
        // .sw(sw),
        // .rx_data(w_rx_data),   // UART 8 bits
        // .rx_done(w_rx_done),    // 8bit data reached : 1
        .humidity(w_humidity),    // dht11_controller에서 나온 와이어
        .temperature(w_temp),     // dht11_controller에서 나온 와이어
        .seg_data(w_seg_data),
        .led(led)
    );

    uart_controller u_uart_controller(
        .clk(clk),
        .reset(reset),
        .send_data(sw),  // 현재 스위치 값을 PC로 전송 [cite: 5]
        .rx(RsRx),
        .tx(RsTx),
        .rx_data(w_rx_data),
        .rx_done(w_rx_done)
    );


    dht11_controller u_dht11_controller(
        .clk(clk),
        .reset(reset),
        .start(w_tick_50ms), // 50ms마다 측정 시작 (또는 별도 타이머 사용 가능)
        .dht_data(dht_data),
        .humidity(w_humidity),
        .temperature(w_temp),
        .data_valid(w_dht_valid)
    );

    fnd_controller u_fnd_controller(
        .clk(clk),
        .reset(reset),
        .tick_1ms(w_tick_1ms),
        .tick_50ms(w_tick_50ms),
        .circle_mode(sw[7]), // 예시: sw[7]이 켜지면 애니메이션 모드 
        .in_data(w_seg_data), 
        .an(an),
        .seg(seg)
    );


    tick_generator #(.TICK_Hz(1000)) u_tick_1ms (
        .clk(clk), .reset(reset), .tick(w_tick_1ms)
    );
    tick_generator #(.TICK_Hz(20)) u_tick_50ms (
        .clk(clk), .reset(reset), .tick(w_tick_50ms)
    );


    
    assign uartTx = RsTx; // 오실로스크프  측정 단자  
    assign uartRx = RsRx;
endmodule
