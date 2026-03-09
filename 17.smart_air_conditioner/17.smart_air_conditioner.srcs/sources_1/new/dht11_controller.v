`timescale 1ns / 1ps

module dht11_controller(
    input clk,
    input reset,
    input start,
    inout dht_data,
    output reg [7:0] humidity,
    output reg [7:0] temperature,
    output reg data_valid
);

localparam IDLE            = 3'd0;
localparam START_LOW       = 3'd1;
localparam START_RELEASE   = 3'd2;
localparam WAIT_RESP_LOW   = 3'd3;
localparam WAIT_RESP_HIGH  = 3'd4;
localparam WAIT_FIRST_LOW  = 3'd5;
localparam READ_DATA       = 3'd6;
localparam DONE            = 3'd7;

localparam [31:0] START_LOW_US        = 32'd18_000;
localparam [31:0] RELEASE_WAIT_US     = 32'd30;
localparam [31:0] RESPONSE_TIMEOUT_US = 32'd200;
localparam [31:0] BIT_HIGH_TIMEOUT_US = 32'd120;

reg [2:0] state;
reg [31:0] timer;
reg [5:0] bit_cnt;
reg [39:0] data_shift;

reg data_out;
reg data_dir;

assign dht_data = data_dir ? data_out : 1'bz;

reg data_sync0;
reg data_sync1;
wire data_in = data_sync1;

wire [7:0] checksum_calc = data_shift[39:32] + data_shift[31:24]
                         + data_shift[23:16] + data_shift[15:8];
wire checksum_ok = (checksum_calc == data_shift[7:0]);

reg [6:0] us_cnt;
reg tick_1us;

always @(posedge clk or posedge reset) begin
    if (reset) begin
        us_cnt <= 7'd0;
        tick_1us <= 1'b0;
    end else begin
        if (us_cnt == 7'd99) begin
            us_cnt <= 7'd0;
            tick_1us <= 1'b1;
        end else begin
            us_cnt <= us_cnt + 7'd1;
            tick_1us <= 1'b0;
        end
    end
end

always @(posedge clk or posedge reset) begin
    if (reset) begin
        data_sync0 <= 1'b1;
        data_sync1 <= 1'b1;
    end else begin
        data_sync0 <= dht_data;
        data_sync1 <= data_sync0;
    end
end

always @(posedge clk or posedge reset) begin
    if (reset) begin
        state <= IDLE;
        timer <= 32'd0;
        bit_cnt <= 6'd0;
        data_shift <= 40'd0;
        humidity <= 8'd0;
        temperature <= 8'd0;
        data_valid <= 1'b0;
        data_dir <= 1'b0;
        data_out <= 1'b1;
    end else begin
        // Generate a single-cycle pulse only when a frame is valid.
        data_valid <= 1'b0;

        case (state)
            IDLE: begin
                if (start) begin
                    state <= START_LOW;
                    timer <= 32'd0;
                    bit_cnt <= 6'd0;
                    data_shift <= 40'd0;
                    data_dir <= 1'b1;
                    data_out <= 1'b0;
                end
            end

            START_LOW: begin
                if (tick_1us) begin
                    timer <= timer + 32'd1;
                end
                if (timer >= START_LOW_US) begin
                    timer <= 32'd0;
                    data_out <= 1'b1;
                    state <= START_RELEASE;
                end
            end

            START_RELEASE: begin
                data_dir <= 1'b0;
                if (tick_1us) begin
                    timer <= timer + 32'd1;
                end
                if (timer >= RELEASE_WAIT_US) begin
                    timer <= 32'd0;
                    state <= WAIT_RESP_LOW;
                end
            end

            WAIT_RESP_LOW: begin
                if (data_in == 1'b0) begin
                    timer <= 32'd0;
                    state <= WAIT_RESP_HIGH;
                end else if (tick_1us) begin
                    if (timer >= RESPONSE_TIMEOUT_US) begin
                        state <= IDLE;
                    end else begin
                        timer <= timer + 32'd1;
                    end
                end
            end

            WAIT_RESP_HIGH: begin
                if (data_in == 1'b1) begin
                    timer <= 32'd0;
                    state <= WAIT_FIRST_LOW;
                end else if (tick_1us) begin
                    if (timer >= RESPONSE_TIMEOUT_US) begin
                        state <= IDLE;
                    end else begin
                        timer <= timer + 32'd1;
                    end
                end
            end

            WAIT_FIRST_LOW: begin
                if (data_in == 1'b0) begin
                    timer <= 32'd0;
                    bit_cnt <= 6'd0;
                    data_shift <= 40'd0;
                    state <= READ_DATA;
                end else if (tick_1us) begin
                    if (timer >= RESPONSE_TIMEOUT_US) begin
                        state <= IDLE;
                    end else begin
                        timer <= timer + 32'd1;
                    end
                end
            end

            READ_DATA: begin
                if (data_in == 1'b1) begin
                    if (tick_1us) begin
                        if (timer >= BIT_HIGH_TIMEOUT_US) begin
                            state <= IDLE;
                        end else begin
                            timer <= timer + 32'd1;
                        end
                    end
                end else if (timer > 32'd0) begin
                    if (timer > 32'd40) begin
                        data_shift <= {data_shift[38:0], 1'b1};
                    end else begin
                        data_shift <= {data_shift[38:0], 1'b0};
                    end

                    timer <= 32'd0;
                    bit_cnt <= bit_cnt + 6'd1;

                    if (bit_cnt >= 6'd39) begin
                        state <= DONE;
                    end
                end
            end

            DONE: begin
                if (checksum_ok) begin
                    humidity <= data_shift[39:32];
                    temperature <= data_shift[23:16];
                    data_valid <= 1'b1;
                end
                state <= IDLE;
            end

            default: begin
                state <= IDLE;
            end
        endcase
    end
end

endmodule
