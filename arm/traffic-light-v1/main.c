#include "stm32l476xx.h"
#include <stdint.h>

// FSM 状态定义
typedef enum { 
    STATE_CAR_GREEN,   // 默认：车绿灯(PB3)，人红灯(PA11)
    STATE_CAR_YELLOW,  // 过渡：车黄灯(PB4)，人红灯(PA11) (2s)
    STATE_PED_CROSS    // 行人：车红灯(PB5)，人绿灯(PA12)，蜂鸣器(PB12)响 (5s)
} TrafficState_t;

volatile uint32_t ms_ticks = 0;

// SysTick 中断服务函数 (每 1ms 触发一次)
void SysTick_Handler(void) {
    ms_ticks++;
}

// 80MHz 系统时钟配置
void SystemClock_Config_80MHz(void) {
    FLASH->ACR |= FLASH_ACR_LATENCY_4WS;
    RCC->PLLCFGR = (RCC_PLLCFGR_PLLSRC_MSI | (0 << 4) | (40 << 8) | (0 << 25)); 
    RCC->CR |= RCC_CR_PLLON;
    while(!(RCC->CR & RCC_CR_PLLRDY));
    RCC->PLLCFGR |= RCC_PLLCFGR_PLLREN;
    RCC->CFGR |= RCC_CFGR_SW_PLL;
    while((RCC->CFGR & RCC_CFGR_SWS) != RCC_CFGR_SWS_PLL);
}

// 硬件 GPIO 寄存器初始化
void GPIO_Init(void) {
    // 开启 GPIOA, GPIOB, GPIOC 时钟
    RCC->AHB2ENR |= (RCC_AHB2ENR_GPIOAEN | RCC_AHB2ENR_GPIOBEN | RCC_AHB2ENR_GPIOCEN);

    // 1. 人行灯 PA11(红), PA12(绿) 配置为输出
    GPIOA->MODER &= ~(GPIO_MODER_MODE11 | GPIO_MODER_MODE12);
    GPIOA->MODER |=  (GPIO_MODER_MODE11_0 | GPIO_MODER_MODE12_0);

    // 2. 车行灯 PB3(绿), PB4(黄), PB5(红) 配置为输出
    GPIOB->MODER &= ~(GPIO_MODER_MODE3 | GPIO_MODER_MODE4 | GPIO_MODER_MODE5);
    GPIOB->MODER |=  (GPIO_MODER_MODE3_0 | GPIO_MODER_MODE4_0 | GPIO_MODER_MODE5_0);

    // 3. 蜂鸣器 PB12 配置为输出
    GPIOB->MODER &= ~(GPIO_MODER_MODE12);
    GPIOB->MODER |=  (GPIO_MODER_MODE12_0);
    GPIOB->BSRR = GPIO_BSRR_BS12; // 默认拉高（低电平触发，所以先关掉）

    // 4. 行人按钮 PC2, PC3 配置为输入 + 内部上拉
    GPIOC->MODER &= ~(GPIO_MODER_MODE2 | GPIO_MODER_MODE3);
    GPIOC->PUPDR &= ~(GPIO_PUPDR_PUPD2 | GPIO_PUPDR_PUPD3);
    GPIOC->PUPDR |=  (GPIO_PUPDR_PUPD2_0 | GPIO_PUPDR_PUPD3_0);
}

// 状态切换时的灯光控制
void Set_Lights(TrafficState_t state) {
    // 关闭所有相关 LED (PA11,12 和 PB3,4,5)
    GPIOA->BRR = (GPIO_BRR_BR11 | GPIO_BRR_BR12);
    GPIOB->BRR = (GPIO_BRR_BR3 | GPIO_BRR_BR4 | GPIO_BRR_BR5);
    
    switch(state) {
        case STATE_CAR_GREEN:
            GPIOB->BSRR = GPIO_BSRR_BS3;  // PB3 绿灯亮
            GPIOA->BSRR = GPIO_BSRR_BS11; // PA11 人行红灯亮
            break;
        case STATE_CAR_YELLOW:
            GPIOB->BSRR = GPIO_BSRR_BS4;  // PB4 黄灯亮
            GPIOA->BSRR = GPIO_BSRR_BS11; // PA11 人行红灯亮
            break;
        case STATE_PED_CROSS:
            GPIOB->BSRR = GPIO_BSRR_BS5;  // PB5 红灯亮
            GPIOA->BSRR = GPIO_BSRR_BS12; // PA12 人行绿灯亮
            break;
    }
}

int main(void) {
    SystemClock_Config_80MHz();
    SysTick_Config(80000); // 1ms 滴答
    GPIO_Init();

    TrafficState_t currentState = STATE_CAR_GREEN;
    uint32_t state_timer = 0;
    
    // 进入初始状态
    Set_Lights(currentState);

    while (1) {
        switch (currentState) {
            case STATE_CAR_GREEN:
                // 按钮检测 (PC2 或 PC3 按下为低电平)
                if (!(GPIOC->IDR & (GPIO_IDR_ID2)) || !(GPIOC->IDR & (GPIO_IDR_ID3))) {
                    currentState = STATE_CAR_YELLOW;
                    state_timer = ms_ticks;
                    Set_Lights(currentState);
                }
                // 确保蜂鸣器关闭 (PB12 为高电平)
                GPIOB->BSRR = GPIO_BSRR_BS12;
                break;

            case STATE_CAR_YELLOW:
                // 等待 2s
                if ((ms_ticks - state_timer) >= 2000) {
                    currentState = STATE_PED_CROSS;
                    state_timer = ms_ticks;
                    Set_Lights(currentState);
                }
                break;

            case STATE_PED_CROSS:
                // 无源蜂鸣器：1ms 周期翻转实现约 500Hz 鸣叫
                if (ms_ticks % 2 == 0) {
                    GPIOB->BSRR = GPIO_BSRR_BS12; // 高
                } else {
                    GPIOB->BRR = GPIO_BRR_BR12;   // 低 (触发)
                }

                // 等待 5s 过街时间
                if ((ms_ticks - state_timer) >= 5000) {
                    currentState = STATE_CAR_GREEN;
                    Set_Lights(currentState);
                }
                break;
        }
    }
}