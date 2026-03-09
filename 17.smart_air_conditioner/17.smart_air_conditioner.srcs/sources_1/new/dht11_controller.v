`timescale 1ns / 1ps

module dht11_controller(
    input clk,
    input reset,
    input start,
    inout dht_data,
    output reg [7:0] humidity,
    output reg [7:0] temperature,
    output reg data_valid,
    output reg error
);

    // 상태 정의
    localparam IDLE           = 3'd0;
    localparam START_LOW      = 3'd1;
    localparam START_RELEASE  = 3'd2;
    localparam WAIT_RESP_LOW  = 3'd3;
    localparam WAIT_RESP_HIGH = 3'd4;
    localparam WAIT_FIRST_LOW = 3'd5;
    localparam READ_DATA      = 3'd6;
    localparam DONE           = 3'd7;

    // 시간 상수 (100MHz 기준, 1us 단위 카운트)
    localparam [31:0] START_LOW_US    = 32'd18_000; // 18ms
    localparam [31:0] RELEASE_WAIT_US = 32'd30;     // 30us
    localparam [31:0] TIMEOUT_LIMIT   = 32'd3_000_000; // 3초 타임아웃

    reg [2:0]  state;
    reg [31:0] timer;
    reg [5:0]  bit_cnt;
    reg [39:0] data_shift;
    reg        data_out;
    reg        data_dir;

    // 입출력 제어
    assign dht_data = data_dir ? data_out : 1'bz;

    // 외부 입력 동기화 (Metastability 방지)
    reg data_sync0, data_sync1;
    wire data_in = data_sync1;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            data_sync0 <= 1'b1;
            data_sync1 <= 1'b1;
        end else begin
            data_sync0 <= dht_data;
            data_sync1 <= data_sync0;
        end
    end

    // 체크섬 계산 로직
    wire [7:0] checksum_calc = data_shift[39:32] + data_shift[31:24] 
                             + data_shift[23:16] + data_shift[15:8];
    wire checksum_ok = (checksum_calc == data_shift[7:0]);

    // 1us tick 생성 로직 (100MHz 기준)
    reg [6:0] us_cnt;
    reg       tick_1us;
    always @(posedge clk or posedge reset) begin
        if (reset) begin us_cnt <= 0; tick_1us <= 0; end
        else begin
            if (us_cnt == 99) begin us_cnt <= 0; tick_1us <= 1; end
            else begin us_cnt <= us_cnt + 1; tick_1us <= 0; end
        end
    end

    // 메인 상태 머신
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= IDLE; timer <= 0; bit_cnt <= 0; data_shift <= 0;
            humidity <= 0; temperature <= 0; data_valid <= 0;
            error <= 0; data_dir <= 0; data_out <= 1;
        end else begin
            case (state)
                IDLE: begin
                    data_valid <= 0; 
                    if (start) begin
                        error <= 0;
                        state <= START_LOW; timer <= 0;
                        data_dir <= 1; data_out <= 0; // Host: Low
                    end
                end

                START_LOW: begin
                    if (tick_1us) timer <= timer + 1;
                    if (timer >= START_LOW_US) begin
                        timer <= 0; data_out <= 1; state <= START_RELEASE;
                    end
                end

                START_RELEASE: begin
                    data_dir <= 0; // Bus Release (Input 모드)
                    if (tick_1us) timer <= timer + 1;
                    if (timer >= RELEASE_WAIT_US) begin 
                        timer <= 0; state <= WAIT_RESP_LOW; 
                    end
                end

                WAIT_RESP_LOW: begin
                    if (tick_1us) timer <= timer + 1;
                    if (data_in == 0) begin state <= WAIT_RESP_HIGH; timer <= 0; end
                    else if (timer >= TIMEOUT_LIMIT) begin state <= IDLE; error <= 1; end
                end

                WAIT_RESP_HIGH: begin
                    if (tick_1us) timer <= timer + 1;
                    if (data_in == 1) begin state <= WAIT_FIRST_LOW; timer <= 0; end
                    else if (timer >= TIMEOUT_LIMIT) begin state <= IDLE; error <= 1; end
                end

                WAIT_FIRST_LOW: begin
                    if (tick_1us) timer <= timer + 1;
                    if (data_in == 0) begin state <= READ_DATA; bit_cnt <= 0; timer <= 0; end
                    else if (timer >= TIMEOUT_LIMIT) begin state <= IDLE; error <= 1; end
                end

                READ_DATA: begin
                    if (data_in == 1) begin
                        if (tick_1us) timer <= timer + 1;
                        if (timer >= 1000) begin state <= IDLE; error <= 1; end // 비정상 High
                    end else if (data_in == 0 && timer > 0) begin
                        // 45us 기준으로 0/1 판별
                        if (timer > 45) data_shift <= {data_shift[38:0], 1'b1};
                        else            data_shift <= {data_shift[38:0], 1'b0};

                        timer <= 0;
                        bit_cnt <= bit_cnt + 1;
                        if (bit_cnt >= 39) state <= DONE;
                    end
                end

                DONE: begin
                    if (checksum_ok) begin
                        humidity <= data_shift[39:32];
                        temperature <= data_shift[23:16];
                        data_valid <= 1;
                        error <= 0;
                    end else begin
                        error <= 1; // 체크섬 오류 시 에러 발생
                    end
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule


// `timescale 1ns / 1ps

