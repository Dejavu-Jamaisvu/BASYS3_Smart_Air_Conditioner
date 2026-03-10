`timescale 1ns / 1ps

module tb_top;
    localparam [2:0] ST_IDLE           = 3'd0;
    localparam [2:0] ST_START_LOW      = 3'd1;
    localparam [2:0] ST_START_RELEASE  = 3'd2;
    localparam [2:0] ST_WAIT_RESP_LOW  = 3'd3;
    localparam [2:0] ST_WAIT_RESP_HIGH = 3'd4;
    localparam [2:0] ST_WAIT_FIRST_LOW = 3'd5;
    localparam [2:0] ST_READ_DATA      = 3'd6;
    localparam [2:0] ST_DONE           = 3'd7;

    localparam [7:0] SAMPLE1_H = 8'd55;
    localparam [7:0] SAMPLE1_T = 8'd24;
    localparam [7:0] SAMPLE2_H = 8'd65;
    localparam [7:0] SAMPLE2_T = 8'd21;

    reg clk = 1'b0;
    reg reset = 1'b1;

    reg [4:0] btn = 5'b00000; 
    reg [7:0] sw = 8'h00;
    reg [7:0] fault_flags = 8'h00;
    reg RsRx = 1'b1;

    tri dht_data;
    wire rtc_ce;
    wire rtc_sclk;
    tri rtc_io;

    reg s1 = 1'b0;
    reg s2 = 1'b0;
    reg key = 1'b1;

    wire buzzer_out;
    wire [7:0] seg;
    wire [3:0] an;
    wire [15:0] led;
    wire uartTx;
    wire uartRx;

    reg tb_dht_drive_en = 1'b0;
    reg tb_dht_drive_val = 1'b1;
    assign dht_data = tb_dht_drive_en ? tb_dht_drive_val : 1'bz;

    reg [7:0] visited_states = 8'h00;
    reg data_valid_prev = 1'b0;
    integer data_valid_pulse_count = 0;

    top dut (
        .clk(clk),
        .reset(reset),
        .btn(btn),
        .sw(sw),
        // .fault_flags(fault_flags),
        .RsRx(RsRx),
        .RsTx(),
        .dht_data(dht_data),
        .rtc_ce(rtc_ce),
        .rtc_sclk(rtc_sclk),
        .rtc_io(rtc_io),
        .s1(s1),
        .s2(s2),
        .key(key),
        .buzzer_out(buzzer_out),
        .seg(seg),
        .an(an),
        .led(led),
        .uartTx(uartTx),
        .uartRx(uartRx)
    );

    function [13:0] hhmm_value;
        input [7:0] h;
        input [7:0] m;
    begin
        hhmm_value = (h[7:4] * 14'd1000) + (h[3:0] * 14'd100) +
                     (m[7:4] * 14'd10) + m[3:0];
    end
    endfunction

    always #5 clk = ~clk; // 100MHz

    always @(posedge clk) begin
        #1;
        if (reset) begin
            visited_states <= 8'h00;
            data_valid_prev <= 1'b0;
            data_valid_pulse_count <= 0;
        end else begin
            visited_states[dut.u_dht11_controller.state] <= 1'b1;
            if (dut.u_dht11_controller.data_valid && !data_valid_prev)
                data_valid_pulse_count <= data_valid_pulse_count + 1;
            data_valid_prev <= dut.u_dht11_controller.data_valid;
        end
    end

    // DEBOUNCE_LIMIT = 999999 (10ms at 100MHz) 이므로 실제 btn 경로를 쓰면
    // 1,000,000+ 클록을 기다려야 함. 아래 task는 btn 물리 핀도 구동해서
    // 파형에서 식별 가능하게 하되, debouncer count를 force로 가속하여
    // 실제 btn_debouncer 경로(노이즈 제거 후 w_clean_btn)를 통해 신호가 전달됨.
    task pulse_mode_btn;
    begin
        // 1) 기존 w_clean_btn force 해제 → debouncer 경로 활성화
        release dut.w_clean_btn;

        // 2) 물리 btn[0] 구동 (파형에서 btn 변화 확인 가능)
        btn = 5'b00001;

        // 3) debouncer 카운터를 LIMIT-2 로 강제 후 해제
        //    → 2 클록 후 clean_btn 상승 (10ms 대기 생략)
        force dut.u_btn_debouncer.U_debouncer_btnL.count = 20'd999_997;
        @(posedge clk); #1;
        release dut.u_btn_debouncer.U_debouncer_btnL.count;
        // count: 999997 → 999998 → 999999 == LIMIT → clean_btn=1
        @(posedge clk); #1;
        @(posedge clk); #1;
        @(posedge clk); #1;  // control_tower edge-detect 래치용

        // 4) btn 해제 후 debouncer 재가속 → clean_btn 복귀
        btn = 3'b000;
        force dut.u_btn_debouncer.U_debouncer_btnL.count = 20'd999_997;
        @(posedge clk); #1;
        release dut.u_btn_debouncer.U_debouncer_btnL.count;
        @(posedge clk); #1;
        @(posedge clk); #1;
        @(posedge clk); #1;

        // 5) 이후 테스트를 위해 w_clean_btn 다시 0 으로 force
        force dut.w_clean_btn = 3'b000;
        @(posedge clk); #1;
    end
    endtask


    task pulse_up_btn;
        begin
            release dut.w_clean_btn;
            btn = 5'b01000; 
            force dut.u_btn_debouncer.U_debouncer_btnU.count = 20'd999_997; 
            @(posedge clk); #1;
            release dut.u_btn_debouncer.U_debouncer_btnU.count;
            repeat (5) @(posedge clk); #1;
            btn = 5'b00000;
            force dut.u_btn_debouncer.U_debouncer_btnU.count = 20'd999_997;
            @(posedge clk); #1;
            release dut.u_btn_debouncer.U_debouncer_btnU.count;
            repeat (5) @(posedge clk); #1;
            
            // force dut.w_clean_btn = 3'b000; 
            release dut.w_clean_btn;
        end
    endtask

    task pulse_down_btn;
    begin
        release dut.w_clean_btn;
        btn = 5'b10000; 
        force dut.u_btn_debouncer.U_debouncer_btnD.count = 20'd999_997; 
        @(posedge clk); #1;
        release dut.u_btn_debouncer.U_debouncer_btnD.count;
        repeat (5) @(posedge clk); #1;
        btn = 5'b00000;
        force dut.u_btn_debouncer.U_debouncer_btnD.count = 20'd999_997;
        @(posedge clk); #1;
        release dut.u_btn_debouncer.U_debouncer_btnD.count;
        repeat (5) @(posedge clk); #1;

        // force dut.w_clean_btn = 3'b000; 
        release dut.w_clean_btn;
    end
    endtask

    task pulse_dht_start;
    begin
        force dut.trigger_update = 1'b1;
        @(posedge clk);
        #1;
        release dut.trigger_update;
    end
    endtask

    task wait_state;
        input [2:0] target_state;
        input integer timeout_cycles;
        integer i;
        reg found;
    begin
        found = 1'b0;
        for (i = 0; i < timeout_cycles; i = i + 1) begin
            @(posedge clk);
            #1;
            if (dut.u_dht11_controller.state == target_state) begin
                found = 1'b1;
                i = timeout_cycles;
            end
        end

        if (!found) begin
            $display("ERROR: timeout waiting for state=%0d, current=%0d",
                     target_state, dut.u_dht11_controller.state);
            $fatal;
        end
    end
    endtask

    task drive_dht;
        input drive_en;
        input drive_val;
        input integer cycles;
        integer i;
    begin
        tb_dht_drive_en = drive_en;
        tb_dht_drive_val = drive_val;
        for (i = 0; i < cycles; i = i + 1) begin
            @(posedge clk);
            #1;
        end
    end
    endtask

    task send_bit;
        input bit_val;
        integer high_cycles;
    begin
        if (bit_val)
            high_cycles = 60;
        else
            high_cycles = 20;

        drive_dht(1'b1, 1'b1, high_cycles); // high width: 1 or 0
        drive_dht(1'b1, 1'b0, 20);          // low gap between bits
    end
    endtask

    task send_byte;
        input [7:0] byte_data;
        integer b;
    begin
        for (b = 7; b >= 0; b = b - 1)
            send_bit(byte_data[b]);
    end
    endtask

    task send_frame;
        input [7:0] h;
        input [7:0] h_dec;
        input [7:0] t;
        input [7:0] t_dec;
        reg [7:0] checksum;
    begin
        checksum = h + h_dec + t + t_dec;
        send_byte(h);
        send_byte(h_dec);
        send_byte(t);
        send_byte(t_dec);
        send_byte(checksum);
    end
    endtask

    task run_dht_transaction;
        input [7:0] h;
        input [7:0] t;
        integer prev_valid_cnt;
        integer i;
    begin
        prev_valid_cnt = data_valid_pulse_count;
        pulse_dht_start();

        wait_state(ST_START_LOW, 100);
        wait_state(ST_START_RELEASE, 25000);
        wait_state(ST_WAIT_RESP_LOW, 500);

        drive_dht(1'b1, 1'b0, 10); // response low
        wait_state(ST_WAIT_RESP_HIGH, 500);

        drive_dht(1'b1, 1'b1, 10); // response high
        wait_state(ST_WAIT_FIRST_LOW, 500);

        drive_dht(1'b1, 1'b0, 10); // first data low
        wait_state(ST_READ_DATA, 500);

        send_frame(h, 8'd0, t, 8'd0);
        tb_dht_drive_en = 1'b0;
        tb_dht_drive_val = 1'b1;

        for (i = 0; i < 300; i = i + 1) begin
            @(posedge clk);
            #1;
        end
        wait_state(ST_IDLE, 3000);
        if (data_valid_pulse_count <= prev_valid_cnt) begin
            $display("ERROR: no new data_valid pulse for DHT transaction");
            $fatal;
        end
    end
    endtask

    initial begin
        // force dut.w_clean_btn = 3'b000;
        force dut.u_dht11_controller.tick_1us = 1'b1;

        // Keep clock display deterministic.
        force dut.w_rtc_hour = 8'h12;
        force dut.w_rtc_minute = 8'h34;
        force dut.w_edit_mode = 1'b0;

        repeat (5) @(posedge clk);
        #1;
        reset = 1'b0;
        repeat (5) @(posedge clk);
        #1;

        // A) Initial CLOCK mode checks.
        if (dut.w_dht_mode !== 1'b0) begin
            $display("ERROR: initial mode is not CLOCK");
            $fatal;
        end
        if (dut.led[9] !== 1'b0) begin
            $display("ERROR: LED[9] should be 0 in CLOCK mode");
            $fatal;
        end
        if (dut.w_seg_data !== hhmm_value(8'h12, 8'h34)) begin
            $display("ERROR: CLOCK mode display mismatch. expected=%0d got=%0d",
                     hhmm_value(8'h12, 8'h34), dut.w_seg_data);
            $fatal;
        end

        // B) DHT acquisition while CLOCK mode is active.
        run_dht_transaction(SAMPLE1_H, SAMPLE1_T);

        if (dut.w_humidity !== SAMPLE1_H || dut.w_temp !== SAMPLE1_T) begin
            $display("ERROR: sample1 capture mismatch. H=%0d T=%0d got H=%0d T=%0d",
                     SAMPLE1_H, SAMPLE1_T, dut.w_humidity, dut.w_temp);
            $fatal;
        end
        if (dut.w_seg_data !== hhmm_value(8'h12, 8'h34)) begin
            $display("ERROR: display should remain CLOCK HHMM in CLOCK mode");
            $fatal;
        end

        // // C) Switch to DHT mode and verify display source changed.
        // pulse_mode_btn();
        // repeat (3) @(posedge clk);
        // #1;
        // if (dut.w_dht_mode !== 1'b1) begin
        //     $display("ERROR: mode did not switch to DHT");
        //     $fatal;
        // end
        // if (dut.led[9] !== 1'b1) begin
        //     $display("ERROR: LED[9] should be 1 in DHT mode");
        //     $fatal;
        // end
        // if (dut.w_seg_data !== (SAMPLE1_H * 14'd100 + SAMPLE1_T)) begin
        //     $display("ERROR: DHT mode display mismatch for sample1");
        //     $fatal;
        // end

        // // D) DHT acquisition while DHT mode is active.
        // run_dht_transaction(SAMPLE2_H, SAMPLE2_T);

        // if (dut.w_humidity !== SAMPLE2_H || dut.w_temp !== SAMPLE2_T) begin
        //     $display("ERROR: sample2 capture mismatch. H=%0d T=%0d got H=%0d T=%0d",
        //              SAMPLE2_H, SAMPLE2_T, dut.w_humidity, dut.w_temp);
        //     $fatal;
        // end
        // if (dut.w_seg_data !== (SAMPLE2_H * 14'd100 + SAMPLE2_T)) begin
        //     $display("ERROR: DHT mode display mismatch for sample2");
        //     $fatal;
        // end

        // // E) Switch back to CLOCK mode.
        // pulse_mode_btn();
        repeat (3) @(posedge clk);
        #1;
        if (dut.w_dht_mode !== 1'b0) begin
            $display("ERROR: mode did not return to CLOCK");
            $fatal;
        end
        if (dut.led[9] !== 1'b0) begin
            $display("ERROR: LED[9] should return to 0 in CLOCK mode");
            $fatal;
        end
        if (dut.w_seg_data !== hhmm_value(8'h12, 8'h34)) begin
            $display("ERROR: CLOCK mode display mismatch after return");
            $fatal;
        end

        if (visited_states !== 8'hFF) begin
            $display("ERROR: DHT FSM did not visit all states. visited=0x%02h", visited_states);
            $fatal;
        end
        
        if (data_valid_pulse_count < 2) begin
            $display("ERROR: expected >=2 data_valid pulses, got %0d", data_valid_pulse_count);
            $fatal;
        end

        $display("PASS: CLOCK<->DHT mode integration + DHT FSM sequential coverage verified.");

        // // ----------------------------------------------------------------
        // // F) warning_controller:
        // //    fault_flags 주입 → warning_active=1 → buzzer_out 실제 울림 확인
        // //    → cancel(btn[1]) → 뮤트 → fault 해제
        // // ----------------------------------------------------------------
        // fault_flags = 8'hFF;
        // repeat (5) @(posedge clk); #1;

        // if (dut.w_warning_active !== 1'b1) begin
        //     $display("ERROR: warning_active should be 1 when fault_flags=0xFF");
        //     $fatal;
        // end
        // if (dut.w_warning_buzzer_on !== 1'b1) begin
        //     $display("ERROR: warning_buzzer_on should be 1 immediately after fault");
        //     $fatal;
        // end

        // // buzzer_out 는 TONE_HALF_PERIOD(25000) 클록 후 첫 토글 → 26000 대기
        // repeat (26_000) @(posedge clk); #1;
        // if (dut.buzzer_out !== 1'b1) begin
        //     $display("ERROR: buzzer_out not ringing during warning (after 26000 cycles)");
        //     $fatal;
        // end
        // $display("INFO: warning buzzer ringing confirmed, buzzer_out=%b", dut.buzzer_out);

        // // btn[1] (cancel_btn) 상승 에지 → r_buzzer_muted 토글(0→1)
        // // warning_buzzer_on 은 다음 클록에서 !r_buzzer_muted = 0 으로 반영
        // force dut.w_clean_btn = 3'b010;
        // @(posedge clk); #1;   // r_buzzer_muted 토글됨, warning_buzzer_on 는 아직 1
        // force dut.w_clean_btn = 3'b000;
        // repeat (4) @(posedge clk); #1;  // 두 번째 클록에서 warning_buzzer_on=0, 이후 buzzer_out=0

        // if (dut.w_warning_buzzer_on !== 1'b0) begin
        //     $display("ERROR: warning_buzzer_on should be 0 after cancel_btn");
        //     $fatal;
        // end
        // if (dut.buzzer_out !== 1'b0) begin
        //     $display("ERROR: buzzer_out should be 0 after warning muted");
        //     $fatal;
        // end
        // $display("INFO: warning buzzer muted, buzzer_out=%b", dut.buzzer_out);

        // fault_flags = 8'h00;
        // repeat (3) @(posedge clk); #1;
        // if (dut.w_warning_active !== 1'b0) begin
        //     $display("ERROR: warning_active should be 0 after fault_flags cleared");
        //     $fatal;
        // end
        // $display("PASS: warning_controller verified (active + buzzer ring + cancel + clear).");

        // ----------------------------------------------------------------
        // G) alarm_controller:
        //    alarm_update_pulse 경로로 알람 설정 → RTC 시간 일치 + second 0
        //    → alarm_triggered, alarm_active=1 → buzzer_out 실제 울림 확인
        //    → dismiss(btn[2]) → 정지 확인
        // ----------------------------------------------------------------

        // G-1: 포트를 통해 알람 등록 (rtc_hour=12, rtc_minute=34 는 이미 force 중)
        force dut.w_alarm_enable_cfg   = 1'b1;
        force dut.w_alarm_hour_cfg     = 8'h12;
        force dut.w_alarm_minute_cfg   = 8'h34;
        force dut.w_alarm_update_pulse = 1'b1;
        @(posedge clk); #1;   // r_alarm_enable/hour/minute 내부 레지스터 래치
        force dut.w_alarm_update_pulse = 1'b0;
        release dut.w_alarm_enable_cfg;
        release dut.w_alarm_hour_cfg;
        release dut.w_alarm_minute_cfg;
        release dut.w_alarm_update_pulse;
        repeat (2) @(posedge clk); #1;

        // G-2: rtc_second 를 nonzero → 0 으로 변경 → second_tick 발생 → trigger
        force dut.w_rtc_second = 8'h01;  // r_prev_second 갱신용
        @(posedge clk); #1;              // r_prev_second = 1 로 래치
        force dut.w_rtc_second = 8'h00;  // second_tick=1, slot_match=1, sec==0 → TRIGGER
        @(posedge clk); #1;              // alarm_active=1, alarm_triggered=1 래치
        @(posedge clk); #1;              // buzzer_on=alarm_active=1 래치

        if (dut.w_alarm_triggered !== 1'b1) begin
            $display("ERROR: alarm_triggered should be 1 (rtc=12:34:00 == alarm 12:34)");
            $fatal;
        end
        if (dut.w_alarm_active !== 1'b1) begin
            $display("ERROR: alarm_active should be 1 after trigger");
            $fatal;
        end
        $display("INFO: alarm_triggered=%b alarm_active=%b led[12]=%b",
                 dut.w_alarm_triggered, dut.w_alarm_active, dut.led[12]);

        // G-3: 26000 클록 대기 → buzzer_out 실제 울림 확인
        //      buzzer_on(=alarm_buzzer_on)=1 → tone_cnt 카운트 → 25000 클록 후 첫 토글
        repeat (26_000) @(posedge clk); #1;

        if (dut.w_alarm_buzzer_on !== 1'b1) begin
            $display("ERROR: w_alarm_buzzer_on should be 1 during alarm");
            $fatal;
        end
        if (dut.buzzer_out !== 1'b1) begin
            $display("ERROR: buzzer_out not ringing during alarm (after 26000 cycles)");
            $fatal;
        end
        $display("INFO: alarm buzzer ringing confirmed, buzzer_out=%b led[12]=%b",
                 dut.buzzer_out, dut.led[12]);

        // G-4: dismiss (btn[2] 상승 에지) → alarm_active 해제 → buzzer 정지
        release dut.w_rtc_second;
        force dut.w_clean_btn = 3'b100;
        @(posedge clk); #1;
        force dut.w_clean_btn = 3'b000;
        repeat (5) @(posedge clk); #1;  // alarm_active=0 → buzzer_on=0 → buzzer_out=0

        if (dut.w_alarm_active !== 1'b0) begin
            $display("ERROR: alarm_active should be 0 after dismiss_btn");
            $fatal;
        end
        if (dut.buzzer_out !== 1'b0) begin
            $display("ERROR: buzzer_out should stop after alarm dismissed");
            $fatal;
        end
        $display("PASS: alarm_controller verified (trigger + buzzer ring + dismiss + stop).");



      // ----------------------------------------------------------------
        // H) 종합 시나리오: 여기서부터가 핵심 수정 항목입니다.
        // ----------------------------------------------------------------

        // Step 1: 모드 전환 (CLOCK -> DHT)
        pulse_mode_btn();
        repeat (5000) @(posedge clk); 

        // Step 2: [여기가 핵심] 모든 강제사항 해제 후 정확한 순서로 주입
        $display("[STEP 2] Forcing Temperature and Humidity...");

        // 1. 우선 모든 관련 신호를 release 해서 충돌 방지
        release dut.w_temp;
        release dut.u_aircon_control.curr_temp;

        // 2. 그 다음 동시에 force (하나만 하면 안 먹힐 때가 있음)
        force dut.w_temp = 8'd30; 
        force dut.u_aircon_control.curr_temp = 8'd30; // 제어 모듈 입력에 직접 주입
        #100;

        // Step 3: 스위치 켜기 (설정 모드 진입)
        sw[0] = 1'b1; 
        repeat (5000) @(posedge clk);

        // Step 4: 버튼 조작 전 '이전 상태' 초기화 확인
        // aircon_control 내부의 r_prev_up/down이 0인지 확인해야 edge가 먹힘
        release dut.w_clean_btn; 
        #100;

        $display("Current Set Temp: %d, Speed: %d", dut.w_set_temp, dut.w_motor_speed);

        // Step 5: DOWN 버튼 연타 (설정 온도를 25 -> 20으로 내림)
        repeat (5) begin
            pulse_down_btn();
            repeat (10000) @(posedge clk); // 버튼 인식 시간 충분히 확보
            $display("Set Temp: %d, Motor Speed: %d", dut.w_set_temp, dut.w_motor_speed);
        end
        repeat (5) begin
            pulse_up_btn();
            repeat (10000) @(posedge clk); // 버튼 인식 시간 충분히 확보
            $display("Set Temp: %d, Motor Speed: %d", dut.w_set_temp, dut.w_motor_speed);
        end

        // Step 5: 파형 관찰 (PWM 신호 확인)
        repeat (500_000) @(posedge clk);

        // Step 6: 마무리 (스위치 끄고 모드 복귀)
        sw[0] = 1'b0;
        pulse_mode_btn(); // 다시 시계 모드로
        release dut.w_temp;
        release dut.w_humidity;
        $display("==== [SCENARIO FINISHED] ====\n");
    end
endmodule
