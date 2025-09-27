#include <stdio.h>
#include <stdlib.h>

int take_photo(const char* path){
  char cmd[256];
  snprintf(cmd,sizeof(cmd),"libcamera-still -n -o %s --width 640 --height 480 >/dev/null 2>&1", path);
  return system(cmd);
}