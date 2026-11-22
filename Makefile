SHELL := /bin/bash
ROOT := $(CURDIR)
CACHE := $(ROOT)/.build

.PHONY: app dmg build test qa run clean

app:
	./Scripts/build-app.sh

dmg: app
	./Scripts/make-dmg.sh

build:
	TMPDIR="$(CACHE)/tmp" CLANG_MODULE_CACHE_PATH="$(CACHE)/clangcache" \
	swift build --disable-sandbox --scratch-path "$(CACHE)" \
	--cache-path "$(CACHE)/swiftpm-cache" --config-path "$(CACHE)/config"

test:
	TMPDIR="$(CACHE)/tmp" CLANG_MODULE_CACHE_PATH="$(CACHE)/clangcache" \
	swift test --disable-sandbox --scratch-path "$(CACHE)" \
	--cache-path "$(CACHE)/swiftpm-cache" --config-path "$(CACHE)/config"

qa:
	./Scripts/visual-qa.sh

run: app
	open "$(ROOT)/build/NOTCHORA.app"

clean:
	swift package clean || true
	rm -rf "$(CACHE)" "$(ROOT)/build"