// module dht11_controller(
//     input clk,
//     input reset,
//     input start,
//     inout dht_data,
//     output reg [7:0] humidity,
//     output reg [7:0] temperature,
//     output reg data_valid,
//     output reg error           // [수정] 에러 신호 포트 추가
// );

// <<<<<<< HEAD
// parameter IDLE           = 3'd0;
// parameter START_LOW      = 3'd1;
// parameter START_RELEASE   = 3'd2;
// parameter WAIT_RESP_LOW   = 3'd3;
// parameter WAIT_RESP_HIGH  = 3'd4;
// parameter WAIT_FIRST_LOW  = 3'd5;
// parameter READ_DATA       = 3'd6;
// parameter DONE            = 3'd7;

// // [수정] 3초 타임아웃 기준 (1us tick 기준 3,000,000)
// parameter TIMEOUT_LIMIT   = 32'd3_000_000; 

// =======
// localparam IDLE            = 3'd0;
// localparam START_LOW       = 3'd1;
// localparam START_RELEASE   = 3'd2;
// localparam WAIT_RESP_LOW   = 3'd3;
// localparam WAIT_RESP_HIGH  = 3'd4;
// localparam WAIT_FIRST_LOW  = 3'd5;
// localparam READ_DATA       = 3'd6;
// localparam DONE            = 3'd7;

// localparam [31:0] START_LOW_US        = 32'd18_000;
// localparam [31:0] RELEASE_WAIT_US     = 32'd30;
// localparam [31:0] RESPONSE_TIMEOUT_US = 32'd200;
// localparam [31:0] BIT_HIGH_TIMEOUT_US = 32'd120;

// >>>>>>> bb0ba62c7ebd9dc3998cff288ce9cf1c459058b0
// reg [2:0] state;
// reg [31:0] timer;
// reg [5:0] bit_cnt;
// reg [39:0] data_shift;
// reg data_out;
// reg data_dir;

// assign dht_data = data_dir ? data_out : 1'bz;

// <<<<<<< HEAD
// =======
// reg data_sync0;
// reg data_sync1;
// wire data_in = data_sync1;

// wire [7:0] checksum_calc = data_shift[39:32] + data_shift[31:24]
//                          + data_shift[23:16] + data_shift[15:8];
// wire checksum_ok = (checksum_calc == data_shift[7:0]);

// >>>>>>> bb0ba62c7ebd9dc3998cff288ce9cf1c459058b0
// reg [6:0] us_cnt;
// reg tick_1us;

// // 1us 생성 로직
// always @(posedge clk or posedge reset) begin
// <<<<<<< HEAD
//     if(reset) begin us_cnt <= 0; tick_1us <= 0; end
//     else begin
//         if(us_cnt == 99) begin us_cnt <= 0; tick_1us <= 1; end
//         else begin us_cnt <= us_cnt + 1; tick_1us <= 0; end
// =======
//     if (reset) begin
//         us_cnt <= 7'd0;
//         tick_1us <= 1'b0;
//     end else begin
//         if (us_cnt == 7'd99) begin
//             us_cnt <= 7'd0;
//             tick_1us <= 1'b1;
//         end else begin
//             us_cnt <= us_cnt + 7'd1;
//             tick_1us <= 1'b0;
//         end
// >>>>>>> bb0ba62c7ebd9dc3998cff288ce9cf1c459058b0
//     end
// end

