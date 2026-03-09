`timescale 1ns / 1ps

module data_sender(
    input clk,
    input reset,
    input start_trigger,
    input [15:0] send_data,  // [15:8]: Temp, [7:0]: Humi
    input tx_busy,
    input tx_done,
    output reg tx_start,
    output reg [7:0] tx_data
    );

    // 상태를 25번까지 써야 하므로 5비트(0~31)가 꼭 필요합니다!
    reg [4:0] state; 

    // 10진수 분리 (ASCII)
    wire [7:0] humi_10 = (send_data[7:0] / 10) + 8'h30;
    wire [7:0] humi_1  = (send_data[7:0] % 10) + 8'h30;
    wire [7:0] temp_10 = (send_data[15:8] / 10) + 8'h30;
    wire [7:0] temp_1  = (send_data[15:8] % 10) + 8'h30;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            tx_start <= 0;
            tx_data <= 0;
            state <= 0;
        end else begin
            case (state)
                0: begin // IDLE
                    if (start_trigger && !tx_busy) begin
                        tx_data <= "H"; tx_start <= 1; state <= 1;
                    end
                end
                1:  if (tx_done) state <= 2;
                2:  begin tx_data <= ":"; tx_start <= 1; state <= 3; end
                3:  if (tx_done) state <= 4;
                4:  begin tx_data <= humi_10; tx_start <= 1; state <= 5; end
                5:  if (tx_done) state <= 6;
                6:  begin tx_data <= humi_1; tx_start <= 1; state <= 7; end
                7:  if (tx_done) state <= 8;
                8:  begin tx_data <= " "; tx_start <= 1; state <= 9; end
                9:  if (tx_done) state <= 10;
                10: begin tx_data <= "/"; tx_start <= 1; state <= 11; end
                11: if (tx_done) state <= 12;
                12: begin tx_data <= " "; tx_start <= 1; state <= 13; end
                13: if (tx_done) state <= 14;
                14: begin tx_data <= "T"; tx_start <= 1; state <= 15; end
                15: if (tx_done) state <= 16;
                16: begin tx_data <= ":"; tx_start <= 1; state <= 17; end
                17: if (tx_done) state <= 18;
                18: begin tx_data <= temp_10; tx_start <= 1; state <= 19; end
                19: if (tx_done) state <= 20;
                20: begin tx_data <= temp_1; tx_start <= 1; state <= 21; end
                21: if (tx_done) state <= 22;
                
                // --- 줄바꿈 구간 ---
                22: begin tx_data <= 8'h0D; tx_start <= 1; state <= 23; end // Carriage Return (\r)
                23: if (tx_done) state <= 24;
                24: begin tx_data <= 8'h0A; tx_start <= 1; state <= 25; end // Line Feed (\n)
                25: if (tx_done) state <= 0; // 완료 후 대기상태로

                default: state <= 0;
            endcase

            if (tx_start) tx_start <= 0;
        end
    end
endmodule

// hex값 출력

// `timescale 1ns / 1ps

// module data_sender(
//     input clk,
//     input reset,
//     input start_trigger,
//     input [15:0] send_data,  // 8비트에서 16비트로 수정 (온도+습도)
//     input tx_busy,
//     input tx_done,
//     output reg tx_start,
//     output reg [7:0] tx_data
//     );

//     // state 변수를 선언해야 합니다. (0~3까지 사용하므로 2비트면 충분합니다)
//     reg [1:0] state; 

//     always @(posedge clk or posedge reset) begin
//         if (reset) begin
//             tx_start <= 0;
//             tx_data <= 0;
//             state <= 0;
//         end else begin
//             case (state)
//                 0: begin // 대기 상태
//                     // 전송 트리거가 발생하고 TX가 준비되었을 때
//                     if (start_trigger && !tx_busy) begin
//                         tx_data <= send_data[7:0]; // 하위 8비트 (습도)
//                         tx_start <= 1;
//                         state <= 1;
//                     end
//                 end
//                 1: begin // 첫 번째 바이트 전송 중
//                     tx_start <= 0; // 한 클럭만 High 유지
//                     if (tx_done) state <= 2; // 전송 완료 신호를 받으면 다음으로
//                 end
//                 2: begin // 두 번째 바이트 전송 시작
//                     if (!tx_busy) begin
//                         tx_data <= send_data[15:8]; // 상위 8비트 (온도)
//                         tx_start <= 1;
//                         state <= 3;
//                     end
//                 end
//                 3: begin // 두 번째 바이트 전송 중
//                     tx_start <= 0;
//                     if (tx_done) state <= 0; // 완료되면 다시 대기(IDLE) 상태로
//                 end
//                 default: state <= 0;
//             endcase
//         end
//     end

// endmodule



// 기존 코드 참고
// `timescale 1ns / 1ps

// module data_sender(
//     input clk,
//     input reset,
//     input start_trigger,
//     input [7:0] send_data,   // 1 byte
//     input tx_busy,
//     input tx_done,
//     output reg tx_start,
//     output reg [7:0] tx_data
//     );

//     reg [6:0] r_send_byte_cnt=7'd0;

//     always @(posedge clk, posedge reset) begin
//         if (reset) begin
//             tx_start <= 1'b0;
//             r_send_byte_cnt <= 7'd0;
//         end else begin
//             if (start_trigger && !tx_busy) begin
//                 tx_start <= 1;
//                 if (r_send_byte_cnt >= 7'd9) begin   // '0' ~ '9' : 10자 
//                     r_send_byte_cnt <= 7'd0;
//                     tx_data <= send_data;
//                 end else  begin
//                     tx_data <= send_data + r_send_byte_cnt;
//                     r_send_byte_cnt <= r_send_byte_cnt + 1;
//                 end 
//             end else begin
//                tx_start <= 1'b0; 
//             end 
//         end 
//     end 

// endmodule
