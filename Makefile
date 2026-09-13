.PHONY: build run test xcode-test app package update sync clean
build:
	swift build -c release
run:
	swift run DiskMetrics
test:
	mkdir -p .build
	clang -fsyntax-only -Wall -Wextra -I Sources/StorageProbe/include Sources/StorageProbe/StorageProbe.c
	swiftc Sources/DiskMetrics/Metrics.swift Sources/DiskMetrics/Diagnostics.swift Checks/main.swift -o .build/DiskMetricsChecks
	.build/DiskMetricsChecks
xcode-test:
	swift test
app: build
	mkdir -p ".build/bundle/DiskMetrics.app/Contents/MacOS"
	cp .build/release/DiskMetrics ".build/bundle/DiskMetrics.app/Contents/MacOS/DiskMetrics"
	cp packaging/Info.plist ".build/bundle/DiskMetrics.app/Contents/Info.plist"
	codesign --force --sign - ".build/bundle/DiskMetrics.app"
	swift scripts/ReplaceApp.swift ".build/bundle/DiskMetrics.app" "dist/DiskMetrics.app"
package: app
	ditto -c -k --sequesterRsrc --keepParent "dist/DiskMetrics.app" dist/DiskMetrics-macOS.zip
update: build
	swift scripts/StopApp.swift
	$(MAKE) app
	mkdir -p "$(HOME)/Applications"
	swift scripts/ReplaceApp.swift "dist/DiskMetrics.app" "$(HOME)/Applications/DiskMetrics.app"
	codesign --verify --deep --strict "$(HOME)/Applications/DiskMetrics.app"
	open "$(HOME)/Applications/DiskMetrics.app"
sync:
	git pull --ff-only
	$(MAKE) update
clean:
	swift package clean
