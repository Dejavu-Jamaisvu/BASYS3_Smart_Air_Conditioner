`timescale 1ns / 1ps

module top(
    input clk,
    input reset,
    input [2:0]  btn,
    input [7:0] sw,
    input RsRx,    // UART rx
    output RsTx,   // UART tx
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
        .sw(sw),
        .rx_data(w_rx_data),   // UART 8 bits
        .rx_done(w_rx_done),    // 8bit data reached : 1
        .seg_data(w_seg_data),
        .led(led)
    );

    uart_controller u_uart_controller(
        .clk(clk),
        .reset(reset),
        .send_data(sw),  // '0' : temp  
        .rx(RsRx),
        .tx(RsTx),
        .rx_data(w_rx_data),
        .rx_done(w_rx_done)
    );
    
    assign uartTx = RsTx; // 오실로스크프  측정 단자  
    assign uartRx = RsRx;
endmodule