// always @(posedge clk or posedge reset) begin
// <<<<<<< HEAD
//     if(reset) begin
//         state <= IDLE; timer <= 0; bit_cnt <= 0; data_shift <= 0;
//         humidity <= 0; temperature <= 0; data_valid <= 0;
//         error <= 0; data_dir <= 0; data_out <= 1;
//     end
//     else begin
//         case(state)
//         IDLE: begin
//             if(start) begin
//                 data_valid <= 0; error <= 0; // [수정] 새 측정 시작 시 에러 초기화
//                 state <= START_LOW; timer <= 0;
//                 data_dir <= 1; data_out <= 0;
//             end
//         end

//         START_LOW: begin
//             if(tick_1us) timer <= timer + 1;
//             if(timer >= 18000) begin
//                 timer <= 0; data_out <= 1; state <= START_RELEASE;
//             end
//         end

//         START_RELEASE: begin
//             data_dir <= 0;
//             if(tick_1us) timer <= timer + 1;
//             if(timer >= 30) begin timer <= 0; state <= WAIT_RESP_LOW; end
//         end

//         // [수정] 각 응답 대기 상태에 3초 타임아웃 로직 적용
//         WAIT_RESP_LOW: begin
//             if(tick_1us) timer <= timer + 1;
//             if(data_in == 0) begin state <= WAIT_RESP_HIGH; timer <= 0; end
//             else if(timer >= TIMEOUT_LIMIT) begin state <= IDLE; error <= 1; end
//         end

//         WAIT_RESP_HIGH: begin
//             if(tick_1us) timer <= timer + 1;
//             if(data_in == 1) begin state <= WAIT_FIRST_LOW; timer <= 0; end
//             else if(timer >= TIMEOUT_LIMIT) begin state <= IDLE; error <= 1; end
//         end

//         WAIT_FIRST_LOW: begin
//             if(tick_1us) timer <= timer + 1;
//             if(data_in == 0) begin state <= READ_DATA; bit_cnt <= 0; timer <= 0; end
//             else if(timer >= TIMEOUT_LIMIT) begin state <= IDLE; error <= 1; end
//         end

//         READ_DATA: begin
//             if (data_in == 1) begin
//                 if (tick_1us) timer <= timer + 1;
//                 // [수정] 비트 하나가 1ms(1000us) 이상 High일 수 없으므로 안전장치 추가
//                 if (timer >= 1000) begin state <= IDLE; error <= 1; end 
//             end 
//             else if (data_in == 0 && timer > 0) begin
//                 // [수정] 판별 기준을 45us로 상향 (데이터 튐 방지)
//                 if (timer > 45) data_shift <= {data_shift[38:0], 1'b1};
//                 else data_shift <= {data_shift[38:0], 1'b0};

//                 timer <= 0;
//                 bit_cnt <= bit_cnt + 1;
//                 if (bit_cnt >= 39) state <= DONE;
//             end
//         end

//         DONE: begin
//             humidity <= data_shift[39:32];
//             temperature <= data_shift[23:16];
//             data_valid <= 1;
//             state <= IDLE;
//         end
//         endcase
// =======
//     if (reset) begin
//         data_sync0 <= 1'b1;
//         data_sync1 <= 1'b1;
//     end else begin
//         data_sync0 <= dht_data;
//         data_sync1 <= data_sync0;
// >>>>>>> bb0ba62c7ebd9dc3998cff288ce9cf1c459058b0
//     end
// end
// endmodule

// <<<<<<< HEAD

// // `timescale 1ns / 1ps

// // module dht11_controller(
// //     input clk,
// //     input reset,
// //     input start,            // 측정 시작

// //     inout dht_data,         // DHT11 DATA

// //     output reg [7:0] humidity,
// //     output reg [7:0] temperature,
// //     output reg data_valid,
// //     output reg error           // 에러 신호 추가
// // );

// // parameter IDLE            = 3'd0;
// // parameter START_LOW       = 3'd1;
// // parameter START_RELEASE   = 3'd2;
// // parameter WAIT_RESP_LOW   = 3'd3;
// // parameter WAIT_RESP_HIGH  = 3'd4;
// // parameter WAIT_FIRST_LOW  = 3'd5; //추가
// // parameter READ_DATA       = 3'd6;
// // parameter DONE            = 3'd7;

