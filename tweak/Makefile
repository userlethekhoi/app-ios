export THEOS ?= $(HOME)/.theos/theos

TARGET := iphone:clang:latest:15.0
ARCHS := arm64
THEOS_PACKAGE_SCHEME ?= rootless

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = IAPCheck
IAPCheck_FILES = Tweak.xm
IAPCheck_FRAMEWORKS = UIKit StoreKit Foundation CoreFoundation
IAPCheck_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
INSTALL_TARGET_PROCESSES = storekitd itunesstored

include $(THEOS_MAKE_PATH)/tweak.mk
