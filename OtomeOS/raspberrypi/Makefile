CFLAGS  = -O2 -Wall -I./ -I./common -I./drivers/u8g2/csrc -I./drivers/rpi_st7789
LDFLAGS = -lpigpio -lpthread -lcurl

SRC_COMMON = common/net.c common/display_oled.c common/display_tft.c \
             drivers/u8g2/csrc/u8g2.c drivers/u8g2/csrc/u8x8.c \
             drivers/u8g2/csrc/u8x8_byte.c drivers/u8g2/csrc/u8x8_gpio.c
SRC_DIALOGUE = dialogue/main.c dialogue/audio.c
SRC_FACE = face/camera.c

BIN = otome

all: $(BIN)
$(BIN): $(SRC_COMMON) $(SRC_DIALOGUE) $(SRC_FACE)
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS)

clean:
	rm -f $(BIN)