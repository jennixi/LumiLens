# OtomeOS Hackathon Project

Magical girl–style communication-assist glasses.  
Two halves: Raspberry Pi hardware (C) + iPhone app (Swift).

---

## Raspberry Pi (C)
- Buttons → GPIO
- I²C OLED (SSD1306) → recognition text
- SPI TFT (ST7789) → dialogue choices
- Camera snapshot (`libcamera-still`)
- Audio capture (`arecord`)
- Sends requests → iPhone app via Wi-Fi

### Build & run
```bash
cd raspberrypi
make
sudo ./otome


### THE SKELETON
otomeos-hackathon/
├── README.md
├── raspberrypi/
│   ├── Makefile
│   ├── proto.h
│   ├── common/
│   │   ├── net.c
│   │   ├── display_oled.c
│   │   ├── display_tft.c
│   │   └── (u8g2 + st7789 drivers here or as submodules)
│   ├── dialogue/           # dialogue half
│   │   ├── main.c
│   │   └── audio.c
│   └── face/               # face-rec half
│       └── camera.c
└── iphone/
    ├── OtomePhoneSwift.xcodeproj
    ├── App/
    │   ├── OtomePhoneSwiftApp.swift
    │   └── ContentView.swift
    ├── Server/
    │   └── WebServerManager.swift
    ├── dialogue/
    │   ├── DialogueServer.swift
    │   └── DialogueAI.swift
    └── face/
        ├── FaceServer.swift
        ├── FaceModels.swift
        ├── FaceStore.swift
        └── FaceRecognition.swift

        [ Raspberry Pi ] --Wi-Fi--> [ iPhone app (Swifter server) ]
   |                           |
 buttons + sensors             AI + face recognition + storage
 displays text/options          sends JSON back