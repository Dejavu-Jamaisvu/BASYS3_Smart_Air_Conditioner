`timescale 1ns / 1ps

module aircon_control(
    input clk,
    input reset,
    input btn_up,         // 온도 올리기
    input btn_down,       // 온도 내리기
    input [7:0] curr_temp, // 현재 온도 (DHT11에서 옴)
    output [7:0] set_temp, // 설정 온도 (FND/UART용)
    output [3:0] motor_speed // 모터 PWM용 속도 (0~9)
);

    reg [7:0] r_set_temp = 8'd25;
    reg r_prev_up, r_prev_down;

    // 1. 온도 설정 로직 (버튼 엣지 검출)
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            r_set_temp <= 8'd25;
            r_prev_up <= 0;
            r_prev_down <= 0;
        end else begin
            r_prev_up <= btn_up;
            r_prev_down <= btn_down;

            if (btn_up && !r_prev_up && r_set_temp < 8'd40)
                r_set_temp <= r_set_temp + 1;
            else if (btn_down && !r_prev_down && r_set_temp > 8'd15)
                r_set_temp <= r_set_temp - 1;
        end
    end

    // 2. 스마트 제어 알고리즘 (차이값 계산)
    // 현재 온도가 설정값보다 높을 때만 가동
    wire [7:0] w_diff = (curr_temp > r_set_temp) ? (curr_temp - r_set_temp) : 8'd0;

    assign motor_speed = (w_diff >= 5) ? 4'd9 : // 5도 이상 차이: 강풍(90%)
                         (w_diff >= 3) ? 4'd8 : // 3도 이상 차이: 약풍(80%)
                         (w_diff >= 1) ? 4'd7 : // 1도 이상 차이: 미풍(70%)
                                         4'd0;  // 시원하면 정지

    assign set_temp = r_set_temp;

endmodule