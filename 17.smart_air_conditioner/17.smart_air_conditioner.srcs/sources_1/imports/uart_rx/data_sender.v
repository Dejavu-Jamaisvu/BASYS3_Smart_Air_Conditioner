`timescale 1ns / 1ps

module data_sender(
    input clk,
    input reset,
    input start_trigger,
    input [15:0] send_data,
    input error_in,          // DHT11 컨트롤러의 error 신호
    input tx_busy,
    input tx_done,
    output reg tx_start,
    output reg [7:0] tx_data
    );

    // 상태 정의 (에러 처리를 위해 7비트 확장)
    reg [6:0] state; 
    
    // 데이터 보존을 위한 래치 변수
    reg [7:0] r_humi;
    reg [7:0] r_temp;
    reg       r_error;

    // ASCII 변환 로직 (래치된 데이터 기준)
    wire [7:0] humi_10 = (r_humi / 10) + 8'h30;
    wire [7:0] humi_1  = (r_humi % 10) + 8'h30;
    wire [7:0] temp_10 = (r_temp / 10) + 8'h30;
    wire [7:0] temp_1  = (r_temp % 10) + 8'h30;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            tx_start <= 0;
            tx_data <= 0;
            state <= 0;
            r_humi <= 0;
            r_temp <= 0;
            r_error <= 0;
        end else begin
            case (state)
                0: begin 
                    if (start_trigger && !tx_busy) begin
                        // 전송 시작 시 현재 데이터를 래치 (전송 도중 값 변경 방지)
                        r_humi <= send_data[7:0];
                        r_temp <= send_data[15:8];
                        r_error <= error_in;
                        
                        if (error_in) begin
                            tx_data <= "F"; // FAIL의 시작
                            tx_start <= 1;
                            state <= 100;
                        end else begin
                            tx_data <= "H"; // H:xx...의 시작
                            tx_start <= 1;
                            state <= 1;
                        end
                    end
                end

                // --- [정상 경로] H:xx / T:xx ---
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

                // --- [에러 경로] FAIL ---
                100: if (tx_done) state <= 101;
                101: begin tx_data <= "A"; tx_start <= 1; state <= 102; end
                102: if (tx_done) state <= 103;
                103: begin tx_data <= "I"; tx_start <= 1; state <= 104; end
                104: if (tx_done) state <= 105;
                105: begin tx_data <= "L"; tx_start <= 1; state <= 22; end

                // --- [공통] 줄바꿈 및 종료 ---
                22: if (tx_done) state <= 23;
                23: begin tx_data <= 8'h0D; tx_start <= 1; state <= 24; end // CR (\r)
                24: if (tx_done) state <= 25;
                25: begin tx_data <= 8'h0A; tx_start <= 1; state <= 26; end // LF (\n)
                26: if (tx_done) state <= 0;

                default: state <= 0;
            endcase
            
            // 한 클럭만 High 유지
            if (tx_start) tx_start <= 0;
        end
    end
endmodule

// `timescale 1ns / 1ps

// module data_sender(
//     input clk,
//     input reset,
//     input start_trigger,
//     input [15:0] send_data,
//     input error_in,          // [수정] DHT11 컨트롤러의 error 출력과 연결
//     input tx_busy,
//     input tx_done,
//     output reg tx_start,
//     output reg [7:0] tx_data
//     );

// <<<<<<< HEAD
//     // [수정] 상태 번호 100번대 사용을 위해 7비트로 확장
//     reg [6:0] state; 

//     // ASCII 변환 로직
//     wire [7:0] humi_10 = (send_data[7:0] / 10) + 8'h30;
//     wire [7:0] humi_1  = (send_data[7:0] % 10) + 8'h30;
//     wire [7:0] temp_10 = (send_data[15:8] / 10) + 8'h30;
//     wire [7:0] temp_1  = (send_data[15:8] % 10) + 8'h30;

//     always @(posedge clk or posedge reset) begin
//         if (reset) begin
//             tx_start <= 0; tx_data <= 0; state <= 0;
//         end else begin
//             case (state)
//                 0: begin 
//                     if (start_trigger && !tx_busy) begin
//                         if (error_in) begin // [수정] 에러 시 FAIL 출력 경로
//                             tx_data <= "F"; tx_start <= 1; state <= 100;
//                         end else begin      // 정상 시 데이터 출력 경로
//                             tx_data <= "H"; tx_start <= 1; state <= 1;
//                         end
//                     end
//                 end

