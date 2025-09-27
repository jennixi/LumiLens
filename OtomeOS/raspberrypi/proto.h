#pragma once
// set to your iPhone's LAN IP shown in the app
#define PHONE_URL "http://192.168.1.45:8080"
#define DIALOGUE_EP PHONE_URL "/dialogueAudio"
#define ENROLL_EP   PHONE_URL "/enroll"
#define RECOG_EP    PHONE_URL "/recognize"

// GPIO (adjust if you wired differently)
#define BTN_DIALOGUE 23
#define BTN_FACE     24

// forward decls common helpers
int post_file(const char* url, const char* field, const char* path);
void oled_init(); void oled_print(const char* l1, const char* l2);
void tft_init();  void tft_menu(const char* a,const char* b,const char* c,int sel);

// dialogue helpers
int record_audio(const char* path);
// face helpers
int take_photo(const char* path);