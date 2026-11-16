export TARGET = iphone:clang:14.0:14.0
export ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = BeegramNSE

BeegramNSE_FILES = BeegramNSE.x
BeegramNSE_CFLAGS = -fobjc-arc -Wno-unused-variable -Wno-deprecated-declarations
BeegramNSE_FRAMEWORKS = Foundation UserNotifications Security
BeegramNSE_LIBRARIES = z substrate
BeegramNSE_INSTALL_PATH = /Library/MobileSubstrate/DynamicLibraries
BeegramNSE_BUNDLE_FILTER = com.apple.UNNotificationServiceExtension

include $(THEOS_MAKE_PATH)/tweak.mk
