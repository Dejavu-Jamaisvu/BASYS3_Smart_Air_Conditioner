`timescale 1ns / 1ps

module uart_controller(
    input clk,
    input reset,
    input rx,
    output tx,

    input [7:0] rtc_hour,
    input [7:0] rtc_minute,

    output [7:0] rx_data,
    output rx_done
    );

    wire w_tx_busy;
    wire w_tx_done;
    wire w_tx_start;
    wire [7:0] w_tx_data;

    rtc_time_sender u_rtc_time_sender(
        .clk(clk),
        .reset(reset),
        .rtc_hour(rtc_hour),
        .rtc_minute(rtc_minute),
        .tx_busy(w_tx_busy),
        .tx_done(w_tx_done),
        .tx_start(w_tx_start),
        .tx_data(w_tx_data)
    );

    uart_tx #(
        .BPS(9600)
    ) u_uart_tx(
        .clk(clk),
        .reset(reset),
        .tx_data(w_tx_data),
        .tx_start(w_tx_start),
        .tx(tx),
        .tx_done(w_tx_done),
        .tx_busy(w_tx_busy)
    );

    uart_rx #(
        .BPS(9600)
    ) u_uart_rx(
        .clk(clk),
        .reset(reset),
        .rx(rx),
        .data_out(rx_data),
        .rx_done(rx_done)
    );

endmodule