// // reg [2:0] state;

// // reg [31:0] timer;
// // reg [5:0] bit_cnt;

// // reg [39:0] data_shift;

// // reg data_out;
// // reg data_dir;

// // assign dht_data = data_dir ? data_out : 1'bz;
// // wire data_in = dht_data;


// // reg [6:0] us_cnt;
// // reg tick_1us;

// // always @(posedge clk or posedge reset) begin
// //     if(reset) begin
// //         us_cnt <= 0;
// //         tick_1us <= 0;
// //     end
// //     else begin
// //         if(us_cnt == 99) begin
// //             us_cnt <= 0;
// //             tick_1us <= 1;
// //         end
// //         else begin
// //             us_cnt <= us_cnt + 1;
// //             tick_1us <= 0;
// //         end
// //     end
// // end


// // always @(posedge clk or posedge reset) begin
// //     if(reset) begin
// //         state <= IDLE;
// //         timer <= 0;
// //         bit_cnt <= 0;
// //         data_shift <= 0;
// //         humidity <= 0;
// //         temperature <= 0;
// //         data_valid <= 0;
// //         error <= 0;
// //         data_dir <= 0;
// //         data_out <= 1;
// //     end

// //     else begin

// //         case(state)


// //         IDLE:
// //         begin
// //             // data_valid <= 0; // 이 줄을 주석 처리하면 다음 측정 전까지 LED가 유지됩니다.
// //             if(start) begin
// //                 data_valid <= 0; // 새로운 측정이 시작될 때만 valid를 끕니다.
// //                 state <= START_LOW;
// //                 timer <= 0;
// //                 data_dir <= 1;
// //                 data_out <= 0;
// //             end
// //         end
        
// //         START_LOW:
// //         begin
// //             if(tick_1us)
// //                 timer <= timer + 1;

// //             if(timer >= 18000) begin
// //                 timer <= 0;
// //                 data_out <= 1;
// //                 state <= START_RELEASE;
// //             end
// //         end

// //         START_RELEASE:
// //         begin
// //             data_dir <= 0;

// //             if(tick_1us)
// //                 timer <= timer + 1;

// //             if(timer >= 30) begin
// //                 timer <= 0;
// //                 state <= WAIT_RESP_LOW;
// //             end
// //         end



// //         WAIT_RESP_LOW:
// //         begin
// //             if(data_in == 0)
// //                 state <= WAIT_RESP_HIGH;
// //         end


// //         // WAIT_RESP_HIGH:
// //         // begin
// //         //     if(data_in == 1) begin
// //         //         bit_cnt <= 0;
// //         //         state <= READ_DATA;
// //         //     end
// //         // end


// //         WAIT_RESP_HIGH:
// //         begin
// //             if(data_in == 1)
// //                 state <= WAIT_FIRST_LOW;
// //         end

// //         WAIT_FIRST_LOW:
// //         begin
// //             if(data_in == 0) begin
// //                 bit_cnt <= 0;
// //                 state <= READ_DATA;
// //             end
// //         end



// //         // READ_DATA:
// //         // begin
// //         //     if(data_in == 1) begin

// //         //         if(tick_1us)
// //         //             timer <= timer + 1;

// //         //     end
// //         //     else begin

// //         //         if(timer > 50)
// //         //             data_shift <= {data_shift[38:0],1'b1};
// //         //         else
// //         //             data_shift <= {data_shift[38:0],1'b0};

// //         //         timer <= 0;
// //         //         bit_cnt <= bit_cnt + 1;

// //         //         if(bit_cnt == 39)
// //         //             state <= DONE;
// //         //     end
// //         // end



// //         // 상태 머신 내부 READ_DATA 부분 수정 제
// //         READ_DATA:
// //         begin
// //             if (data_in == 1) begin
// //                 if (tick_1us) timer <= timer + 1;
// //             end 
// //             else if (data_in == 0 && timer > 0) begin // Falling Edge 시점
// //                 // 비트 판별 (40us 기준)
// //                 if (timer > 40) 
// //                     data_shift <= {data_shift[38:0], 1'b1};
// //                 else 
// //                     data_shift <= {data_shift[38:0], 1'b0};

// //                 timer <= 0;
// //                 bit_cnt <= bit_cnt + 1;

// //                 if (bit_cnt >= 39) begin
// //                     state <= DONE;
// //                 end
// //             end
// //         end

