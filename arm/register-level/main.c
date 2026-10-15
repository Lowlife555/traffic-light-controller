#include "stm32l476xx.h"
#include <stdint.h>
#include <stdio.h>



// Font matrix 6*8

const uint8_t Font6x8[][6] = {
    [0x20-0x20] = {0x00,0x00,0x00,0x00,0x00,0x00},
    [0x25-0x20] = {0x23,0x13,0x08,0x64,0x62,0x00},
    [0x2D-0x20] = {0x00,0x00,0x08,0x08,0x08,0x00},
    [0x30-0x20] = {0x00,0x3E,0x51,0x49,0x45,0x3E}, [0x31-0x20] = {0x00,0x00,0x42,0x7F,0x40,0x00},
    [0x32-0x20] = {0x00,0x42,0x61,0x51,0x49,0x46}, [0x33-0x20] = {0x00,0x21,0x41,0x45,0x4B,0x31},
    [0x34-0x20] = {0x00,0x18,0x14,0x12,0x7F,0x10}, [0x35-0x20] = {0x00,0x27,0x45,0x45,0x45,0x39},
    [0x36-0x20] = {0x00,0x3C,0x4A,0x49,0x49,0x30}, [0x37-0x20] = {0x00,0x01,0x71,0x09,0x05,0x03},
    [0x38-0x20] = {0x00,0x36,0x49,0x49,0x49,0x36}, [0x39-0x20] = {0x00,0x06,0x49,0x49,0x29,0x1E},
    [0x3A-0x20] = {0x00,0x00,0x24,0x00,0x00,0x00},
    ['A'-0x20] = {0x7E,0x11,0x11,0x11,0x7E,0x00}, ['C'-0x20] = {0x3E,0x41,0x41,0x41,0x22,0x00},
    ['D'-0x20] = {0x7F,0x41,0x41,0x22,0x1C,0x00}, ['E'-0x20] = {0x7F,0x49,0x49,0x49,0x41,0x00},
    ['F'-0x20] = {0x7F,0x09,0x09,0x09,0x01,0x00}, ['G'-0x20] = {0x3E,0x41,0x49,0x49,0x7A,0x00},
    ['H'-0x20] = {0x7F,0x08,0x08,0x08,0x7F,0x00}, ['I'-0x20] = {0x00,0x41,0x7F,0x41,0x00,0x00},
    ['L'-0x20] = {0x7F,0x40,0x40,0x40,0x40,0x00}, ['M'-0x20] = {0x7F,0x02,0x04,0x02,0x7F,0x00},
    ['O'-0x20] = {0x3E,0x41,0x41,0x41,0x3E,0x00}, ['P'-0x20] = {0x7F,0x09,0x09,0x09,0x06,0x00},
    ['R'-0x20] = {0x7F,0x09,0x19,0x29,0x46,0x00}, ['S'-0x20] = {0x46,0x49,0x49,0x49,0x31,0x00},
    ['T'-0x20] = {0x01,0x01,0x7F,0x01,0x01,0x00}, ['W'-0x20] = {0x3F,0x40,0x38,0x40,0x3F,0x00},
    ['Y'-0x20] = {0x07,0x08,0x70,0x08,0x07,0x00}
};

typedef enum { STATE_IDLE,STATE_FLASH,STATE_YELLOW,STATE_PED} TrafficState_t;  //naming of different state
const char* StateNames[] = {"IDLE", "FLASH", "YELLOW", "PED-CROSS"};

// 2026.4.1 测试发现全局变量在中断中修改后值不对，添加volatile防止编译器优化
volatile TrafficState_t currentState = STATE_IDLE;
volatile uint32_t timer_ms = 0; volatile uint8_t tl_sec = 0;
volatile uint32_t raw_adc_value = 0; volatile uint8_t adc_req = 0;
volatile uint32_t ms_ticks = 0; volatile uint8_t ped_req = 0;        //"state reg"

