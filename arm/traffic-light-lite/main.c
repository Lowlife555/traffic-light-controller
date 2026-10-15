#include "stm32l476xx.h"
#include <stdint.h>

// FSM 状态定义
typedef enum { 
    STATE_CAR_GREEN,   // 默认：车绿灯，人红灯
    STATE_CAR_YELLOW,  // 过渡：车黄灯，人红灯 (2s)
    STATE_PED_CROSS    // 行人：车红灯，人绿灯，蜂鸣器响 (5s)
} TrafficState_t;

volatile uint32_t ms_ticks = 0;

// SysTick 中断服务函数 (每 1ms 触发一次)
void SysTick_Handler(void) {
    ms_ticks++;
}

// 80MHz 系统时钟配置 (保留自你的参考代码)
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
    // 1. 开启 GPIOA, GPIOB, GPIOC 的时钟
    RCC->AHB2ENR |= (RCC_AHB2ENR_GPIOAEN | RCC_AHB2ENR_GPIOBEN | RCC_AHB2ENR_GPIOCEN);
    
    // 2. 配置 PA11(人红), PA12(人绿), PA13(车绿), PA14(车黄), PA15(车红) 为通用输出模式 (01)
    GPIOA->MODER &= ~((3U << 22) | (3U << 24) | (3U << 26) | (3U << 28) | (3U << 30));
    GPIOA->MODER |=  ((1U << 22) | (1U << 24) | (1U << 26) | (1U << 28) | (1U << 30));
    
    // 3. 配置 PB12 (蜂鸣器) 为通用输出模式 (01)
    GPIOB->MODER &= ~(3U << 24);
    GPIOB->MODER |=  (1U << 24);
    GPIOB->BSRR = (1U << 12); // 默认拉高 PB12，关闭低电平触发的蜂鸣器
    
    // 4. 配置 PC2, PC3 为输入模式 (00)
    GPIOC->MODER &= ~((3U << 4) | (3U << 6));
    // 为 PC2, PC3 开启内部上拉电阻 (01) - 假设按钮按下是接地
    GPIOC->PUPDR &= ~((3U << 4) | (3U << 6));
    GPIOC->PUPDR |=  ((1U << 4) | (1U << 6));
}

// 辅助函数：根据状态控制 LED 亮灭
void Set_Lights(TrafficState_t state) {
    // 先将所有灯熄灭 (向 BSRR 的高 16 位写入 1，即 BRy 位)
    GPIOA->BSRR = ((1U<<11) | (1U<<12) | (1U<<13) | (1U<<14) | (1U<<15)) << 16;
    
    switch(state) {
        case STATE_CAR_GREEN:
            GPIOA->BSRR = (1U << 13) | (1U << 11); // PA13(车绿)亮, PA11(人红)亮
            break;
        case STATE_CAR_YELLOW:
            GPIOA->BSRR = (1U << 14) | (1U << 11); // PA14(车黄)亮, PA11(人红)亮
            break;
        case STATE_PED_CROSS:
            GPIOA->BSRR = (1U << 15) | (1U << 12); // PA15(车红)亮, PA12(人绿)亮
            break;
    }
}

int main(void) {
    // 初始化系统时钟与外设
    SystemClock_Config_80MHz();
    SysTick_Config(80000); // 80MHz 下，配置 SysTick 为 1ms 中断
    GPIO_Init();

    TrafficState_t currentState = STATE_CAR_GREEN;
    uint32_t state_timer = 0;
    
    // 初始状态
    Set_Lights(currentState);

    while (1) {
        switch (currentState) {
            case STATE_CAR_GREEN:
                // 检测行人按钮是否被按下 (由于开启了上拉，按下时为低电平)
                if (!(GPIOC->IDR & (1U << 2)) || !(GPIOC->IDR & (1U << 3))) {
                    currentState = STATE_CAR_YELLOW; // 切换到黄灯状态
                    state_timer = ms_ticks;          // 记录当前时间
                    Set_Lights(currentState);
                }
                
                // 确保蜂鸣器安静
                GPIOB->BSRR = (1U << 12); 
                break;

            case STATE_CAR_YELLOW:
                // 黄灯持续 2s (2000ms)
                if ((ms_ticks - state_timer) >= 2000) {
                    currentState = STATE_PED_CROSS;  // 切换到行人过街状态
                    state_timer = ms_ticks;          // 记录当前时间
                    Set_Lights(currentState);
                }
                break;

            case STATE_PED_CROSS:
                // 无源蜂鸣器发声逻辑：利用 ms_ticks 每 1ms 翻转一次电平 (500Hz)
                if (ms_ticks % 2 == 0) {
                    GPIOB->BSRR = (1U << 12);        // 设置为高
                } else {
                    GPIOB->BSRR = (1U << 28);        // 设置为低 (BSRR高16位的第12位，即清零)
                }

                // 行人过街持续 5s (5000ms)
                if ((ms_ticks - state_timer) >= 5000) {
                    currentState = STATE_CAR_GREEN;  // 回到默认状态
                    Set_Lights(currentState);
                }
                break;
        }
    }
}