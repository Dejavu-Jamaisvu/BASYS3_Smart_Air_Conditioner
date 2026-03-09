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
    wire w_tick_1ms; //FND 스캔
    wire w_tick_50ms; //FND 애니메이션
    wire w_tick_1s; //DHT11 측정 start




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

    // 온습도 10초 카운터 수정 (첫 즉시 실행 버전)
    reg [4:0] count_20s; 
    reg tick_20s_reg;

    always @(posedge clk or posedge reset) begin
        if(reset) begin
            // 핵심: 초기값을 9로 설정하면 1초 틱이 오자마자 첫 측정이 시작됩니다!
            count_20s <= 19; 
            tick_20s_reg <= 0;
        end else if(w_tick_1s) begin
            if(count_20s == 19) begin
                count_20s <= 0;
                tick_20s_reg <= 1;  // 즉시 실행 신호 발사!
            end else begin
                count_20s <= count_20s + 1;
                tick_20s_reg <= 0;
            end
        end else begin
            tick_20s_reg <= 0;
        end
    end



    dht11_controller u_dht11_controller(
        .clk(clk),
        .reset(reset),
        // .start(w_clean_btn[0]),
        .start(tick_20s_reg), // 20초마다
        .dht_data(dht_data),
        .humidity(w_humidity),
        .temperature(w_temp),
        .data_valid(w_dht_valid)
    );

    reg dht_valid_prev;
    wire w_uart_trigger;

    always @(posedge clk or posedge reset) begin
        if(reset) dht_valid_prev <= 0;
        else dht_valid_prev <= w_dht_valid;
    end

    assign w_uart_trigger = (w_dht_valid && !dht_valid_prev);    

    uart_controller u_uart_controller(
        .clk(clk),
        .reset(reset),
        .send_data({w_temp, w_humidity}),
        .start_trigger(w_uart_trigger), // tick_20s_reg , w_dht_valid 지금현재값 한번만 출력
        .rx(RsRx),
        .tx(RsTx),
        .rx_data(w_rx_data),
        .rx_done(w_rx_done)
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

    tick_generator #(.TICK_Hz(1)) u_tick_1s (
        .clk(clk),
        .reset(reset),
        .tick(w_tick_1s)
    );
    
    assign uartTx = RsTx; // 오실로스크프  측정 단자  
    assign uartRx = RsRx;






    //---아래 디버깅용---
    reg led_toggle;

    always @(posedge clk or posedge reset) begin
        if(reset)
            led_toggle <= 0;
        else if(w_tick_1s)
            led_toggle <= ~led_toggle;
    end


    reg led_valid_toggle;

    always @(posedge clk or posedge reset) begin
        if(reset) led_valid_toggle <= 0;
        else if(w_dht_valid) // 측정이 성공할 때마다
            led_valid_toggle <= ~led_valid_toggle; // 상태를 반전시킴
    end

    assign led[15] = led_valid_toggle; // 성공할 때마다 LED가 켜졌다~ 꺼졌다~ 함
    //assign led[15] = w_dht_valid; //DHT11 읽기 성공 1초마다 깜빡임

    // assign led[14] = w_tick_1s;
    assign led[14] = led_toggle;

    assign led[13] = dht_data;

endmodule
