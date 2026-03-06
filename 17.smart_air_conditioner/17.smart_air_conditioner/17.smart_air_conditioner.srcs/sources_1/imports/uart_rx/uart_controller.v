`timescale 1ns / 1ps

module uart_controller(
    input clk,
    input reset,
    input [7:0] send_data,
    input rx,
    output tx,
    output [7:0] rx_data,
    output rx_done
    );


    wire w_tick_1Hz;
    wire w_tx_busy, w_tx_done, w_tx_start;
    wire [7:0] w_tx_data; 

    tick_generator # (
        .INPUT_FREQUENCY(100_000_000),   // 100MHz
        .TICK_Hz(1)   // 1Hz
    ) u_tick_generator (
        .clk(clk),
        .reset(reset),
        .tick(w_tick_1Hz)
        );

    
    data_sender u_data_sender(
        .clk(clk),
        .reset(reset),
        .start_trigger(w_tick_1Hz),
        .send_data(send_data),   // 1 byte
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
    ) u_uart_rx (
        .clk(clk),
        .reset(reset),
        .rx(rx),
        .data_out(rx_data),
        .rx_done(rx_done)
    );

endmodule
