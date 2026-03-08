`timescale 1ns / 1ps

module dht11_controller(
    input clk,
    input reset,
    input start,            // 측정 시작

    inout dht_data,         // DHT11 DATA

    output reg [7:0] humidity,
    output reg [7:0] temperature,
    output reg data_valid
);

parameter IDLE            = 3'd0;
parameter START_LOW       = 3'd1;
parameter START_RELEASE   = 3'd2;
parameter WAIT_RESP_LOW   = 3'd3;
parameter WAIT_RESP_HIGH  = 3'd4;
parameter READ_DATA       = 3'd5;
parameter DONE            = 3'd6;

reg [2:0] state;

reg [31:0] timer;
reg [5:0] bit_cnt;

reg [39:0] data_shift;

reg data_out;
reg data_dir;

assign dht_data = data_dir ? data_out : 1'bz;
wire data_in = dht_data;


reg [6:0] us_cnt;
reg tick_1us;

always @(posedge clk or posedge reset) begin
    if(reset) begin
        us_cnt <= 0;
        tick_1us <= 0;
    end
    else begin
        if(us_cnt == 99) begin
            us_cnt <= 0;
            tick_1us <= 1;
        end
        else begin
            us_cnt <= us_cnt + 1;
            tick_1us <= 0;
        end
    end
end


always @(posedge clk or posedge reset) begin
    if(reset) begin
        state <= IDLE;
        timer <= 0;
        bit_cnt <= 0;
        data_shift <= 0;
        humidity <= 0;
        temperature <= 0;
        data_valid <= 0;
        data_dir <= 0;
        data_out <= 1;
    end

    else begin

        case(state)


        IDLE:
        begin
            data_valid <= 0;
            if(start) begin
                state <= START_LOW;
                timer <= 0;
                data_dir <= 1;
                data_out <= 0;
            end
        end


        START_LOW:
        begin
            if(tick_1us)
                timer <= timer + 1;

            if(timer >= 18000) begin
                timer <= 0;
                data_out <= 1;
                state <= START_RELEASE;
            end
        end

        START_RELEASE:
        begin
            data_dir <= 0;

            if(tick_1us)
                timer <= timer + 1;

            if(timer >= 30) begin
                timer <= 0;
                state <= WAIT_RESP_LOW;
            end
        end


        WAIT_RESP_LOW:
        begin
            if(data_in == 0)
                state <= WAIT_RESP_HIGH;
        end

        WAIT_RESP_HIGH:
        begin
            if(data_in == 1) begin
                bit_cnt <= 0;
                state <= READ_DATA;
            end
        end


        READ_DATA:
        begin
            if(data_in == 1) begin

                if(tick_1us)
                    timer <= timer + 1;

            end
            else begin

                if(timer > 40)
                    data_shift <= {data_shift[38:0],1'b1};
                else
                    data_shift <= {data_shift[38:0],1'b0};

                timer <= 0;
                bit_cnt <= bit_cnt + 1;

                if(bit_cnt == 39)
                    state <= DONE;
            end
        end


        DONE:
        begin
            humidity <= data_shift[39:32];
            temperature <= data_shift[23:16];

            data_valid <= 1;
            state <= IDLE;
        end

        endcase

    end
end

endmodule