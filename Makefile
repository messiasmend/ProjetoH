ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:14.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = ProjetoH

ProjetoH_FILES = Tweak.xm \
    Sources/PHThreeFingerGesture.m \
    Sources/PHOverlayManager.m \
    Sources/PHV15Patch.m \
    Sources/PHV16ButtonOrderFix.m

ProjetoH_CFLAGS = -fobjc-arc
ProjetoH_FRAMEWORKS = UIKit Foundation WebKit

include $(THEOS_MAKE_PATH)/tweak.mk

INSTALL_TARGET_PROCESSES =