void OLED_Write(uint8_t mode, uint8_t data) {
    I2C1->CR2 = (0x78 << 0) | (2 << 16) | I2C_CR2_START | I2C_CR2_AUTOEND;
    while(!(I2C1->ISR & I2C_ISR_TXIS));
    I2C1->TXDR = mode;
    while(!(I2C1->ISR & I2C_ISR_TXIS));
    I2C1->TXDR = data;
    while(!(I2C1->ISR & I2C_ISR_STOPF));
    // 2026.3.29 OLED只能发一次数据         添加清除STOPCF标志
    I2C1->ICR |= I2C_ICR_STOPCF;   //stop flag clear
}

void OLED_SetCursor(uint8_t page, uint8_t col) {
    OLED_Write(0x00, 0xB0 + page);   //0x00->command,0xB0->display the current state
    OLED_Write(0x00, col & 0x0F);      //
    OLED_Write(0x00, 0x10 | (col >> 4));
}

void OLED_Clear(void) {
    for(uint8_t i=0; i<8; i++) {
        OLED_SetCursor(i, 0);
        for(uint8_t j=0; j<128; j++) OLED_Write(0x40, 0x00);
    }
}



//display a character
void OLED_ShowChar(uint8_t page, uint8_t col, char c) {
    uint8_t is_valid = 0;
    if(c == 0x20 || c == 0x25 || c == 0x2D || c == 0x3A) is_valid = 1;
    if(c >= '0' && c <= '9') is_valid = 1;
    if(c >= 'A' && c <= 'Z') {
        switch(c) {
            case 'A': case 'C': case 'D': case 'E': case 'F': case 'G':
            case 'H': case 'I': case 'L': case 'M': case 'O': case 'P':
            case 'R': case 'S': case 'T': case 'W': case 'Y':
                is_valid = 1; break;
        }
    }
    if(!is_valid) c = 0x20;
    
    OLED_SetCursor(page, col);
    for(uint8_t i=0; i<6; i++) OLED_Write(0x40, Font6x8[c-0x20][i]);//why 6 ?, because 6 means a character cost 6 columns wide
}

void OLED_ShowString(uint8_t page, uint8_t col, const char* str) {
    while(*str) {
        OLED_ShowChar(page, col, *str++);
        col += 6; if(col > 122) break;
    }
}

void OLED_Init(void) {
    uint8_t cmds[] = {0xAE,0xD5,0x80,0xA8,0x3F,0xD3,0x00,0x40,0x8D,0x14,0xAF,0xA1,0xC8};   //0xAE: open  0xAF: close, rest:sanding commands to OLED by OLED-WRITE
    for(int i=0; i<sizeof(cmds); i++) OLED_Write(0x00, cmds[i]);
    OLED_Clear();
}



//80Mhz To achieve the standard 1ms,
void SystemClock_Config_80MHz(void) {
    // 2026.3.30 测试系统时钟到80MHz            添加Flash等待状态
    FLASH->ACR |= FLASH_ACR_LATENCY_4WS;
    RCC->PLLCFGR = (RCC_PLLCFGR_PLLSRC_MSI | (0 << 4) | (40 << 8) | (0 << 25));
    RCC->CR |= RCC_CR_PLLON;
    while(!(RCC->CR & RCC_CR_PLLRDY));
    RCC->PLLCFGR |= RCC_PLLCFGR_PLLREN;
    RCC->CFGR |= RCC_CFGR_SW_PLL;
    while((RCC->CFGR & RCC_CFGR_SWS) != RCC_CFGR_SWS_PLL);
}




