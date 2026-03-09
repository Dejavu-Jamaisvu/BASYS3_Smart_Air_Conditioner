`timescale 1ns / 1ps

module control_tower(
    input clk,
    input reset,
    input [2:0] btn,         // btn[0]으로 모드 전환
    input [7:0] humidity,    // DHT11 습도 데이터
    input [7:0] temperature, // DHT11 온도 데이터
    output reg [13:0] seg_data, 
    output reg [15:0] led
    );

    // 상태 정의
    parameter MODE_CLOCK = 1'b0;
    parameter MODE_DHT11 = 1'b1;

    reg r_mode = MODE_CLOCK;
    reg [2:0] r_btn_prev;
    
    // 시계용 변수
    reg [31:0] r_tick_cnt;
    reg [5:0] r_sec = 0, r_min = 0;

    // 1. 모드 전환 로직 (Edge Detection)
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            r_mode <= MODE_CLOCK;
            r_btn_prev <= 3'b000;
        end else begin
            r_btn_prev <= btn;
            // btn[0]을 누르는 순간(Rising Edge) 모드 변경
            if (btn[0] && !r_btn_prev[0]) begin
                r_mode <= ~r_mode;
            end
        end
    end

    // 2. 시계 카운터 로직 (1초 생성)
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            r_tick_cnt <= 0;
            r_sec <= 0;
            r_min <= 0;
        end else begin
            if (r_tick_cnt >= 100_000_000 - 1) begin // 1초
                r_tick_cnt <= 0;
                if (r_sec >= 59) begin
                    r_sec <= 0;
                    if (r_min >= 59) r_min <= 0;
                    else r_min <= r_min + 1;
                end else begin
                    r_sec <= r_sec + 1;
                end
            end else begin
                r_tick_cnt <= r_tick_cnt + 1;
            end
        end
    end

    // 3. FND 출력 데이터 선택
    always @(*) begin
        if (r_mode == MODE_CLOCK) begin
            // 시계 모드: 분(2자리) + 초(2자리) -> MMSS
            seg_data = (r_min * 100) + r_sec;
            //led = 16'b0000_0000_0000_0001; // 시계 모드 표시
        end else begin
            // 온습도 모드: 습도(2자리) + 온도(2자리) -> HHTT
            seg_data = (humidity * 100) + temperature;
            //led = 16'b0000_0000_0000_0010; // 온습도 모드 표시
        end
    end

endmodule





// 기존 코드 - 삭제가능
// `timescale 1ns / 1ps

// module control_tower(
//     input clk,
//     input reset,  // sw[15]
//     input [2:0] btn,   // btn[0]: btnL btn[1]: btnC btn[2]: btnR
//     input [7:0] sw,
//     input [7:0] rx_data,   // UART 8 bits
//     input rx_done,    // 8bit data reached : 1
//     output [13:0] seg_data,
//     output reg [15:0] led
//     );
//     // mode define 
//     parameter UP_COUNTER = 3'b001;
//     parameter DOWN_COUNTER = 3'b010;
//     parameter SLIDE_SW_READ = 3'b011;

//     reg r_prev_btnL=0;
//     reg [2:0] r_mode=3'b000;
//     reg [19:0] r_counter; // 10ms 를 재기 위한 counter 10ns * 1000000
//     reg [13:0] r_ms10_counter;  // 10ms가 될때 마다 1 증가  9999 

//     // mode check 
//     always @(posedge clk, posedge reset) begin
//         if (reset) begin
//             r_mode <=0;
//             r_prev_btnL <=0;
//         end else begin
//             if (btn[0] && !r_prev_btnL)
//                 r_mode = (r_mode == SLIDE_SW_READ ) ? UP_COUNTER : r_mode + 1;
            
//             if (rx_done && rx_data == 8'h4D)   // 4d --> 'M'
//                 r_mode = (r_mode == SLIDE_SW_READ ) ? UP_COUNTER : r_mode + 1;
//         end
//         r_prev_btnL <= btn[0];
//     end 

// // up counter
// always @(posedge clk, posedge reset) begin
//     if (reset) begin
//         r_counter <=0; 
//         r_ms10_counter <=0;
//     end else if (r_mode == UP_COUNTER) begin  // 1. add logic 
//         if (r_counter == 20'd1_000_000-1) begin  // 10ms
//             r_counter <=0;
//             if (r_ms10_counter >= 9999)  // 9999도달시 0
//                 r_ms10_counter <= 0;
//             else r_ms10_counter <= r_ms10_counter + 1;
//             led[13:0] <= r_ms10_counter;
//         end else begin
//             r_counter <= r_counter + 1;
//         end
//     end else if (r_mode == DOWN_COUNTER) begin  // 2. sub logic 
//         if (r_counter == 20'd1_000_000-1) begin  // 10ms
//             r_counter <=0;
//             if (r_ms10_counter == 0)  // 0도달시 9999
//                 r_ms10_counter <= 9999;
//             else r_ms10_counter <= r_ms10_counter - 1;
//             led[13:0] <= r_ms10_counter;
//         end else begin
//             r_counter <= r_counter + 1;
//         end
//     end  else begin   // 3. SLIDE_SW_READ or IDLE mode 
//         r_counter <=0; 
//         r_ms10_counter <=0;
//     end 
// end

// //--- led mode display 
// always @(r_mode) begin   // r_mode가 변경 될때 실행
//     case (r_mode)
//         UP_COUNTER: begin 
//             led[15:14] = UP_COUNTER;
//         end 
//         DOWN_COUNTER: begin
//             led[15:14] = DOWN_COUNTER;
//         end 
//         SLIDE_SW_READ: begin  
//             led[15:14] = SLIDE_SW_READ;
//         end 
//         default:
//              led[15:14] = 3'b000;
//     endcase
// end 

// assign seg_data = (r_mode == UP_COUNTER) ? r_ms10_counter :
//                   (r_mode == DOWN_COUNTER) ? r_ms10_counter : sw;

// endmodule
