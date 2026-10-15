# Traffic Light Controller — ARM (register level) + FPGA (Verilog)

A traffic-light intersection controller implemented **twice**, on two completely different platforms, as Year-2 undergraduate coursework (EL2242 – Digital Systems / Embedded Systems):

1. **Bare-metal ARM firmware** on an STM32 — written directly against CMSIS registers (no HAL), driven by a finite-state machine.
2. **FPGA logic** in Verilog for an Altera/Intel Cyclone board — a synthesisable FSM with ADC-based traffic-density sensing, a 6-digit seven-segment display and a buzzer.

The two halves are independent implementations of the same specification, which is why the repository contains several design iterations of each.

## Repository layout

```
arm/
  register-level/       main traffic-light FSM written with raw CMSIS register access  (Keil MDK project)
  traffic-light-lite/   compact version of the same controller (4 KB of main.c)
  traffic-light-v1/     first working ARM version, own Keil project (traffic_light_V1)
  register-practice/    minimal register-level bring-up sketch used while learning CMSIS
fpga/
  quartus-v2/           most complete Verilog design (traffic_light_V2.v, ~15 KB)
  quartus-vg/           refined design split into drivers (top + ADC + buzzer + display)
  quartus-vg-demo/      earlier demo build of the same design, includes an OLED driver
  simulation/           simplified standalone version used for simulation
```

## ARM implementation

- **Target:** STM32, Keil MDK-ARM project (`.uvprojx`), CMSIS startup and device headers under `RTE/`.
- **Style:** register-level (`RCC`, `GPIO`, `TIM` written by hand) — no ST HAL, no CubeMX-generated code.
- **Logic:** a finite-state machine stepping through the intersection phases (vehicle red / amber / green, pedestrian phases) with timer-driven delays.
- The repository keeps several iterations (`v1` → `lite` → `register-level`) so the development history is visible.

## FPGA implementation (Verilog)

| Module | Role |
|---|---|
| `traffic_lights_VG.v` / `traffic_light_V2.v` | Top-level traffic-light FSM: automatic timed mode **plus** pedestrian-request mode, 50 MHz clock, asynchronous active-low reset |
| `adc_081s021_driver.v` | SPI driver for an **ADC081S021** ADC — reads the potentiometer that sets the base vehicle-green duration |
| `display_6digit_driver.v` | 6-digit seven-segment display multiplexer — shows the countdown timer normally, and switches to the raw traffic-flow reading while the potentiometer is being turned |
| `buzzer_pwm_driver.v` | PWM buzzer output (pedestrian-crossing beeper) |
| `oled_disp_driver.v` | OLED status display (demo build only) |
| `tb_traffic_lights.v` | Testbench placeholder (waveform verification was done with `Waveform1.vwf`) |

**Control features implemented in the FPGA design**

- Dual mode: fully automatic timing **or** pedestrian push-button request on either of two crossing buttons.
- A **vehicle-density sensor** input (button-simulated) dynamically extends / truncates the green phase.
- A potentiometer read through the SPI ADC sets the base green time — the display switches to show the raw ADC value while it is adjusted, so the effect is visible on the board.
- Quartus pin assignments are kept as `.tcl` scripts (`pin_assignment.tcl`, `pin_planner.tcl`) so a fresh project can be constrained in one command.

## How to build

- **ARM:** open the `.uvprojx` in Keil MDK-ARM (requires the matching STM32 device pack), build and flash. `RTE/` provides the startup file and CMSIS headers; the HAL/CMSIS library itself is not vendored.
- **FPGA:** open the `.qpf` in Intel/Altera Quartus, or recreate it and run the provided `pin_assignment.tcl`. `.qsf` files list the pin assignments and device settings.

## Notes

- Build artefacts (`db/`, `incremental_db/`, `output_files/`, `Objects/`, `Listings/`, `*.sof`, `*.hex`, …) and the course assignment brief and report are intentionally **not** committed — see `.gitignore`.
- The FPGA design was verified on hardware and through a Quartus simulation waveform; the committed testbench is only a placeholder.

---

# 交通灯控制器 —— ARM（寄存器级）+ FPGA（Verilog）