// //         DONE:
// //         begin
// //             humidity <= data_shift[39:32];
// //             temperature <= data_shift[23:16];

// //             data_valid <= 1;
// //             state <= IDLE;
// //         end

// //         endcase

// //     end
// // end

// // endmodule
// =======
// always @(posedge clk or posedge reset) begin
//     if (reset) begin
//         state <= IDLE;
//         timer <= 32'd0;
//         bit_cnt <= 6'd0;
//         data_shift <= 40'd0;
//         humidity <= 8'd0;
//         temperature <= 8'd0;
//         data_valid <= 1'b0;
//         data_dir <= 1'b0;
//         data_out <= 1'b1;
//     end else begin
//         // Generate a single-cycle pulse only when a frame is valid.
//         data_valid <= 1'b0;

//         case (state)
//             IDLE: begin
//                 if (start) begin
//                     state <= START_LOW;
//                     timer <= 32'd0;
//                     bit_cnt <= 6'd0;
//                     data_shift <= 40'd0;
//                     data_dir <= 1'b1;
//                     data_out <= 1'b0;
//                 end
//             end

//             START_LOW: begin
//                 if (tick_1us) begin
//                     timer <= timer + 32'd1;
//                 end
//                 if (timer >= START_LOW_US) begin
//                     timer <= 32'd0;
//                     data_out <= 1'b1;
//                     state <= START_RELEASE;
//                 end
//             end

//             START_RELEASE: begin
//                 data_dir <= 1'b0;
//                 if (tick_1us) begin
//                     timer <= timer + 32'd1;
//                 end
//                 if (timer >= RELEASE_WAIT_US) begin
//                     timer <= 32'd0;
//                     state <= WAIT_RESP_LOW;
//                 end
//             end

//             WAIT_RESP_LOW: begin
//                 if (data_in == 1'b0) begin
//                     timer <= 32'd0;
//                     state <= WAIT_RESP_HIGH;
//                 end else if (tick_1us) begin
//                     if (timer >= RESPONSE_TIMEOUT_US) begin
//                         state <= IDLE;
//                     end else begin
//                         timer <= timer + 32'd1;
//                     end
//                 end
//             end

//             WAIT_RESP_HIGH: begin
//                 if (data_in == 1'b1) begin
//                     timer <= 32'd0;
//                     state <= WAIT_FIRST_LOW;
//                 end else if (tick_1us) begin
//                     if (timer >= RESPONSE_TIMEOUT_US) begin
//                         state <= IDLE;
//                     end else begin
//                         timer <= timer + 32'd1;
//                     end
//                 end
//             end

//             WAIT_FIRST_LOW: begin
//                 if (data_in == 1'b0) begin
//                     timer <= 32'd0;
//                     bit_cnt <= 6'd0;
//                     data_shift <= 40'd0;
//                     state <= READ_DATA;
//                 end else if (tick_1us) begin
//                     if (timer >= RESPONSE_TIMEOUT_US) begin
//                         state <= IDLE;
//                     end else begin
//                         timer <= timer + 32'd1;
//                     end
//                 end
//             end

//             READ_DATA: begin
//                 if (data_in == 1'b1) begin
//                     if (tick_1us) begin
//                         if (timer >= BIT_HIGH_TIMEOUT_US) begin
//                             state <= IDLE;
//                         end else begin
//                             timer <= timer + 32'd1;
//                         end
//                     end
//                 end else if (timer > 32'd0) begin
//                     if (timer > 32'd40) begin
//                         data_shift <= {data_shift[38:0], 1'b1};
//                     end else begin
//                         data_shift <= {data_shift[38:0], 1'b0};
//                     end

//                     timer <= 32'd0;
//                     bit_cnt <= bit_cnt + 6'd1;

//                     if (bit_cnt >= 6'd39) begin
//                         state <= DONE;
//                     end
//                 end
//             end

//             DONE: begin
//                 if (checksum_ok) begin
//                     humidity <= data_shift[39:32];
//                     temperature <= data_shift[23:16];
//                     data_valid <= 1'b1;
//                 end
//                 state <= IDLE;
//             end

//             default: begin
//                 state <= IDLE;
//             end
//         endcase
//     end
// end

// endmodule
// >>>>>>> bb0ba62c7ebd9dc3998cff288ce9cf1c459058b0
