// SSD1306 (I2C) via u8g2 linux i2c backend
#include <u8g2.h>
#include <u8x8.h>

static u8g2_t u8g2;

void oled_init(){
  u8g2_Setup_ssd1306_i2c_128x64_noname_f(&u8g2, U8G2_R0,
     u8x8_byte_linux_i2c, u8x8_linux_gpio_and_delay);
  // address 0x3C (shifted for u8x8 api)
  u8x8_SetI2CAddress(u8g2_GetU8x8(&u8g2), 0x3C<<1);
  u8g2_InitDisplay(&u8g2);
  u8g2_SetPowerSave(&u8g2,0);
  u8g2_ClearBuffer(&u8g2);
  u8g2_SendBuffer(&u8g2);
}

void oled_print(const char* l1, const char* l2){
  u8g2_ClearBuffer(&u8g2);
  u8g2_SetFont(&u8g2, u8g2_font_6x12_tf);
  if(l1) u8g2_DrawStr(&u8g2, 0, 14, l1);
  if(l2) u8g2_DrawStr(&u8g2, 0, 28, l2);
  u8g2_SendBuffer(&u8g2);
}