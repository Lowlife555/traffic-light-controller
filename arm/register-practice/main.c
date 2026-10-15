#include "stm32L476xx.h"  // 引入STM32L476xx器件头文件
int main(void){
  int i;
  int time=0x1FFFF;  // 延时计数阈值

  RCC->AHB2ENR |= RCC_AHB2ENR_GPIOAEN;  // 开启GPIOA的时钟
  GPIOA->MODER &= ~(3<<10);              // 清除引脚5的两个模式位
  GPIOA->MODER |= 1U<<10;                // 将引脚5设置为输出模式(01)，原文笔误为pir 5

  while(1)
  {
    GPIOA->ODR ^= 1UL<<5;  // 翻转GPIOA引脚5的输出电平
    for(i=0;i<time;i++);    // 简易延时循环
  }
}