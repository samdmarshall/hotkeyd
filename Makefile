all:
	mkdir -p build/
	xcrun clang -x objective-c -arch x86_64 -framework Foundation -framework Cocoa -framework Carbon -mmacosx-version-min=10.11 -g -fobjc-arc -Wall -Werror main.m  -Wl,-sectcreate,__TEXT,__info_plist,Info.plist -o build/hotkeyd
	-codesign --sign "Developer ID" build/hotkeyd

