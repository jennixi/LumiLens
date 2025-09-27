#include <stdio.h>
#include <stdlib.h>

int record_audio(const char* path){
  char cmd[256];
  snprintf(cmd,sizeof(cmd),"arecord -d 4 -f cd -t wav %s >/dev/null 2>&1", path);
  return system(cmd);
}