同一个交通灯路口控制器，用**两种完全不同的平台各实现了一遍**：大二课程作业（EL2242 数字系统 / 嵌入式系统）。

1. **裸机 ARM 固件**：STM32，**直接操作 CMSIS 寄存器**（不用 HAL），由有限状态机驱动。
2. **FPGA 逻辑**：Altera/Intel Cyclone 开发板上的可综合 Verilog —— FSM + ADC 车流检测 + 6 位数码管 + 蜂鸣器。

两部分是同一份需求书的两个独立实现，所以仓库里保留了各自的多个迭代版本。

## 仓库结构

```
arm/
  register-level/       主交通灯 FSM，直接写 CMSIS 寄存器（Keil MDK 工程）
  traffic-light-lite/   同一控制器的精简版（main.c 约 4 KB）
  traffic-light-v1/     第一个能跑的 ARM 版本，独立 Keil 工程（traffic_light_V1）
  register-practice/    学 CMSIS 时的最小寄存器点灯例程
fpga/
  quartus-v2/           最完整的 Verilog 设计（traffic_light_V2.v，约 15 KB）
  quartus-vg/           改进版，拆成多个驱动模块（顶层 + ADC + 蜂鸣器 + 数码管）
  quartus-vg-demo/      同一设计的早期演示版，额外带 OLED 驱动
  simulation/           用于仿真的简化独立版本
```

## ARM 实现

- **目标**：STM32，Keil MDK-ARM 工程（`.uvprojx`），启动文件与设备头文件在 `RTE/`。
- **风格**：寄存器级（`RCC`、`GPIO`、`TIM` 全部手写），不用 ST HAL，不用 CubeMX 生成代码。
- **逻辑**：有限状态机按路口相位推进（机动车红/黄/绿、行人相位），用定时器做延时。
- 仓库保留了多个迭代（`v1` → `lite` → `register-level`），能看到演进过程。

## FPGA 实现（Verilog）

| 模块 | 作用 |
|---|---|
| `traffic_lights_VG.v` / `traffic_light_V2.v` | 顶层交通灯 FSM：自动定时模式 **+** 行人请求模式，50 MHz 时钟，异步低电平复位 |
| `adc_081s021_driver.v` | **ADC081S021** 的 SPI 驱动 —— 读电位器，用来设定机动车绿灯基础时长 |
| `display_6digit_driver.v` | 6 位数码管动态扫描 —— 平时显示倒计时，拧电位器时切换显示车流原始数据 |
| `buzzer_pwm_driver.v` | PWM 蜂鸣器输出（行人过街提示音） |
| `oled_disp_driver.v` | OLED 状态显示（仅演示版） |
| `tb_traffic_lights.v` | 测试平台占位文件（当时用 `Waveform1.vwf` 做波形验证） |

**FPGA 设计实现的控制功能**

- 双模式：完全自动定时 **或** 两个行人按钮之一的请求过街。
- **车流检测**输入（用按键模拟）动态延长 / 缩短绿灯相位。
- 通过 SPI ADC 读电位器设定绿灯基础时长 —— 调节时数码管切换显示 ADC 原始值，板上能直接看到效果。
- Quartus 引脚分配保存为 `.tcl` 脚本（`pin_assignment.tcl`、`pin_planner.tcl`），新建工程后可一条命令完成约束。

## 如何编译

- **ARM**：用 Keil MDK-ARM 打开 `.uvprojx`（需要装对应的 STM32 器件包）后编译下载。`RTE/` 里给了启动文件和 CMSIS 头文件；HAL/CMSIS 库本身没有随仓库附带。
- **FPGA**：用 Intel/Altera Quartus 打开 `.qpf`，或新建工程后跑附带的 `pin_assignment.tcl`。`.qsf` 里是引脚分配与器件设置。

## 说明

- 编译产物（`db/`、`incremental_db/`、`output_files/`、`Objects/`、`Listings/`、`*.sof`、`*.hex` …）以及课程任务书与报告**有意未入库**，见 `.gitignore`。
- FPGA 设计在硬件上和 Quartus 仿真波形里都验证过；仓库里提交的测试平台只是占位文件。
