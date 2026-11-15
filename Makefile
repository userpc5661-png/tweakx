TARGET := iphone:clang:latest:14.0
ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = RiseYT

RiseYT_FILES = Tweak.x
RiseYT_CFLAGS = -fobjc-arc -I./headers
RiseYT_FRAMEWORKS = UIKit Foundation AVFoundation Photos MediaPlayer Security WebKit AVKit UserNotifications BackgroundTasks
RiseYT_PRIVATE_FRAMEWORKS = SpringBoard
RiseYT_LIBRARIES = substrate

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 YouTube"
