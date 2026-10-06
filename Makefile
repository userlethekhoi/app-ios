export THEOS ?= $(HOME)/.theos/theos
TARGET := iphone:clang:latest:16.0
ARCHS := arm64 arm64e

THEOS_PACKAGE_SCHEME ?= rootless

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = NappStore

NappStore_FILES = $(shell find Sources -name '*.swift')
NappStore_FRAMEWORKS = UIKit SwiftUI Foundation CoreServices StoreKit
NappStore_RESOURCE_FILES = Info.plist AppIcon.png CatalogData
# TrollStore / jailbreak installs need the binary to carry the no-sandbox and
# platform-application entitlements or the app stays inside its container and
# cannot reach the shared IAPCheck bridge directories. The development IPA
# path (build_ipa.sh) still strips them because real Apple Development
# profiles refuse those keys.
NappStore_CODESIGN_FLAGS = -S$(THEOS_PROJECT_DIR)/entitlements.tipa.plist


include $(THEOS_MAKE_PATH)/application.mk
