`timescale 1ns / 1ps

module fnd_controller(
    input clk,
    input reset,  // sw[15]

    //input tick,
    input tick_1ms,        // Digit 스캐닝용
    input tick_50ms,       // 애니메이션 속도용
    input circle_mode,     // 애니메이션 모드 활성화

    input [13:0] in_data, // 현재 금액 (coin_val)
    output [3:0] an,
    output [7:0] seg    
    );

    wire [1:0] w_sel;
    wire [3:0] w_d1, w_d10, w_d100, w_d1000; 

    wire [3:0] an_bcd, an_ani;
    wire [7:0] seg_bcd, seg_ani;


    fnd_digit_select u_fnd_digit_select(
        // .clk(clk),
        .reset(reset),
        .tick(tick_1ms),

        .sel(w_sel)    // 00 01 10 11 : 1ms마다  바뀜 
    ); 

     bin2bcd4digit u_bin2bcd4digit(
        .in_data(in_data), ////.in_data(in_data[13:0])

        .d1(w_d1),
        .d10(w_d10),
        .d100(w_d100),
        .d1000(w_d1000)
    );

    fnd_digit_diaply u_fnd_digit_diaply(
        .digit_sel(w_sel),
        .d1(w_d1),
        .d10(w_d10),
        .d100(w_d100),
        .d1000(w_d1000),

        .an(an_bcd),
        .seg(seg_bcd)
    );
    
    fnd_circle_animation u_fnd_circle_animation(
        .clk(clk),
        .reset(reset),
        .tick(tick_50ms),

        .digit_sel(w_sel),
        .an(an_ani),
        .seg(seg_ani)
    );

    //coffee_make = 1이면 애니메이션 세그먼트, 아니면 BCD 숫자 세그먼트 출력
    assign an  = (circle_mode) ? an_ani  : an_bcd;
    assign seg = (circle_mode) ? seg_ani : seg_bcd;

endmodule



//------------------------------------------
// 1ms마다 fnd를 display하기 위해서 digit 1자리씩 선택 하는 logic 
// 4ms까지는 잔상 효과가 있다. 그 이상의 시간 지연을 주면 깜박임 현상 발생 주의 요함
//------------------------------------------
module fnd_digit_select (
//    input clk,
    input reset,
    input tick,
    output reg  [1:0] sel    // 00 01 10 11 : 1ms마다  바뀜 
);
    // reg[$clog2(100_000):0]  r_1ms_counter=0;

    // always @(posedge clk, posedge reset, posedge tick) begin
        // if (reset) begin
        //     r_1ms_counter <= 0;
        //     sel <= 0;
        // end else begin
        //     if (r_1ms_counter == 100_000-1) begin  // 1ms
        //         r_1ms_counter <= 0;
        //         sel <= sel + 1; 
        //     end else begin
        //         r_1ms_counter <= r_1ms_counter + 1;
        //     end 
        // end 
    always @(posedge reset, posedge tick) begin
         if (reset) begin
            sel <= 0;
        end else begin
            if (tick) begin  // 1ms
                sel <= sel + 1; 
            end 
        end        
    end
    
endmodule 



//------------------------------------
// input [13:0] in_data : 14 bit fnd에 9999 까지 표현 하기 위한 bin size
//  0~9999 천/백/십/일  자리숫자 0~9 까지 BCD로 4 bit표현
//------------------------------------
module bin2bcd4digit (
    input [13:0] in_data,
    output [3:0] d1,
    output [3:0] d10,
    output [3:0] d100,
    output [3:0] d1000
);
    assign d1 = in_data % 10;
    assign d10 = ( in_data / 10 )  % 10;
    assign d100 = ( in_data / 100 )  % 10;
    assign d1000 = ( in_data / 1000 )  % 10;
endmodule 



module fnd_digit_diaply (
    input [1:0] digit_sel,
    input [3:0] d1,
    input [3:0] d10,
    input [3:0] d100,
    input [3:0] d1000,
    output reg [3:0] an,
    output reg [7:0] seg
);

    reg [3:0] bcd_data; 

    always @(digit_sel)  begin  // digit_sel값이 바뀔떄는 언제나 실행 한다. 
        case (digit_sel)
            2'b00: begin
                bcd_data = d1;
                an = 4'b1110; 
            end
            2'b01: begin
                bcd_data = d10;
                an = 4'b1101; 
            end
            2'b10: begin
                bcd_data = d100;
                an = 4'b1011; 
            end
            2'b11: begin
                bcd_data = d1000;
                an = 4'b0111; 
            end
            default: begin
                bcd_data = 4'b0000;
                an = 4'b1111; 
            end
        endcase 
    end 

    always @(bcd_data) begin
        case(bcd_data)
            4'd0: seg = 8'b11000000;   // 0
            4'd1: seg = 8'b11111001;   // 1
            4'd2: seg = 8'b10100100;   // 2
            4'd3: seg = 8'b10110000;   // 3
            4'd4: seg = 8'b10011001;   // 4
            4'd5: seg = 8'b10010010;   // 5
            4'd6: seg = 8'b10000010;   // 6
            4'd7: seg = 8'b11111000;   // 7
            4'd8: seg = 8'b10000000;   // 8
            4'd9: seg = 8'b10010000;   // 9
            default: seg = 8'b11111111;  // all off  
        endcase 
    end 
endmodule



module fnd_circle_animation(
    input clk,
    input reset,
    input tick,           // 애니메이션 속도 (50ms)
    input [1:0] digit_sel, // 1ms 스캐닝 신호 (11:1000, 10:100, 01:10, 00:1)
    output reg [3:0] an,
    output reg [7:0] seg
);

    reg [3:0] r_ani_step; // 0~11까지 (총 12단계)

    always @(posedge clk or posedge reset) begin
        if(reset) r_ani_step <= 0;
        else if(tick) begin
            if(r_ani_step >= 11) r_ani_step <= 0;
            else r_ani_step <= r_ani_step + 1;
        end
    end


    always @(*) begin
        an = 4'b1111;
        seg = 8'b11111111; // Active Low (1이 꺼짐)

        case(r_ani_step)
            4'd0:  if(digit_sel == 2'b11) begin an = 4'b0111; seg = 8'b11011111; end // 1000번 F
            4'd1:  if(digit_sel == 2'b11) begin an = 4'b0111; seg = 8'b11111110; end // 1000번 A
            4'd2:  if(digit_sel == 2'b10) begin an = 4'b1011; seg = 8'b11111110; end // 100번 A
            4'd3:  if(digit_sel == 2'b01) begin an = 4'b1101; seg = 8'b11111110; end // 10번 A
            4'd4:  if(digit_sel == 2'b00) begin an = 4'b1110; seg = 8'b11111110; end // 1번 A
            4'd5:  if(digit_sel == 2'b00) begin an = 4'b1110; seg = 8'b11111101; end // 1번 B
            4'd6:  if(digit_sel == 2'b00) begin an = 4'b1110; seg = 8'b11111011; end // 1번 C
            4'd7:  if(digit_sel == 2'b00) begin an = 4'b1110; seg = 8'b11110111; end // 1번 D
            4'd8:  if(digit_sel == 2'b01) begin an = 4'b1101; seg = 8'b11110111; end // 10번 D
            4'd9:  if(digit_sel == 2'b10) begin an = 4'b1011; seg = 8'b11110111; end // 100번 D
            4'd10: if(digit_sel == 2'b11) begin an = 4'b0111; seg = 8'b11110111; end // 1000번 D
            4'd11: if(digit_sel == 2'b11) begin an = 4'b0111; seg = 8'b11101111; end // 1000번 E
            default: ;
        endcase
    end
endmodule



// 각각 4자리 서클 애니메이션
// module fnd_circle_animation(
//     input clk,
//     input reset,
//     input tick,       // 애니메이션 속도 결정 (20Hz)
//     input [1:0] digit_sel,  // 1ms 스캔 신호와 동기화
//     output reg [3:0] an,
//     output reg [7:0] seg
// );

//     reg [2:0] r_ani_cnt;


//     // 1. 회전 상태 카운터 (0~5 순환)
//     always @(posedge clk or posedge reset) begin
//         if(reset) begin
//             r_ani_cnt <= 0;
//         end else if(tick) begin
//             if(r_ani_cnt >= 5) r_ani_cnt <= 0;
//             else r_ani_cnt <= r_ani_cnt + 1;
//         end
//     end

//     // 2. Anode 제어 (FND 4개 위치 스캐닝)
//     always @(*) begin
//         case(digit_sel)
//             2'b00: an = 4'b1110;
//             2'b01: an = 4'b1101;
//             2'b10: an = 4'b1011;
//             2'b11: an = 4'b0111;
//             default: an = 4'b1111;
//         endcase
//     end

//     // 3. 서클 패턴 (Active Low)
//     // a -> b -> c -> d -> e -> f 순서로 회전
//     always @(*) begin
//         case(r_ani_cnt)
//             3'd0: seg = 8'b11111110; // a 세그먼트
//             3'd1: seg = 8'b11111101; // b 세그먼트
//             3'd2: seg = 8'b11111011; // c 세그먼트
//             3'd3: seg = 8'b11110111; // d 세그먼트
//             3'd4: seg = 8'b11101111; // e 세그먼트
//             3'd5: seg = 8'b11011111; // f 세그먼트
//             default: seg = 8'b11111111;
//         endcase
//     end

// endmodule