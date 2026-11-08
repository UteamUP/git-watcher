APP_NAME := GIT Watcher
RELEASE_APP := build/macos/Build/Products/Release/$(APP_NAME).app
MCP_BIN := $(HOME)/.local/bin/git-watcher-mcp
CHROME := /Applications/Google Chrome.app/Contents/MacOS/Google Chrome
ICONSET := macos/Runner/Assets.xcassets/AppIcon.appiconset

.PHONY: run app bump install mcp register-mcp icon analyze test

run:
	flutter run -d macos

app:
	flutter build macos --release

bump:
	sh tool/bump_version.sh

install: bump app mcp
	-pkill -f "$(APP_NAME).app/Contents/MacOS/$(APP_NAME)"
	rm -rf "/Applications/$(APP_NAME).app"
	cp -R "$(RELEASE_APP)" /Applications/
	open "/Applications/$(APP_NAME).app"

mcp:
	mkdir -p "$(dir $(MCP_BIN))"
	cd packages/git_watcher_core && dart compile exe bin/git_watcher_mcp.dart -o "$(MCP_BIN)"

register-mcp: mcp
	claude mcp add --scope user git-watcher -- "$(MCP_BIN)"
	codex mcp add git-watcher -- "$(MCP_BIN)"

icon:
	"$(CHROME)" --headless=new --disable-gpu --hide-scrollbars --default-background-color=00000000 \
		--window-size=1024,1024 --screenshot="$(CURDIR)/design/app_icon_1024.png" "file://$(CURDIR)/design/app_icon.html"
	"$(CHROME)" --headless=new --disable-gpu --hide-scrollbars --default-background-color=00000000 \
		--window-size=1024,1024 --screenshot="$(CURDIR)/design/logo_1024.png" "file://$(CURDIR)/design/app_icon.html#logo"
	for s in 16 32 64 128 256 512 1024; do sips -z $$s $$s design/app_icon_1024.png --out $(ICONSET)/app_icon_$$s.png >/dev/null; done
	sips -Z 512 design/logo_1024.png --out assets/logo.png >/dev/null

analyze:
	flutter analyze
	cd packages/git_watcher_core && dart analyze

test:
	flutter test
	cd packages/git_watcher_core && dart test
