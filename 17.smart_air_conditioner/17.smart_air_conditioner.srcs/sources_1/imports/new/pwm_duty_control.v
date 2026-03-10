
`timescale 1ns / 1ps

module pwm_duty_control(
    input clk,
    input reset,
    input [3:0] auto_duty_in, // 온도 로직에서 받은 0~9 사이의 값
    // output [3:0] DUTY_CYCLE,   // 현재 상태 확인용 (FND 등에 연결 가능)
    output PWM_OUT//,
    // output PWM_OUT_LED
);

    reg [3:0] r_counter_PWM;

    // 10MHz PWM 신호 생성용 카운터 (0~9)
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            r_counter_PWM <= 0;
        end else begin
            if (r_counter_PWM >= 4'd9)
                r_counter_PWM <= 0;
            else 
                r_counter_PWM <= r_counter_PWM + 1;
        end
    end

    // 카운터가 입력된 duty 값보다 작을 때 High 출력
    assign PWM_OUT = (r_counter_PWM < auto_duty_in) ? 1'b1 : 1'b0;
    // assign PWM_OUT_LED = PWM_OUT;
    // assign DUTY_CYCLE = auto_duty_in;

endmodule

// 기존 코드
// `timescale 1ns / 1ps


// // 100Mhz/10 -- > 10Mhz의 주파수를 만든다.
// // 10Mhz는 100MHz의 10% 조절 해상더를 가질수 있는 최대 주파수
// // 0~9 까지 총 10번의 클럭을 세고

// module pwm_duty_control(
//     input clk,
//     input reset,
//     input duty_inc,
//     input duty_dec,
//     output [3:0] DUTY_CYCLE, // FND 출력 표시 0~9
//     output PWM_OUT,
//     output PWM_OUT_LED
// );

//     reg [3:0] r_DUTY_CYCLE = 4'd5;
//     reg [3:0] r_counter_PWM;

    
//     // edge 검출 register
//     reg r_prev_duty_inc, r_prev_duty_dec;

//     wire w_duty_inc = (duty_inc && !r_prev_duty_inc);    // rising edge
//     wire w_duty_dec = (duty_dec && !r_prev_duty_dec); 


//     // 1. duty cycle 제어 btnU, btnD
//     always @(posedge clk, posedge reset) begin
//         if (reset) begin
//             r_DUTY_CYCLE <= 4'd5; // 50% dutyI
//         end else begin
//             r_prev_duty_inc <= duty_inc; // 이전 상태 저장
//             r_prev_duty_dec <= duty_dec;

//             if (w_duty_inc && r_DUTY_CYCLE < 4'd9)
//             r_DUTY_CYCLE <= r_DUTY_CYCLE + 1;
//             if (w_duty_dec && r_DUTY_CYCLE > 4'd1)
//             r_DUTY_CYCLE <= r_DUTY_CYCLE -1;

//         end
//     end    


//     // 2. 10MHz PWM 신호 생성 (0~9)
//     always @(posedge clk, posedge reset) begin
//         if (reset) begin
//             r_counter_PWM <= 0;
//         end else begin
//             if (r_counter_PWM >= 4'd9)
//             r_counter_PWM <= 0;
//             else r_counter_PWM <= r_counter_PWM + 1;
//         end

//     end

// assign PWM_OUT = (r_counter_PWM < r_DUTY_CYCLE) ? 1'b1 : 1'b0; //실제 파형 만들기
// assign PWM_OUT_LED =  PWM_OUT; //LED와 연결
// assign DUTY_CYCLE = r_DUTY_CYCLE;


// endmodule

