export TARGET = iphone:clang:14.0:14.0
export ARCHS = arm64 arm64e
export THEOS_DEVICE_IP = 0

INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

# ─── Main Tweak ───────────────────────────────────────────────────
TWEAK_NAME = Beegram

Beegram_FILES = Beegram.x
Beegram_CFLAGS = -fobjc-arc -Wno-unused-variable -Wno-deprecated-declarations
Beegram_CCFLAGS = -std=c++17
Beegram_FRAMEWORKS = \
    Foundation \
    UIKit \
    QuartzCore \
    AVFoundation \
    AVKit \
    Photos \
    UserNotifications \
    Security \
    WebKit \
    CoreVideo \
    CoreMedia \
    CoreImage \
    AuthenticationServices \
    Speech \
    MediaPlayer \
    CoreLocation \
    Accelerate \
    AudioToolbox \
    CoreGraphics \
    ImageIO
Beegram_LIBRARIES = z c++ substrate
Beegram_INSTALL_PATH = /Library/MobileSubstrate/DynamicLibraries

# ─── NSE Subproject ───────────────────────────────────────────────
SUBPROJECTS = BeegramNSE

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 Instagram || true"
