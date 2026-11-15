# RiseYT dylib intended for embedding into a signed YouTube IPA.
TARGET := iphone:clang:latest:14.0
ARCHS := arm64

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = RiseYT
RiseYT_FILES = Tweak.x
RiseYT_CFLAGS = -fobjc-arc -I./headers
RiseYT_FRAMEWORKS = UIKit Foundation AVFoundation CoreMedia Photos AVKit UserNotifications
# Internal Logos generator does not need an external CydiaSubstrate library.
RiseYT_GENERATOR = internal

include $(THEOS_MAKE_PATH)/tweak.mk
