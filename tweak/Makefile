export THEOS ?= $(HOME)/.theos/theos

TARGET := iphone:clang:latest:15.0
ARCHS := arm64
THEOS_PACKAGE_SCHEME ?= rootless

include $(THEOS)/makefiles/common.mk

# Two substrate modules share one source file. MobileSubstrate AND-matches
# Bundles+Executables in a single plist, so daemon injection needs its own
# dylib/plist pair or it never loads anywhere (daemons don't link UIKit).
TWEAK_NAME = IAPCheck IAPCheckDaemon
IAPCheck_FILES = Tweak.xm
IAPCheckDaemon_FILES = Tweak.xm
IAPCheck_FRAMEWORKS = UIKit StoreKit Foundation CoreFoundation
IAPCheckDaemon_FRAMEWORKS = UIKit StoreKit Foundation CoreFoundation
IAPCheck_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
IAPCheckDaemon_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
INSTALL_TARGET_PROCESSES = storekitd itunesstored

include $(THEOS_MAKE_PATH)/tweak.mk
