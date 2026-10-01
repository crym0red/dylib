SDKROOT := $(shell xcrun --sdk iphoneos --show-sdk-path)
CC := xcrun --sdk iphoneos clang
CFLAGS := -fobjc-arc -fmodules -O2 -Wall -Wextra -Wno-unused-parameter \
          -isysroot "$(SDKROOT)" -miphoneos-version-min=15.0
FRAMEWORKS := -framework Foundation -framework UIKit -framework QuartzCore

BUILD := build
TARGET := $(BUILD)/DELvEKTheme.dylib
SRC := Sources/DELvEKTheme.m

.PHONY: all clean

all: $(TARGET)

$(BUILD):
	mkdir -p $(BUILD)

$(TARGET): $(SRC) Sources/DELvEKTheme.h | $(BUILD)
	$(CC) $(CFLAGS) -dynamiclib $(SRC) $(FRAMEWORKS) \
		-install_name @rpath/DELvEKTheme.dylib \
		-current_version 1.0 -compatibility_version 1.0 \
		-o "$@"
	xcrun --sdk iphoneos lipo "$@" -info

clean:
	rm -rf $(BUILD)
