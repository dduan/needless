install: build
	mv .build/release/needless /usr/local/bin

build: clean
	swift build -c release

clean:
	rm -rf .build

uninstall:
	rm -f /usr/local/bin/needless