//GPIO MODE REG: 
//MODER: 00=INPUT  01=OUTPUT 11=ANALOG
//PUPDR:  00=NO PULL  01=PULL UP 10=PULL DOWN  11=STAY
void GPIO_Init(void) {
    RCC->AHB2ENR |= (RCC_AHB2ENR_GPIOAEN | RCC_AHB2ENR_GPIOBEN | RCC_AHB2ENR_GPIOCEN);
	//ENABLE A,B GPIO
    
    GPIOA->MODER &= ~((3<<8) | (3<<10) | (3<<12) | (3<<14));
    GPIOA->MODER |=  ((1<<8) | (1<<10) | (1<<12) | (1<<14));    //PA4-7
    // 2026.3.25 测试蜂鸣器上电         初始化为BS4（高电平）
    GPIOA->BSRR = GPIO_BSRR_BS4;  //BUZZER
    
    GPIOB->MODER &= ~((3<<12) | (3<<14)); GPIOB->MODER |= ((1<<12) | (1<<14));
    
    GPIOA->MODER &= ~((3<<0) | (3<<16)); GPIOA->PUPDR |= ((1<<0) | (1<<16));
    GPIOC->MODER &= ~(3<<26); GPIOC->PUPDR |= (1<<26);
    
    GPIOA->MODER |= (3<<2); GPIOA->ASCR |= (1<<1);
    
    
	
	//I2C
	//<<16 <<18 => 16-17, 18-19 POSITION IS BINARY:11 , OTHER POSITION IS ZERO
	
	GPIOB->MODER &= ~((3<<16) | (3<<18)); GPIOB->MODER |= ((2<<16) | (2<<18));      //&= Perform a bitwise AND operation with a original register
    // 2026.3.26 测试I2C    无法通信    改OTYPER ---开漏
    GPIOB->OTYPER |= (1<<8) | (1<<9);
    // 2026.3.27 测试I2C   不通，修改AFR为AF4     AF ==  Alternate Function Mode
	
    GPIOB->AFR[1] |= (4<<0) | (4<<4);
}



void ADC1_Init(void) {
    RCC->AHB2ENR |= RCC_AHB2ENR_ADCEN;  //ON AHB2 BUS
    RCC->CCIPR |= (3 << 28);
    ADC1->CR &= ~ADC_CR_DEEPPWD;
    ADC1->CR |= ADC_CR_ADVREGEN;
    for(volatile int i=0; i<5000; i++);
    ADC1->CR |= ADC_CR_ADCAL;
    // 2026.3.30 测试ADC读数      添加等待校准完成
    while(ADC1->CR & ADC_CR_ADCAL);  //ADCAL == CALIBRATE ADC
    ADC1->SQR1 = (6 << 6);
    ADC1->CR |= ADC_CR_ADEN;     //regular sequence reg
    while(!(ADC1->ISR & ADC_ISR_ADRDY));  //ADC READY
}

void I2C1_Init(void) {
    RCC->APB1ENR1 |= RCC_APB1ENR1_I2C1EN;
    I2C1->TIMINGR = 0x10D1143A;
    I2C1->CR1 |= I2C_CR1_PE;
}

void Timer3_Init(void) {
    RCC->APB1ENR1 |= RCC_APB1ENR1_TIM3EN;
    TIM3->PSC = 80 - 1;                   //prescaler
    TIM3->ARR = 1000 - 1;
    TIM3->DIER |= TIM_DIER_UIE;
    TIM3->CR1 |= TIM_CR1_CEN;
    NVIC_EnableIRQ(TIM3_IRQn);
}





//STATE Output Logic
void Apply_Hardware_State(TrafficState_t state) {
    GPIOA->BSRR = (GPIO_BSRR_BR5 | GPIO_BSRR_BR6 | GPIO_BSRR_BR7);
    GPIOB->BSRR = (GPIO_BSRR_BR6 | GPIO_BSRR_BR7);
    if (state != STATE_PED) {
        GPIOA->BSRR = GPIO_BSRR_BS4;
        GPIOB->BSRR = GPIO_BSRR_BS7;
    } else {
        GPIOB->BSRR = GPIO_BSRR_BS6;
        GPIOA->BSRR = GPIO_BSRR_BS7;
    }
    switch(state) {
        case STATE_IDLE: GPIOA->BSRR = GPIO_BSRR_BS5; break;        //CAR GREEN
        case STATE_YELLOW: GPIOA->BSRR = GPIO_BSRR_BS6; break;           //CAR YELLOW
        default: break;
    }
}

