`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// DS1302 RTC interface
// - Reads current time from DS1302 periodically
// - Writes DS1302 clock registers when set_time_valid pulses
//////////////////////////////////////////////////////////////////////////////////

module ds1302_rtc(
    input clk,
    input reset,
    input set_time_valid,
    input [7:0] set_year,
    input [7:0] set_month,
    input [7:0] set_date,
    input [7:0] set_hour,
    input [7:0] set_minute,
    input [7:0] set_second,

    output reg [7:0] r_year,
    output reg [7:0] r_month,
    output reg [7:0] r_date,
    output reg [7:0] r_hour,
    output reg [7:0] r_minute,
    output reg [7:0] r_second,

    output rtc_ce,
    output rtc_sclk,
    inout rtc_io
    );

    localparam [7:0] CMD_CLOCK_BURST_WRITE = 8'hBE;
    localparam [7:0] CMD_CLOCK_BURST_READ  = 8'hBF;
    localparam [7:0] CMD_WP_WRITE          = 8'h8E;
    localparam [7:0] DATA_WP_DISABLE       = 8'h00;

    localparam integer IO_TICK_DIV = 16'd500;          // 100MHz / 500 = 200kHz service rate
    localparam integer READ_PERIOD = 24'd10_000_000;   // 100ms at 100MHz
    // DS1302 tCC(min) = 4us. Keep CE low for 6us margin between transactions.
    localparam integer CE_GAP_CYCLES = 10'd600;        // 600 * 10ns = 6us

    localparam [5:0] ST_IDLE       = 6'd0;
    localparam [5:0] ST_WP_CMD     = 6'd1;
    localparam [5:0] ST_WP_DATA    = 6'd2;
    localparam [5:0] ST_WP_END      = 6'd3;
    localparam [5:0] ST_WBURST_GAP  = 6'd4;
    localparam [5:0] ST_WBURST_CMD  = 6'd5;
    localparam [5:0] ST_WBURST_D0   = 6'd6;
    localparam [5:0] ST_WBURST_D1   = 6'd7;
    localparam [5:0] ST_WBURST_D2   = 6'd8;
    localparam [5:0] ST_WBURST_D3   = 6'd9;
    localparam [5:0] ST_WBURST_D4   = 6'd10;
    localparam [5:0] ST_WBURST_D5   = 6'd11;
    localparam [5:0] ST_WBURST_D6   = 6'd12;
    localparam [5:0] ST_WBURST_D7   = 6'd13;
    localparam [5:0] ST_WBURST_END  = 6'd14;
    localparam [5:0] ST_RBURST_GAP  = 6'd15;
    localparam [5:0] ST_RBURST_CMD  = 6'd16;
    localparam [5:0] ST_RBURST_D0   = 6'd17;
    localparam [5:0] ST_RBURST_D1   = 6'd18;
    localparam [5:0] ST_RBURST_D2   = 6'd19;
    localparam [5:0] ST_RBURST_D3   = 6'd20;
    localparam [5:0] ST_RBURST_D4   = 6'd21;
    localparam [5:0] ST_RBURST_D5   = 6'd22;
    localparam [5:0] ST_RBURST_D6   = 6'd23;
    localparam [5:0] ST_RBURST_D7   = 6'd24;
    localparam [5:0] ST_RBURST_END  = 6'd25;

    reg [5:0] r_state;

    reg [15:0] r_tick_div;
    reg r_io_tick;
    reg [23:0] r_read_counter;
    reg [9:0] r_gap_cnt;

    reg r_write_pending;
    reg [7:0] r_set_year;
    reg [7:0] r_set_month;
    reg [7:0] r_set_date;
    reg [7:0] r_set_hour;
    reg [7:0] r_set_minute;
    reg [7:0] r_set_second;

    reg [7:0] r_wr_buf [0:7];
    reg [7:0] r_rd_buf [0:7];

    reg r_ce;
    wire w_sclk;
    wire w_io_oe;
    wire w_io_out;
    wire w_io_in;

    reg r_eng_start;
    reg r_eng_read;
    reg [7:0] r_eng_tx_byte;
    wire w_eng_busy;
    wire w_eng_done;
    wire [7:0] w_eng_rx_byte;

    assign rtc_ce = r_ce;
    assign rtc_sclk = w_sclk;
    assign rtc_io = w_io_oe ? w_io_out : 1'bz;
    assign w_io_in = rtc_io;

    ds1302_byte_engine u_byte_engine (
        .clk(clk),
        .reset(reset),
        .io_tick(r_io_tick),
        .start(r_eng_start),
        .is_read(r_eng_read),
        .tx_byte(r_eng_tx_byte),
        .io_in(w_io_in),
        .busy(w_eng_busy),
        .done(w_eng_done),
        .rx_byte(w_eng_rx_byte),
        .sclk(w_sclk),
        .io_oe(w_io_oe),
        .io_out(w_io_out)
    );

    function bcd_nibbles_ok;
        input [7:0] b;
        begin
            bcd_nibbles_ok = (b[7:4] <= 4'd9) && (b[3:0] <= 4'd9);
        end
    endfunction

    function [7:0] bcd_to_bin2;
        input [7:0] b;
        begin
            bcd_to_bin2 = (b[7:4] * 8'd10) + b[3:0];
        end
    endfunction

    function bcd_range_ok;
        input [7:0] b;
        input [7:0] min_v;
        input [7:0] max_v;
        reg [7:0] v;
        begin
            v = bcd_to_bin2(b);
            bcd_range_ok = bcd_nibbles_ok(b) && (v >= min_v) && (v <= max_v);
        end
    endfunction

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            r_tick_div <= 16'd0;
            r_io_tick <= 1'b0;
            r_read_counter <= 24'd0;
            r_gap_cnt <= 10'd0;
            r_state <= ST_IDLE;
            r_ce <= 1'b0;

            r_eng_start <= 1'b0;
            r_eng_read <= 1'b0;
            r_eng_tx_byte <= 8'h00;

            r_write_pending <= 1'b0;
            r_set_year <= 8'h00;
            r_set_month <= 8'h01;
            r_set_date <= 8'h01;
            r_set_hour <= 8'h00;
            r_set_minute <= 8'h00;
            r_set_second <= 8'h00;

            r_year <= 8'h00;
            r_month <= 8'h01;
            r_date <= 8'h01;
            r_hour <= 8'h00;
            r_minute <= 8'h00;
            r_second <= 8'h00;
        end
        else begin
            r_eng_start <= 1'b0;

            if (r_tick_div == (IO_TICK_DIV - 1)) begin
                r_tick_div <= 16'd0;
                r_io_tick <= 1'b1;
            end else begin
                r_tick_div <= r_tick_div + 16'd1;
                r_io_tick <= 1'b0;
            end

            if (set_time_valid) begin
                r_set_year <= set_year;
                r_set_month <= set_month;
                r_set_date <= set_date;
                r_set_hour <= set_hour;
                r_set_minute <= set_minute;
                r_set_second <= {1'b0, set_second[6:0]}; // CH bit must be 0
                r_write_pending <= 1'b1;

                // Reflect requested time immediately on outputs so display/UART
                // update right away even before next burst-read completes.
                r_year   <= set_year;
                r_month  <= set_month;
                r_date   <= set_date;
                r_hour   <= set_hour;
                r_minute <= set_minute;
                r_second <= {1'b0, set_second[6:0]};
            end

            if (r_state == ST_IDLE) begin
                if (r_read_counter == (READ_PERIOD - 1))
                    r_read_counter <= 24'd0;
                else
                    r_read_counter <= r_read_counter + 24'd1;
            end else begin
                r_read_counter <= 24'd0;
            end

            case (r_state)
                ST_IDLE: begin
                    r_ce <= 1'b0;

                    if (r_write_pending) begin
                        r_ce <= 1'b1;
                        r_state <= ST_WP_CMD;
                    end
                    else if (r_read_counter == (READ_PERIOD - 1)) begin
                        r_ce <= 1'b1;
                        r_state <= ST_RBURST_CMD;
                    end
                end

                ST_WP_CMD: begin
                    if (w_eng_done) begin
                        r_state <= ST_WP_DATA;
                    end else if (!w_eng_busy) begin
                        r_eng_read <= 1'b0;
                        r_eng_tx_byte <= CMD_WP_WRITE;
                        r_eng_start <= 1'b1;
                    end
                end

                ST_WP_DATA: begin
                    if (w_eng_done) begin
                        r_state <= ST_WP_END;
                    end else if (!w_eng_busy) begin
                        r_eng_read <= 1'b0;
                        r_eng_tx_byte <= DATA_WP_DISABLE;
                        r_eng_start <= 1'b1;
                    end
                end

                ST_WP_END: begin
                    r_ce <= 1'b0;
                    r_gap_cnt <= 10'd0;
                    r_wr_buf[0] <= {1'b0, r_set_second[6:0]}; // sec (CH=0)
                    r_wr_buf[1] <= r_set_minute;              // min
                    r_wr_buf[2] <= r_set_hour;                // hour
                    r_wr_buf[3] <= r_set_date;                // date
                    r_wr_buf[4] <= r_set_month;               // month
                    r_wr_buf[5] <= 8'h01;                     // day of week
                    r_wr_buf[6] <= r_set_year;                // year
                    r_wr_buf[7] <= 8'h00;                     // WP=0
                    r_state <= ST_WBURST_GAP;
                end

                ST_WBURST_GAP: begin
                    r_ce <= 1'b0;
                    if (r_gap_cnt >= (CE_GAP_CYCLES - 1)) begin
                        r_ce <= 1'b1;
                        r_state <= ST_WBURST_CMD;
                    end else begin
                        r_gap_cnt <= r_gap_cnt + 10'd1;
                    end
                end

                ST_WBURST_CMD: begin
                    if (w_eng_done) begin
                        r_state <= ST_WBURST_D0;
                    end else if (!w_eng_busy) begin
                        r_eng_read <= 1'b0;
                        r_eng_tx_byte <= CMD_CLOCK_BURST_WRITE;
                        r_eng_start <= 1'b1;
                    end
                end

                ST_WBURST_D0, ST_WBURST_D1, ST_WBURST_D2, ST_WBURST_D3,
                ST_WBURST_D4, ST_WBURST_D5, ST_WBURST_D6, ST_WBURST_D7: begin
                    if (w_eng_done) begin
                        if (r_state == ST_WBURST_D7)
                            r_state <= ST_WBURST_END;
                        else
                            r_state <= r_state + 6'd1;
                    end else if (!w_eng_busy) begin
                        r_eng_read <= 1'b0;
                        r_eng_tx_byte <= r_wr_buf[r_state - ST_WBURST_D0];
                        r_eng_start <= 1'b1;
                    end
                end

                ST_WBURST_END: begin
                    r_ce <= 1'b0;
                    r_write_pending <= 1'b0;
                    r_gap_cnt <= 10'd0;
                    r_state <= ST_RBURST_GAP;
                end

                ST_RBURST_GAP: begin
                    r_ce <= 1'b0;
                    if (r_gap_cnt >= (CE_GAP_CYCLES - 1)) begin
                        r_ce <= 1'b1;
                        r_state <= ST_RBURST_CMD;
                    end else begin
                        r_gap_cnt <= r_gap_cnt + 10'd1;
                    end
                end

                ST_RBURST_CMD: begin
                    if (w_eng_done) begin
                        r_state <= ST_RBURST_D0;
                    end else if (!w_eng_busy) begin
                        r_eng_read <= 1'b0;
                        r_eng_tx_byte <= CMD_CLOCK_BURST_READ;
                        r_eng_start <= 1'b1;
                    end
                end

                ST_RBURST_D0, ST_RBURST_D1, ST_RBURST_D2, ST_RBURST_D3,
                ST_RBURST_D4, ST_RBURST_D5, ST_RBURST_D6, ST_RBURST_D7: begin
                    if (w_eng_done) begin
                        r_rd_buf[r_state - ST_RBURST_D0] <= w_eng_rx_byte;
                        if (r_state == ST_RBURST_D7)
                            r_state <= ST_RBURST_END;
                        else
                            r_state <= r_state + 6'd1;
                    end else if (!w_eng_busy) begin
                        r_eng_read <= 1'b1;
                        r_eng_tx_byte <= 8'h00;
                        r_eng_start <= 1'b1;
                    end
                end

                ST_RBURST_END: begin
                    r_ce <= 1'b0;

                    // Burst read order: sec, min, hour, date, month, day, year, wp
                    if (bcd_range_ok({1'b0, r_rd_buf[0][6:0]}, 8'd0, 8'd59) &&
                        bcd_range_ok(r_rd_buf[1], 8'd0, 8'd59) &&
                        bcd_range_ok(r_rd_buf[2], 8'd0, 8'd23) &&
                        bcd_range_ok(r_rd_buf[3], 8'd1, 8'd31) &&
                        bcd_range_ok(r_rd_buf[4], 8'd1, 8'd12) &&
                        bcd_nibbles_ok(r_rd_buf[6])) begin
                        r_second <= {1'b0, r_rd_buf[0][6:0]};
                        r_minute <= r_rd_buf[1];
                        r_hour   <= r_rd_buf[2];
                        r_date   <= r_rd_buf[3];
                        r_month  <= r_rd_buf[4];
                        r_year   <= r_rd_buf[6];
                    end

                    r_state <= ST_IDLE;
                end

                default: begin
                    r_state <= ST_IDLE;
                    r_ce <= 1'b0;
                end
            endcase
        end
    end

endmodule


module ds1302_byte_engine(
    input clk,
    input reset,
    input io_tick,
    input start,
    input is_read,
    input [7:0] tx_byte,
    input io_in,
    output reg busy,
    output reg done,
    output reg [7:0] rx_byte,
    output reg sclk,
    output reg io_oe,
    output reg io_out
    );

    reg [2:0] r_bit_idx;
    reg [1:0] r_phase;
    reg r_is_read_latched;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            busy <= 1'b0;
            done <= 1'b0;
            rx_byte <= 8'h00;
            sclk <= 1'b0;
            io_oe <= 1'b1;
            io_out <= 1'b0;
            r_bit_idx <= 3'd0;
            r_phase <= 2'd0;
            r_is_read_latched <= 1'b0;
        end
        else begin
            done <= 1'b0;

            if (start && !busy) begin
                busy <= 1'b1;
                sclk <= 1'b0;
                io_oe <= !is_read;
                io_out <= tx_byte[0];
                rx_byte <= 8'h00;
                r_bit_idx <= 3'd0;
                r_phase <= 2'd0;
                r_is_read_latched <= is_read;
            end
            else if (busy && io_tick) begin
                case (r_phase)
                    2'd0: begin
                        sclk <= 1'b0;
                        io_oe <= !r_is_read_latched;
                        io_out <= tx_byte[r_bit_idx];
                        r_phase <= 2'd1;
                    end

                    2'd1: begin
                        sclk <= 1'b1;
                        if (r_is_read_latched)
                            rx_byte[r_bit_idx] <= io_in;
                        r_phase <= 2'd2;
                    end

                    default: begin
                        sclk <= 1'b0;
                        if (r_bit_idx == 3'd7) begin
                            busy <= 1'b0;
                            done <= 1'b1;
                            io_oe <= 1'b1;
                            io_out <= 1'b0;
                            r_phase <= 2'd0;
                        end
                        else begin
                            r_bit_idx <= r_bit_idx + 3'd1;
                            r_phase <= 2'd0;
                        end
                    end
                endcase
            end
        end
    end

endmodule
