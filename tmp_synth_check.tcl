create_project -in_memory -part xc7a35tcpg236-1
read_verilog {
  d:/workspace/BASYS3_Smart_Air_Conditioner/17.smart_air_conditioner/17.smart_air_conditioner.srcs/sources_1/imports/uart_rx/btn_debounce.v
  d:/workspace/BASYS3_Smart_Air_Conditioner/17.smart_air_conditioner/17.smart_air_conditioner.srcs/sources_1/imports/uart_rx/control_tower.v
  d:/workspace/BASYS3_Smart_Air_Conditioner/17.smart_air_conditioner/17.smart_air_conditioner.srcs/sources_1/imports/uart_rx/alarm_controller.v
  d:/workspace/BASYS3_Smart_Air_Conditioner/17.smart_air_conditioner/17.smart_air_conditioner.srcs/sources_1/imports/uart_rx/buzzer_driver.v
  d:/workspace/BASYS3_Smart_Air_Conditioner/17.smart_air_conditioner/17.smart_air_conditioner.srcs/sources_1/imports/uart_rx/ds1302_rtc.v
  d:/workspace/BASYS3_Smart_Air_Conditioner/17.smart_air_conditioner/17.smart_air_conditioner.srcs/sources_1/imports/uart_rx/rotary_time_setter.v
  d:/workspace/BASYS3_Smart_Air_Conditioner/17.smart_air_conditioner/17.smart_air_conditioner.srcs/sources_1/imports/uart_rx/rtc_command_parser.v
  d:/workspace/BASYS3_Smart_Air_Conditioner/17.smart_air_conditioner/17.smart_air_conditioner.srcs/sources_1/imports/uart_rx/rtc_display.v
  d:/workspace/BASYS3_Smart_Air_Conditioner/17.smart_air_conditioner/17.smart_air_conditioner.srcs/sources_1/imports/uart_rx/rtc_time_sender.v
  d:/workspace/BASYS3_Smart_Air_Conditioner/17.smart_air_conditioner/17.smart_air_conditioner.srcs/sources_1/imports/uart_rx/tick_generator.v
  d:/workspace/BASYS3_Smart_Air_Conditioner/17.smart_air_conditioner/17.smart_air_conditioner.srcs/sources_1/imports/uart_rx/uart_controller.v
  d:/workspace/BASYS3_Smart_Air_Conditioner/17.smart_air_conditioner/17.smart_air_conditioner.srcs/sources_1/imports/uart_rx/uart_rx.v
  d:/workspace/BASYS3_Smart_Air_Conditioner/17.smart_air_conditioner/17.smart_air_conditioner.srcs/sources_1/imports/uart_rx/uart_tx.v
  d:/workspace/BASYS3_Smart_Air_Conditioner/17.smart_air_conditioner/17.smart_air_conditioner.srcs/sources_1/imports/uart_rx/warning_controller.v
  d:/workspace/BASYS3_Smart_Air_Conditioner/17.smart_air_conditioner/17.smart_air_conditioner.srcs/sources_1/new/dht11_controller.v
  d:/workspace/BASYS3_Smart_Air_Conditioner/17.smart_air_conditioner/17.smart_air_conditioner.srcs/sources_1/new/fnd_controller.v
  d:/workspace/BASYS3_Smart_Air_Conditioner/17.smart_air_conditioner/17.smart_air_conditioner.srcs/sources_1/imports/uart_rx/top.v
}
read_xdc d:/workspace/BASYS3_Smart_Air_Conditioner/17.smart_air_conditioner/17.smart_air_conditioner.srcs/constrs_1/imports/uart_rx/basys3.xdc
synth_design -top top -part xc7a35tcpg236-1
exit
