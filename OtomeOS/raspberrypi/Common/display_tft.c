// Minimal ST7789 wrapper; assumes you pulled a driver that exposes these.
#include "st7789.h"  // from drivers/rpi_st7789
void tft_init(){ st7789_init(); st7789_fill(0xFFFF); }

void tft_menu(const char* a, const char* b, const char* c, int sel){
  st7789_fill(0xFFFF); // white bg
  // draw 3 lines; selected in red (0xF800), others black
  st7789_draw_string(10,30, a ? a : "", sel==0?0xF800:0x0000);
  st7789_draw_string(10,60, b ? b : "", sel==1?0xF800:0x0000);
  st7789_draw_string(10,90, c ? c : "", sel==2?0xF800:0x0000);
}