void TIM3_IRQHandler(void) {
    static uint16_t button_filter = 0;
    if (TIM3->SR & TIM_SR_UIF) {
        // 2026.3.28  无限进中断，添加清除UIF标志
        TIM3->SR &= ~TIM_SR_UIF;
        ms_ticks++; timer_ms++;
        if (ms_ticks % 100 == 0) adc_req = 1;

        if (!(GPIOA->IDR & (1<<0)) || !(GPIOA->IDR & (1<<8)) || !(GPIOC->IDR & (1<<13))) {
            if (++button_filter > 20) { button_filter = 0; ped_req = 1; }
        } else button_filter = 0;
        
        if (currentState == STATE_PED) ped_req = 0;

        uint8_t tick = 0;
        if (timer_ms >= 1000) { timer_ms = 0; tick = 1; }

		
		
		
		//!!!CORE FSM!!!
        switch (currentState) {
            case STATE_IDLE:
                Apply_Hardware_State(STATE_IDLE);
                uint8_t dynamic_wait = 5 + ((( (raw_adc_value * 8) / 4095 ) * 15) >> 3);
                if (ped_req) {
                    if (tl_sec == 0 || tl_sec > dynamic_wait) tl_sec = dynamic_wait;
                    if (tick) {                                                            //CHECK TIM TICK
                        if (tl_sec == 1) {                                                 //CHECK COUNT DOWN
                            currentState = STATE_FLASH;                                    //JUMP TO FLASH
                            // 2026.4.2 测试状态切换后倒计时不对     修：tl_sec赋值为3
                            tl_sec = 3;
                        }
                        else tl_sec--;
                    }
                } else tl_sec = 0;
                break;

            case STATE_FLASH:
                if (timer_ms % 250 == 0) GPIOA->ODR ^= GPIO_ODR_OD5;
                if (tick) {
                    if (tl_sec <= 1) { currentState = STATE_YELLOW; tl_sec = 2; }
                    else tl_sec--;
                }
                break;

            case STATE_YELLOW:
                Apply_Hardware_State(STATE_YELLOW);
                if (tick) {
                    if (tl_sec <= 1) { currentState = STATE_PED; tl_sec = 5; }    //next state logic
                    else tl_sec--;
                }
                break;

            case STATE_PED:
                Apply_Hardware_State(STATE_PED);
                if (tl_sec <= 3) {
                    if ((timer_ms % 250) < 50) GPIOA->BSRR = GPIO_BSRR_BR4;
                    else GPIOA->BSRR = GPIO_BSRR_BS4;
                } else {
                    if ((timer_ms % 500) < 100) GPIOA->BSRR = GPIO_BSRR_BR4;
                    else GPIOA->BSRR = GPIO_BSRR_BS4;
                }
                if (tick) {
                    if (tl_sec <= 1) { currentState = STATE_IDLE; tl_sec = 0; GPIOA->BSRR = GPIO_BSRR_BS4; }
                    else tl_sec--;
                }
                break;
        }
    }
}

int main(void) {
    SystemClock_Config_80MHz(); GPIO_Init(); ADC1_Init(); I2C1_Init(); OLED_Init(); Timer3_Init();

    char buf[20];
    OLED_ShowString(0, 0, "TRAFFIC LIGHT SYSTEM");
    OLED_ShowString(2, 0, "STATE:"); OLED_ShowString(4, 0, "TIMER:"); OLED_ShowString(6, 0, "TRAFF:");

    while (1) {
        if (adc_req) {                                //ask whether the signal sent
            adc_req = 0;                              //return 0 means cpoy that
            ADC1->CR |= ADC_CR_ADSTART;
            while(!(ADC1->ISR & ADC_ISR_EOC));
            raw_adc_value = ADC1->DR;               //DR => DATA REG

            OLED_ShowString(2, 42, "          ");
            OLED_ShowString(2, 42, StateNames[currentState]);

            if (currentState == STATE_IDLE && !ped_req) OLED_ShowString(4, 42, "-- S ");
            else { sprintf(buf, "%02d S ", tl_sec); OLED_ShowString(4, 42, buf); }

            uint8_t traffic_pct = (raw_adc_value * 100) / 4095;
            sprintf(buf, "%d%%  ", traffic_pct); OLED_ShowString(6, 42, buf);

            uint8_t bar_len = (raw_adc_value * 50) / 4095;
            OLED_SetCursor(6, 77);
            for(uint8_t i=0; i<50; i++) OLED_Write(0x40, (i < bar_len) ? 0x7E : 0x00);
        }
    }
}