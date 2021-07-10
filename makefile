FRAMEWORK_PATH        = -F/System/Library/PrivateFrameworks
FRAMEWORK             = -framework Carbon -framework Cocoa -framework CoreServices -framework SkyLight -framework ScriptingBridge
BUILD_FLAGS           = -std=c99 -Wall -g -O0 -fvisibility=hidden -mmacosx-version-min=10.13
BUILD_PATH            = ./bin
DOC_PATH              = ./doc
SCRIPT_PATH           = ./scripts
ASSET_PATH            = ./assets
SMP_PATH              = ./examples
ARCH_PATH             = ./archive
OSAX_PATH             = ./src/osax
CLANG_PATH            = /Library/Developer/CommandLineTools/usr/bin/clang
SDK_PATH              = $(shell xcrun --sdk macosx --show-sdk-path)

OSAX_X86_64_SRC       = $(OSAX_PATH)/sa_loader.c $(OSAX_PATH)/sa_mach_bootstrap.c $(OSAX_PATH)/sa_payload.c
YABAI_X86_64_SRC      = ./src/manifest.m $(OSAX_X86_64_SRC)

OSAX_ARM_INJECTOR_SRC = $(OSAX_PATH)/arm64/injector.o
OSAX_ARM_SA_SRC       = $(OSAX_PATH)/arm64/sa_arm64e.h $(OSAX_PATH)/arm64/sa_arm64e.o
OSAX_ARM_SRC          = $(OSAX_PATH)/arm64/injector.o $(OSAX_PATH)/sa_payload.c
YABAI_ARM_SRC         = ./src/manifest.m $(OSAX_ARM_SRC)

BINS                  = $(BUILD_PATH)/yabai $(BUILD_PATH)/yabai-x86_64 $(BUILD_PATH)/yabai-arm64

.PHONY: all clean install sign archive man

all: clean-build $(BINS)

install: BUILD_FLAGS=-std=c99 -Wall -DNDEBUG -O2 -fvisibility=hidden -mmacosx-version-min=10.13
install: clean-build $(BINS)

$(OSAX_X86_64_SRC): $(OSAX_PATH)/loader.m $(OSAX_PATH)/mach_bootstrap.c $(OSAX_PATH)/payload.m
	$(CLANG_PATH) $(OSAX_PATH)/loader.m -shared -O2 -mmacosx-version-min=10.13 -arch x86_64 -o $(OSAX_PATH)/loader -isysroot "$(SDK_PATH)" -framework Foundation
	$(CLANG_PATH) $(OSAX_PATH)/mach_bootstrap.c -shared -fPIC -O2 -mmacosx-version-min=10.13 -arch x86_64 -o $(OSAX_PATH)/mach_bootstrap -isysroot "$(SDK_PATH)" -framework Carbon -lpthread
	xxd -i -a $(OSAX_PATH)/loader $(OSAX_PATH)/sa_loader.c
	xxd -i -a $(OSAX_PATH)/mach_bootstrap $(OSAX_PATH)/sa_mach_bootstrap.c
	rm -f $(OSAX_PATH)/loader
	rm -f $(OSAX_PATH)/mach_bootstrap

$(OSAX_PATH)/sa_payload.c: $(OSAX_PATH)/payload.m
	$(CLANG_PATH) $(OSAX_PATH)/payload.m -shared -fPIC -O2 -mmacosx-version-min=10.13 -arch x86_64 -arch arm64e -o $(OSAX_PATH)/payload -isysroot "$(SDK_PATH)" -framework Foundation -framework Carbon
	xxd -i -a $(OSAX_PATH)/payload $(OSAX_PATH)/sa_payload.c
	rm -f $(OSAX_PATH)/payload

$(OSAX_ARM_INJECTOR_SRC): $(OSAX_PATH)/arm64/sa_arm64e.o $(OSAX_PATH)/arm64/injector.c
	dd if=$(OSAX_PATH)/arm64/sa_arm64e.o of=$(OSAX_PATH)/arm64/sa_arm64e bs=1 count=$(shell otool -l $(OSAX_PATH)/arm64/sa_arm64e.o | grep filesize | sed 's/ filesize //') skip=$(shell otool -l $(OSAX_PATH)/arm64/sa_arm64e.o | grep fileoff | sed 's/  fileoff //')
	xxd -i -a $(OSAX_PATH)/arm64/sa_arm64e $(OSAX_PATH)/arm64/sa_arm64e.h
	$(CLANG_PATH) -c $(OSAX_PATH)/arm64/injector.c -o $(OSAX_PATH)/arm64/injector.o -arch arm64e -isysroot "$(SDK_PATH)"
	rm -f $(OSAX_PATH)/arm64/sa_arm64e

$(OSAX_ARM_SA_SRC): $(OSAX_PATH)/arm64/sa_arm64e.s
	as -o $(OSAX_PATH)/arm64/sa_arm64e.o $(OSAX_PATH)/arm64/sa_arm64e.s

man:
	asciidoctor -b manpage $(DOC_PATH)/yabai.asciidoc -o $(DOC_PATH)/yabai.1

icon:
	python $(SCRIPT_PATH)/seticon.py $(ASSET_PATH)/icon/2x/icon-512px@2x.png $(BUILD_PATH)/yabai

archive: man install sign icon
	rm -rf $(ARCH_PATH)
	mkdir -p $(ARCH_PATH)
	cp -r $(BUILD_PATH) $(ARCH_PATH)/
	cp -r $(DOC_PATH) $(ARCH_PATH)/
	cp -r $(SMP_PATH) $(ARCH_PATH)/
	tar -cvzf $(BUILD_PATH)/$(shell $(BUILD_PATH)/yabai --version).tar.gz $(ARCH_PATH)
	rm -rf $(ARCH_PATH)

sign:
	codesign -fs "yabai-cert" $(BUILD_PATH)/yabai

clean-build:
	rm -rf $(BUILD_PATH)

clean: clean-build
	rm -f $(OSAX_ARM_SRC) $(OSAX_X86_64_SRC)

$(BUILD_PATH)/yabai-x86_64: $(YABAI_X86_64_SRC)
	mkdir -p $(BUILD_PATH)
	$(CLANG_PATH) $^ -arch x86_64 $(BUILD_FLAGS) $(FRAMEWORK_PATH) $(FRAMEWORK) -isysroot "$(SDK_PATH)" -o $@

$(BUILD_PATH)/yabai-arm64: $(YABAI_ARM_SRC)
	mkdir -p $(BUILD_PATH)
	$(CLANG_PATH) $^ -arch arm64e $(BUILD_FLAGS) $(FRAMEWORK_PATH) $(FRAMEWORK) -isysroot "$(SDK_PATH)" -o $@

$(BUILD_PATH)/yabai: $(BUILD_PATH)/yabai-x86_64 $(BUILD_PATH)/yabai-arm64
	lipo -create $(BUILD_PATH)/yabai-x86_64 $(BUILD_PATH)/yabai-arm64 -output $(BUILD_PATH)/yabai
