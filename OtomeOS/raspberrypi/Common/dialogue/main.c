#include <pigpio.h>
#include <stdlib.h>
#include "proto.h"

volatile int go_dialogue=0, go_face=0;

static void isr_dialogue(int gpio,int level,uint32_t tick){ if(level==0) go_dialogue=1; }
static void isr_face(int gpio,int level,uint32_t tick){ if(level==0) go_face=1; }

int main(){
  if (gpioInitialise()<0) return 1;

  oled_init(); tft_init();
  oled_print("Otome OS v1.0","Press a button");

  gpioSetMode(BTN_DIALOGUE, PI_INPUT);
  gpioSetPullUpDown(BTN_DIALOGUE, PI_PUD_UP);
  gpioSetMode(BTN_FACE, PI_INPUT);
  gpioSetPullUpDown(BTN_FACE, PI_PUD_UP);

  gpioSetAlertFunc(BTN_DIALOGUE, isr_dialogue);
  gpioSetAlertFunc(BTN_FACE, isr_face);

  for(;;){
    if(go_dialogue){
      go_dialogue=0;
      // record 4s wav and POST to phone
      record_audio("/tmp/clip.wav");
      oled_print("Sending audio..", NULL);
      post_file(DIALOGUE_EP, "audio", "/tmp/clip.wav");
      // placeholder menu until you parse JSON (keep it visual)
      tft_menu("Ask about project","Share progress","Compliment outfit",0);
    }
    if(go_face){
      go_face=0;
      take_photo("/tmp/shot.jpg");
      oled_print("Sending photo..", NULL);
      post_file(RECOG_EP, "photo", "/tmp/shot.jpg");
    }
    gpioDelay(10000); // 10 ms
  }
  gpioTerminate();
  return 0;
}