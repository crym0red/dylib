SDK := iphoneos
SDKROOT := $(shell xcrun --sdk $(SDK) --show-sdk-path)
CC := xcrun --sdk $(SDK) clang
ARCHS := arm64
MIN_IOS := 15.0
CFLAGS := -arch $(ARCHS) -fobjc-arc -fmodules -O2 -Wall -Wextra -Wno-deprecated-declarations -Wno-unused-parameter \
          -isysroot "$(SDKROOT)" -miphoneos-version-min=$(MIN_IOS)
LDFLAGS := -dynamiclib -framework Foundation -framework UIKit -framework QuartzCore \
           -install_name @rpath/DELvEKTheme.dylib -current_version 1.0.0 -compatibility_version 1.0.0

BUILD := build
TARGET := $(BUILD)/DELvEKTheme.dylib
SRC := Sources/DELvEKTheme.m
HDR := Sources/DELvEKTheme.h

.PHONY: all clean

all: $(TARGET)

$(BUILD):
	mkdir -p "$@"

$(TARGET): $(SRC) $(HDR) | $(BUILD)
	$(CC) $(CFLAGS) $(LDFLAGS) $(SRC) -o "$@"
	file "$@"
	xcrun lipo -info "$@"

clean:
	rm -rf "$(BUILD)"
