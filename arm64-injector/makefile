FRIDA_MAJOR=14
FRIDA_MINOR=2
FRIDA_PATCH=18

FRIDA_DEVKIT=https://github.com/frida/frida/releases/download/${FRIDA_MAJOR}.${FRIDA_MINOR}.${FRIDA_PATCH}/frida-core-devkit-${FRIDA_MAJOR}.${FRIDA_MINOR}.${FRIDA_PATCH}-macos-arm64.tar.xz

FRIDA_DEVKIT_FILES=frida-core.h libfrida-core.a

yabai-injector: $(FRIDA_DEVKIT_FILES) yabai-injector.c config.h
	rm -f $@
	clang -fPIC -Os -pipe -g3 yabai-injector.c -o $@ -L. -lfrida-core -lbsm -lm -ldl -lpthread -lresolv -Wl,-framework,Foundation,-framework,AppKit -pthread -isysroot "$(shell xcrun --sdk macosx --show-sdk-path)" -Wl,-dead_strip
	sudo chown root yabai-injector
	sudo chmod u+s yabai-injector

$(FRIDA_DEVKIT_FILES):
	curl -L -o devkit.tar.xz ${FRIDA_DEVKIT}
	tar xJf devkit.tar.xz
	rm frida-core-example.c devkit.tar.xz

clean:
	rm -f $(FRIDA_DEVKIT_FILES)
	rm -rf yabai-injector yabai-injector.dSYM