//                 // --- 정상 데이터 전송 (H:xx / T:xx) ---
//                 1:  if (tx_done) state <= 2;
//                 2:  begin tx_data <= ":"; tx_start <= 1; state <= 3; end
//                 3:  if (tx_done) state <= 4;
//                 4:  begin tx_data <= humi_10; tx_start <= 1; state <= 5; end
//                 5:  if (tx_done) state <= 6;
//                 6:  begin tx_data <= humi_1; tx_start <= 1; state <= 7; end
//                 7:  if (tx_done) state <= 8;
//                 8:  begin tx_data <= " "; tx_start <= 1; state <= 9; end
//                 9:  if (tx_done) state <= 10;
//                 10: begin tx_data <= "/"; tx_start <= 1; state <= 11; end
//                 11: if (tx_done) state <= 12;
//                 12: begin tx_data <= " "; tx_start <= 1; state <= 13; end
//                 13: if (tx_done) state <= 14;
//                 14: begin tx_data <= "T"; tx_start <= 1; state <= 15; end
//                 15: if (tx_done) state <= 16;
//                 16: begin tx_data <= ":"; tx_start <= 1; state <= 17; end
//                 17: if (tx_done) state <= 18;
//                 18: begin tx_data <= temp_10; tx_start <= 1; state <= 19; end
//                 19: if (tx_done) state <= 20;
//                 20: begin tx_data <= temp_1; tx_start <= 1; state <= 21; end
//                 21: if (tx_done) state <= 22; // 공통 줄바꿈으로 이동

//                 // --- [수정] 에러 메시지 전송 (FAIL) ---
//                 100: if (tx_done) state <= 101;
//                 101: begin tx_data <= "A"; tx_start <= 1; state <= 102; end
//                 102: if (tx_done) state <= 103;
//                 103: begin tx_data <= "I"; tx_start <= 1; state <= 104; end
//                 104: if (tx_done) state <= 105;
//                 105: begin tx_data <= "L"; tx_start <= 1; state <= 22; end // 줄바꿈으로 이동

//                 // --- 공통 줄바꿈 (\r\n) ---
//                 22: begin tx_data <= 8'h0D; tx_start <= 1; state <= 23; end
//                 23: if (tx_done) state <= 24;
//                 24: begin tx_data <= 8'h0A; tx_start <= 1; state <= 25; end
//                 25: if (tx_done) state <= 0;

//                 default: state <= 0;
//             endcase
//             if (tx_start) tx_start <= 0;
// =======
//     reg r_sending;
//     reg r_wait_done;
//     reg [3:0] r_byte_idx;

//     reg [7:0] r_humi;
//     reg [7:0] r_temp;

//     function [7:0] clamp_99;
//         input [7:0] value;
//         begin
//             if (value > 8'd99)
//                 clamp_99 = 8'd99;
//             else
//                 clamp_99 = value;
//         end
//     endfunction

//     function [7:0] dec_tens_ascii;
//         input [7:0] value;
//         begin
//             dec_tens_ascii = (clamp_99(value) / 8'd10) + 8'h30;
//         end
//     endfunction

//     function [7:0] dec_ones_ascii;
//         input [7:0] value;
//         begin
//             dec_ones_ascii = (clamp_99(value) % 8'd10) + 8'h30;
//         end
//     endfunction

//     always @(posedge clk or posedge reset) begin
//         if (reset) begin
//             tx_start <= 1'b0;
//             tx_data <= 8'h00;
//             r_sending <= 1'b0;
//             r_wait_done <= 1'b0;
//             r_byte_idx <= 4'd0;
//             r_humi <= 8'd0;
//             r_temp <= 8'd0;
//         end else begin
//             tx_start <= 1'b0;

//             if (!r_sending) begin
//                 if (start_trigger) begin
//                     // Latch once to prevent value changes while text is being sent.
//                     r_humi <= send_data[7:0];
//                     r_temp <= send_data[15:8];
//                     r_sending <= 1'b1;
//                     r_wait_done <= 1'b0;
//                     r_byte_idx <= 4'd0;
//                 end
//             end else begin
//                 if (!r_wait_done && !tx_busy) begin
//                     case (r_byte_idx)
//                         4'd0:  tx_data <= "H";
//                         4'd1:  tx_data <= ":";
//                         4'd2:  tx_data <= dec_tens_ascii(r_humi);
//                         4'd3:  tx_data <= dec_ones_ascii(r_humi);
//                         4'd4:  tx_data <= " ";
//                         4'd5:  tx_data <= "/";
//                         4'd6:  tx_data <= " ";
//                         4'd7:  tx_data <= "T";
//                         4'd8:  tx_data <= ":";
//                         4'd9:  tx_data <= dec_tens_ascii(r_temp);
//                         4'd10: tx_data <= dec_ones_ascii(r_temp);
//                         4'd11: tx_data <= 8'h0D; // CR
//                         default: tx_data <= 8'h0A; // LF
//                     endcase

//                     tx_start <= 1'b1;
//                     r_wait_done <= 1'b1;
//                 end else if (r_wait_done && tx_done) begin
//                     r_wait_done <= 1'b0;

//                     if (r_byte_idx == 4'd12) begin
//                         r_sending <= 1'b0;
//                     end else begin
//                         r_byte_idx <= r_byte_idx + 4'd1;
//                     end
//                 end
//             end
// >>>>>>> bb0ba62c7ebd9dc3998cff288ce9cf1c459058b0
//         end
//     end

// endmodule
