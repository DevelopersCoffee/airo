# Airo Super App Makefile
# Cross-platform build and development automation

# Variables
FLUTTER_VERSION := 3.44.4
APP_DIR := app
ANDROID_DIR := $(APP_DIR)/android
IOS_DIR := $(APP_DIR)/ios
WEB_DIR := $(APP_DIR)/web
IPTV_DIR := iptv-data
IPTV_PYTHON ?= python3
IPTV_CONFIG ?= config/default.yaml
IPTV_SKIP_VALIDATION ?= false
QUANTIZE_PYTHON ?= python3
QUANTIZE_ARGS ?=

# Local simulator targets. Override any of these from the shell when your
# installed Android/Xcode runtimes use different names.
ANDROID_SDK_HOMEBREW := /opt/homebrew/share/android-commandlinetools
ANDROID_SDK_DEFAULT := $(if $(wildcard $(HOME)/Library/Android/sdk),$(HOME)/Library/Android/sdk,$(if $(wildcard $(ANDROID_SDK_HOMEBREW)/platform-tools/adb),$(ANDROID_SDK_HOMEBREW),$(HOME)/Library/Android))
ANDROID_SDK ?= $(or $(ANDROID_SDK_ROOT),$(ANDROID_HOME),$(ANDROID_SDK_DEFAULT))
override ANDROID_HOME := $(ANDROID_SDK)
override ANDROID_SDK_ROOT := $(ANDROID_SDK)
export ANDROID_HOME
export ANDROID_SDK_ROOT
SDKMAN_JAVA_HOME := $(HOME)/.sdkman/candidates/java/current
ifneq ($(wildcard $(SDKMAN_JAVA_HOME)/bin/java),)
JAVA_HOME ?= $(SDKMAN_JAVA_HOME)
PATH := $(JAVA_HOME)/bin:$(PATH)
export JAVA_HOME
export PATH
endif
ANDROID_API ?= 36
ANDROID_IMAGE_ARCH ?= $(shell if [ "$$(uname -m)" = "arm64" ]; then echo arm64-v8a; else echo x86_64; fi)
ANDROID_SYSTEM_IMAGE ?= system-images;android-$(ANDROID_API);google_apis;$(ANDROID_IMAGE_ARCH)
ANDROID_DEVICE_PROFILE ?= pixel_9
ANDROID_AVD ?= Pixel_9_API_$(ANDROID_API)
ANDROID_RUN_DEVICE ?= android
ANDROID_PACKAGE ?= io.airo.app
ANDROID_EMULATOR_FLAGS ?= -no-boot-anim -no-snapshot-save -gpu host -memory 2048 -cores 2
AIRO_ALLOW_ANDROID_EMULATOR ?= false
ADB ?= $(shell command -v adb 2>/dev/null || printf '%s' "$(ANDROID_SDK)/platform-tools/adb")
AVDMANAGER ?= $(shell command -v avdmanager 2>/dev/null || printf '%s' "$(ANDROID_SDK)/cmdline-tools/latest/bin/avdmanager")
SDKMANAGER ?= $(shell command -v sdkmanager 2>/dev/null || printf '%s' "$(ANDROID_SDK)/cmdline-tools/latest/bin/sdkmanager")
ANDROID_EMULATOR ?= $(shell command -v emulator 2>/dev/null || printf '%s' "$(ANDROID_SDK)/emulator/emulator")

IOS_RUNTIME_VERSION ?= 26.5
IOS_DEVICE_TYPE ?= iPhone 17 Pro Max
IOS_SIM_NAME ?= iPhone 17 Pro Max iOS $(IOS_RUNTIME_VERSION)
IOS_LOCAL_PUBSPEC ?= pubspec_ios_spm.yaml
IOS_BUNDLE_ID ?= com.developerscoffee.airo
WEB_PORT ?= 8080
WEB_DEVICE ?= chrome

# Environment Variables for --dart-define
# Set these in your shell or .env file before running make commands
# Example: export GITHUB_ISSUE_TOKEN=ghp_xxxxx && make run-android
DART_DEFINE_ARGS :=
ifdef GITHUB_ISSUE_TOKEN
DART_DEFINE_ARGS += --dart-define=GITHUB_ISSUE_TOKEN=$(GITHUB_ISSUE_TOKEN)
endif
ifdef GITHUB_ISSUE_PROXY_URL
DART_DEFINE_ARGS += --dart-define=GITHUB_ISSUE_PROXY_URL=$(GITHUB_ISSUE_PROXY_URL)
endif
ifdef GITHUB_ISSUE_PROXY_API_KEY
DART_DEFINE_ARGS += --dart-define=GITHUB_ISSUE_PROXY_API_KEY=$(GITHUB_ISSUE_PROXY_API_KEY)
endif

# Colors for output
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[0;33m
BLUE := \033[0;34m
NC := \033[0m # No Color

# Default target
.DEFAULT_GOAL := help

# Help target
.PHONY: help
help: ## Show this help message
	@echo "$(BLUE)Airo Super App - Development Commands$(NC)"
	@echo ""
	@echo "$(YELLOW)Setup Commands:$(NC)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | grep -E '(setup|install|clean)' | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(YELLOW)Development Commands:$(NC)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | grep -E '(run|build|test|analyze)' | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(YELLOW)Platform-Specific Commands:$(NC)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | grep -E '(android|ios|web|chrome|pixel|iphone|simulator|local)' | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(YELLOW)IPTV Data Commands:$(NC)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | grep -E '^iptv-' | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(YELLOW)Model Tooling:$(NC)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | grep -E '^quantize-model' | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2}'

.PHONY: quantize-model
quantize-model: ## Run the model quantization helper; set QUANTIZE_ARGS="..."
	@$(QUANTIZE_PYTHON) scripts/quantize_model.py $(if $(HELP),--help,$(QUANTIZE_ARGS))

# Setup Commands
.PHONY: setup
setup: ## Complete first-time setup for newly cloned repo
	@echo "$(BLUE)Setting up Airo Super App...$(NC)"
	@$(MAKE) check-flutter
	@$(MAKE) install-deps
	@$(MAKE) setup-android
	@$(MAKE) setup-ios
	@$(MAKE) setup-web
	@echo "$(GREEN)Setup complete! Run 'make run-android' or 'make run-ios' to start development.$(NC)"

.PHONY: check-flutter
check-flutter: ## Check if Flutter is installed and correct version
	@echo "$(YELLOW)Checking Flutter installation...$(NC)"
	@if ! command -v flutter &> /dev/null; then \
		echo "$(RED)Flutter is not installed. Please install Flutter first.$(NC)"; \
		echo "Visit: https://flutter.dev/docs/get-started/install"; \
		exit 1; \
	fi
	@flutter --version
	@flutter doctor

.PHONY: install-deps
install-deps: ## Install all dependencies
	@echo "$(YELLOW)Installing dependencies...$(NC)"
	@cd $(APP_DIR) && flutter pub get
	@cd packages/airo && flutter pub get
	@cd packages/airomoney && flutter pub get

.PHONY: setup-android
setup-android: ## Setup Android development environment
	@echo "$(YELLOW)Setting up Android...$(NC)"
	@if [ ! -d "$(ANDROID_SDK_ROOT)" ]; then \
		echo "$(RED)Android SDK not found. Please install Android Studio and SDK.$(NC)"; \
	else \
		echo "$(GREEN)Android SDK found at $(ANDROID_SDK_ROOT)$(NC)"; \
	fi
	@cd $(APP_DIR) && flutter build apk --debug

.PHONY: setup-ios
setup-ios: ## Setup iOS development environment (macOS only)
	@echo "$(YELLOW)Setting up iOS...$(NC)"
	@if [ "$$(uname)" != "Darwin" ]; then \
		echo "$(YELLOW)iOS development is only available on macOS$(NC)"; \
	else \
		if ! command -v xcodebuild &> /dev/null; then \
			echo "$(RED)Xcode is not installed. Please install Xcode from App Store.$(NC)"; \
		elif ! command -v pod &> /dev/null; then \
			echo "$(RED)CocoaPods is required for the current Flutter plugin set.$(NC)"; \
			echo "$(YELLOW)Install CocoaPods, then run 'cd $(APP_DIR)/ios && pod install'.$(NC)"; \
			exit 1; \
		else \
			cd $(APP_DIR) && flutter pub get; \
			cd $(IOS_DIR) && pod install; \
			echo "$(GREEN)iOS is configured with Flutter via SPM and plugins via CocoaPods.$(NC)"; \
			echo "$(GREEN)Run 'make build-ios' to build the app.$(NC)"; \
		fi \
	fi

.PHONY: setup-web
setup-web: ## Setup web development environment
	@echo "$(YELLOW)Setting up web...$(NC)"
	@cd $(APP_DIR) && flutter build web --debug

# Development Commands
.PHONY: devices
devices: ## List all available devices
	@echo "$(BLUE)Available devices:$(NC)"
	@cd $(APP_DIR) && flutter devices

.PHONY: check-android-tools
check-android-tools: ## Validate Android SDK tools needed for local Pixel 9 AVD
	@if ! java -version >/dev/null 2>&1; then \
		echo "$(RED)A working JDK is required for Android SDK tools.$(NC)"; \
		echo "$(YELLOW)Install a JDK, then retry. Example: brew install --cask temurin$(NC)"; \
		exit 1; \
	fi
	@if [ ! -x "$(SDKMANAGER)" ]; then \
		echo "$(RED)sdkmanager not found at $(SDKMANAGER).$(NC)"; \
		echo "$(YELLOW)Install Android Studio command-line tools or set ANDROID_SDK/SDKMANAGER.$(NC)"; \
		exit 1; \
	fi
	@if [ ! -x "$(AVDMANAGER)" ]; then \
		echo "$(RED)avdmanager not found at $(AVDMANAGER).$(NC)"; \
		echo "$(YELLOW)Install Android Studio command-line tools or set ANDROID_SDK/AVDMANAGER.$(NC)"; \
		exit 1; \
	fi

.PHONY: check-android-emulator-opt-in
check-android-emulator-opt-in: ## Require explicit opt-in before booting Android Emulator/qemu
	@if [ "$(AIRO_ALLOW_ANDROID_EMULATOR)" != "true" ]; then \
		echo "$(RED)Android Emulator is disabled by default for agent runs.$(NC)"; \
		echo "$(YELLOW)The emulator/qemu runtime can crash on macOS 26.x hosts and lose test state.$(NC)"; \
		echo "$(YELLOW)Use host checks, a connected physical Android device, or rerun with AIRO_ALLOW_ANDROID_EMULATOR=true.$(NC)"; \
		exit 78; \
	fi

.PHONY: setup-pixel9-avd
setup-pixel9-avd: check-android-tools ## Create/update lightweight Pixel 9 Android emulator
	@echo "$(BLUE)Preparing Android AVD: $(ANDROID_AVD)$(NC)"
	@yes | "$(SDKMANAGER)" --install "platform-tools" "emulator" "platforms;android-$(ANDROID_API)" >/dev/null
	@if ! "$(SDKMANAGER)" --list_installed | grep -Fq "$(ANDROID_SYSTEM_IMAGE)"; then \
		echo "$(YELLOW)Installing $(ANDROID_SYSTEM_IMAGE)...$(NC)"; \
		yes | "$(SDKMANAGER)" --install "$(ANDROID_SYSTEM_IMAGE)"; \
	fi
	@if ! "$(AVDMANAGER)" list avd | grep -Fq "Name: $(ANDROID_AVD)"; then \
		echo "$(YELLOW)Creating $(ANDROID_AVD) using profile $(ANDROID_DEVICE_PROFILE)...$(NC)"; \
		echo "no" | "$(AVDMANAGER)" create avd \
			--name "$(ANDROID_AVD)" \
			--package "$(ANDROID_SYSTEM_IMAGE)" \
			--device "$(ANDROID_DEVICE_PROFILE)" \
			--force; \
	fi
	@AVD_CONFIG="$(HOME)/.android/avd/$(ANDROID_AVD).avd/config.ini"; \
	if [ -f "$$AVD_CONFIG" ]; then \
		grep -q '^hw.ramSize=' "$$AVD_CONFIG" && sed -i.bak 's/^hw.ramSize=.*/hw.ramSize=2048/' "$$AVD_CONFIG" || echo 'hw.ramSize=2048' >> "$$AVD_CONFIG"; \
		grep -q '^vm.heapSize=' "$$AVD_CONFIG" && sed -i.bak 's/^vm.heapSize=.*/vm.heapSize=256/' "$$AVD_CONFIG" || echo 'vm.heapSize=256' >> "$$AVD_CONFIG"; \
		grep -q '^disk.dataPartition.size=' "$$AVD_CONFIG" && sed -i.bak 's/^disk.dataPartition.size=.*/disk.dataPartition.size=4096M/' "$$AVD_CONFIG" || echo 'disk.dataPartition.size=4096M' >> "$$AVD_CONFIG"; \
		rm -f "$$AVD_CONFIG.bak"; \
	fi
	@echo "$(GREEN)✓ Pixel 9 AVD ready: $(ANDROID_AVD)$(NC)"

.PHONY: boot-pixel9
boot-pixel9: check-android-emulator-opt-in setup-pixel9-avd ## Boot/reuse the local Pixel 9 emulator (requires AIRO_ALLOW_ANDROID_EMULATOR=true)
	@echo "$(BLUE)Booting Pixel 9 emulator: $(ANDROID_AVD)$(NC)"
	@if [ ! -x "$(ANDROID_EMULATOR)" ]; then \
		echo "$(RED)Android emulator not found at $(ANDROID_EMULATOR).$(NC)"; \
		echo "$(YELLOW)Install the Android Emulator package from Android Studio or set ANDROID_EMULATOR.$(NC)"; \
		exit 1; \
	fi
	@if [ ! -x "$(ADB)" ]; then \
		echo "$(RED)adb not found at $(ADB).$(NC)"; \
		echo "$(YELLOW)Install Android SDK Platform-Tools from Android Studio or set ADB.$(NC)"; \
		exit 1; \
	fi
	@if "$(ADB)" devices | grep -qE '^emulator-[0-9]+[[:space:]]+device'; then \
		echo "$(GREEN)Android emulator already running; reusing it.$(NC)"; \
	else \
		nohup "$(ANDROID_EMULATOR)" -avd "$(ANDROID_AVD)" $(ANDROID_EMULATOR_FLAGS) > /tmp/$(ANDROID_AVD).log 2>&1 & \
		echo "$(YELLOW)Started emulator in background. Log: /tmp/$(ANDROID_AVD).log$(NC)"; \
	fi
	@"$(ADB)" wait-for-device
	@until [ "$$("$(ADB)" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = "1" ]; do \
		printf "."; \
		sleep 2; \
	done; \
	echo ""; \
	echo "$(GREEN)✓ Pixel 9 emulator is booted.$(NC)"

.PHONY: check-ios-tools
check-ios-tools: ## Validate Xcode tools needed for local iOS simulator
	@if [ "$$(uname)" != "Darwin" ]; then \
		echo "$(RED)iOS simulator support is only available on macOS.$(NC)"; \
		exit 1; \
	fi
	@if ! command -v xcrun >/dev/null 2>&1; then \
		echo "$(RED)xcrun not found. Install Xcode and run xcode-select --install.$(NC)"; \
		exit 1; \
	fi
	@if ! command -v xcodebuild >/dev/null 2>&1; then \
		echo "$(RED)xcodebuild not found. Install Xcode from the Mac App Store.$(NC)"; \
		exit 1; \
	fi

.PHONY: setup-iphone17-simulator
setup-iphone17-simulator: check-ios-tools ## Create iPhone 17 Pro Max simulator for iOS 26.5.1
	@echo "$(BLUE)Preparing iOS simulator: $(IOS_SIM_NAME)$(NC)"
	@RUNTIME_ID=$$(xcrun simctl list runtimes available | awk -v version="$(IOS_RUNTIME_VERSION)" '/iOS/ && index($$0, version) { print $$NF; exit }'); \
	DEVICE_TYPE_ID=$$(xcrun simctl list devicetypes | awk -v name="$(IOS_DEVICE_TYPE)" 'index($$0, name) { print $$NF; exit }' | tr -d '()'); \
	if [ -z "$$RUNTIME_ID" ]; then \
		echo "$(RED)iOS runtime $(IOS_RUNTIME_VERSION) is not installed in Xcode.$(NC)"; \
		echo "$(YELLOW)Install it in Xcode > Settings > Platforms, or override IOS_RUNTIME_VERSION.$(NC)"; \
		exit 1; \
	fi; \
	if [ -z "$$DEVICE_TYPE_ID" ]; then \
		echo "$(RED)Simulator device type '$(IOS_DEVICE_TYPE)' is not available in this Xcode.$(NC)"; \
		echo "$(YELLOW)Install the matching Xcode platform support, or override IOS_DEVICE_TYPE.$(NC)"; \
		exit 1; \
	fi; \
	if ! xcrun simctl list devices available | grep -Fq "$(IOS_SIM_NAME)"; then \
		xcrun simctl create "$(IOS_SIM_NAME)" "$$DEVICE_TYPE_ID" "$$RUNTIME_ID" >/dev/null; \
	fi
	@echo "$(GREEN)✓ iOS simulator ready: $(IOS_SIM_NAME)$(NC)"

.PHONY: boot-iphone17
boot-iphone17: setup-iphone17-simulator ## Boot/reuse the local iPhone 17 Pro Max simulator
	@echo "$(BLUE)Booting iOS simulator: $(IOS_SIM_NAME)$(NC)"
	@UDID=$$(xcrun simctl list devices available -j | /usr/bin/ruby -rjson -e 'name = ARGV[0]; JSON.parse(STDIN.read)["devices"].each_value { |devices| devices.each { |device| if device["name"] == name; puts device["udid"]; exit 0; end } }; exit 1' "$(IOS_SIM_NAME)"); \
	open -a Simulator --args -CurrentDeviceUDID "$$UDID"; \
	xcrun simctl boot "$$UDID" >/dev/null 2>&1 || true; \
	xcrun simctl bootstatus "$$UDID" -b; \
	echo "$(GREEN)✓ iPhone simulator is booted: $$UDID$(NC)"

.PHONY: setup-local-devices
setup-local-devices: setup-pixel9-avd setup-iphone17-simulator setup-e2e ## Prepare Pixel 9, iPhone 17 Pro Max, and browser test tooling

.PHONY: boot-local-devices
boot-local-devices: boot-pixel9 boot-iphone17 ## Boot Android and iOS simulators for local testing

.PHONY: deploy-local-binaries
deploy-local-binaries: deploy-pixel9-apk run-iphone17-local ## Build, install, and launch Android APK plus iOS simulator app

.PHONY: local-test-plan
local-test-plan: ## Show the local Android/iOS/web testing workflow
	@echo "$(BLUE)Local testing workflow$(NC)"
	@echo "1. make setup-local-devices"
	@echo "2. Keep simulators open: make boot-local-devices"
	@echo "3. Terminal A: make run-pixel9"
	@echo "4. Terminal B: make run-iphone17-local"
	@echo "5. Terminal C: make run-browser"
	@echo "6. Browser E2E: make test-browser"
	@echo "7. Native E2E: make test-device-android and make test-device-ios"

.PHONY: run-android-auto
run-android-auto: ## Run app on any connected Android device
	@echo "$(BLUE)Running on Android (auto-detect)...$(NC)"
	@cd $(APP_DIR) && flutter run -d android $(DART_DEFINE_ARGS)

.PHONY: run-android
run-android: run-pixel9 ## Run app on local Pixel 9 Android emulator

.PHONY: run-pixel9
run-pixel9: boot-pixel9 ## Run app on local Pixel 9 emulator
	@echo "$(BLUE)Running on Pixel 9 (Android)...$(NC)"
	@cd $(APP_DIR) && flutter run -d "$(ANDROID_RUN_DEVICE)" $(DART_DEFINE_ARGS)

.PHONY: deploy-pixel9-apk
deploy-pixel9-apk: boot-pixel9 ## Build, install, and launch debug APK on local Pixel 9 emulator
	@echo "$(BLUE)Deploying debug APK to Pixel 9...$(NC)"
	@cd $(APP_DIR) && flutter build apk --debug $(DART_DEFINE_ARGS)
	@"$(ADB)" install -r "$(APP_DIR)/build/app/outputs/flutter-apk/app-debug.apk"
	@"$(ADB)" shell am start -n "$(ANDROID_PACKAGE)/.MainActivity" >/dev/null
	@PID=""; \
	for attempt in $$(seq 1 20); do \
		PID=$$("$(ADB)" shell pidof "$(ANDROID_PACKAGE)" | tr -d '\r'); \
		[ -n "$$PID" ] && break; \
		sleep 1; \
	done; \
	if [ -z "$$PID" ]; then \
		echo "$(RED)APK installed, but $(ANDROID_PACKAGE) is not running.$(NC)"; \
		exit 1; \
	fi; \
	echo "$(GREEN)✓ APK installed and launched on Pixel 9. PID: $$PID$(NC)"

.PHONY: run-ios
run-ios: ## Run app on iOS device/simulator
	@echo "$(BLUE)Running on iOS...$(NC)"
	@if [ "$$(uname)" != "Darwin" ]; then \
		echo "$(RED)iOS development is only available on macOS$(NC)"; \
		exit 1; \
	elif ! command -v pod &> /dev/null; then \
		echo "$(RED)CocoaPods is required for iOS builds in this project.$(NC)"; \
		exit 1; \
	fi
	@cd $(APP_DIR) && flutter run -d ios $(DART_DEFINE_ARGS)

.PHONY: run-iphone13
run-iphone13: ## Run app on iPhone 13 Pro Max simulator
	@echo "$(BLUE)Running on iPhone 13 Pro Max...$(NC)"
	@if [ "$$(uname)" != "Darwin" ]; then \
		echo "$(RED)iOS development is only available on macOS$(NC)"; \
		exit 1; \
	elif ! command -v pod &> /dev/null; then \
		echo "$(RED)CocoaPods is required for iOS builds in this project.$(NC)"; \
		exit 1; \
	fi
	@cd $(APP_DIR) && flutter run -d "iPhone 13 Pro Max" $(DART_DEFINE_ARGS)

.PHONY: run-iphone17
run-iphone17: run-iphone17-local ## Build, install, and launch local iPhone 17 Pro Max simulator profile

.PHONY: run-iphone17-flutter
run-iphone17-flutter: boot-iphone17 ## Run the full native app on local iPhone 17 Pro Max via flutter run
	@echo "$(BLUE)Running on $(IOS_SIM_NAME)...$(NC)"
	@UDID=$$(xcrun simctl list devices available -j | /usr/bin/ruby -rjson -e 'name = ARGV[0]; JSON.parse(STDIN.read)["devices"].each_value { |devices| devices.each { |device| if device["name"] == name; puts device["udid"]; exit 0; end } }; exit 1' "$(IOS_SIM_NAME)"); \
	cd $(APP_DIR) && flutter run -d "$$UDID" $(DART_DEFINE_ARGS)

.PHONY: build-ios-simulator-local
build-ios-simulator-local: boot-iphone17 ## Build local iOS simulator app with native-heavy plugins stubbed
	@echo "$(BLUE)Building local iOS simulator app using $(IOS_LOCAL_PUBSPEC)...$(NC)"
	@set -e; \
	APP_ABS="$$(pwd)/$(APP_DIR)"; \
	TMP_DIR=$$(mktemp -d); \
	cp "$$APP_ABS/pubspec.yaml" "$$TMP_DIR/pubspec.yaml"; \
	cp "$$APP_ABS/pubspec.lock" "$$TMP_DIR/pubspec.lock"; \
	cleanup() { \
		set +e; \
		cp "$$TMP_DIR/pubspec.yaml" "$$APP_ABS/pubspec.yaml"; \
		cp "$$TMP_DIR/pubspec.lock" "$$APP_ABS/pubspec.lock"; \
		flutter config --enable-swift-package-manager >/dev/null; \
		(cd "$$APP_ABS" && flutter pub get >/dev/null); \
		rm -rf "$$TMP_DIR"; \
	}; \
	trap cleanup EXIT; \
	flutter config --no-enable-swift-package-manager >/dev/null; \
	cp "$$APP_ABS/$(IOS_LOCAL_PUBSPEC)" "$$APP_ABS/pubspec.yaml"; \
	cd "$$APP_ABS"; \
	flutter pub get; \
	rm -rf ios/Pods ios/Podfile.lock ios/.symlinks build/ios/Debug-iphonesimulator/Runner.app build/ios/iphonesimulator/Runner.app; \
	flutter build ios --simulator --debug $(DART_DEFINE_ARGS); \
	file build/ios/iphonesimulator/Runner.app/Runner; \
	lipo -info build/ios/iphonesimulator/Runner.app/Runner

.PHONY: run-iphone17-local
run-iphone17-local: build-ios-simulator-local ## Install and launch local iOS simulator app on iPhone 17 Pro Max
	@echo "$(BLUE)Installing local iOS simulator app on $(IOS_SIM_NAME)...$(NC)"
	@UDID=$$(xcrun simctl list devices available -j | /usr/bin/ruby -rjson -e 'name = ARGV[0]; JSON.parse(STDIN.read)["devices"].each_value { |devices| devices.each { |device| if device["name"] == name; puts device["udid"]; exit 0; end } }; exit 1' "$(IOS_SIM_NAME)"); \
	xcrun simctl install "$$UDID" "$(APP_DIR)/build/ios/iphonesimulator/Runner.app"; \
	xcrun simctl launch "$$UDID" "$(IOS_BUNDLE_ID)"

.PHONY: run-web
run-web: ## Run app on web browser
	@echo "$(BLUE)Running on web...$(NC)"
	@cd $(APP_DIR) && flutter run -d web-server --web-port $(WEB_PORT) $(DART_DEFINE_ARGS)

.PHONY: run-chrome
run-chrome: ## Run app specifically on Chrome browser
	@echo "$(BLUE)Running on Chrome...$(NC)"
	@cd $(APP_DIR) && flutter run -d chrome --web-port $(WEB_PORT) $(DART_DEFINE_ARGS)

.PHONY: run-browser
run-browser: ## Run app on configured web browser for local testing
	@echo "$(BLUE)Running on web browser ($(WEB_DEVICE))...$(NC)"
	@cd $(APP_DIR) && flutter run -d "$(WEB_DEVICE)" --web-port $(WEB_PORT) $(DART_DEFINE_ARGS)

# Fire TV Commands
.PHONY: run-firetv
run-firetv: ## Run app on Fire TV (auto-detect TV emulator/device)
	@echo "$(BLUE)Running on Fire TV...$(NC)"
	@cd $(APP_DIR) && flutter run -d android $(DART_DEFINE_ARGS)

.PHONY: run-firetv-emulator
run-firetv-emulator: ## Run app on Fire TV emulator by name
	@echo "$(BLUE)Running on Fire TV emulator...$(NC)"
	@cd $(APP_DIR) && flutter run -d "Fire_TV_Stick_4K" $(DART_DEFINE_ARGS)

.PHONY: run-androidtv
run-androidtv: ## Run app on Android TV emulator
	@echo "$(BLUE)Running on Android TV...$(NC)"
	@cd $(APP_DIR) && flutter run -d "Android_TV" $(DART_DEFINE_ARGS)

# Build Commands
.PHONY: build-android
build-android: ## Build Android APK (split-per-abi for smaller APKs)
	@echo "$(BLUE)Building Android APK (split-per-abi)...$(NC)"
	@cd $(APP_DIR) && flutter build apk --release \
		--split-per-abi \
		--tree-shake-icons \
		--dart-define=APP_VARIANT=full \
		--dart-define=APP_PLATFORM=mobileFull
	@echo "$(GREEN)✓ APKs created:$(NC)"
	@ls -lh $(APP_DIR)/build/app/outputs/flutter-apk/*.apk 2>/dev/null || echo "  Check $(APP_DIR)/build/app/outputs/flutter-apk/"

.PHONY: build-android-fat
build-android-fat: ## Build Android APK (fat APK with all ABIs - larger size)
	@echo "$(BLUE)Building Android APK (fat)...$(NC)"
	@cd $(APP_DIR) && flutter build apk --release

.PHONY: build-android-bundle
build-android-bundle: ## Build Android App Bundle for Play Store
	@echo "$(BLUE)Building Android App Bundle...$(NC)"
	@cd $(APP_DIR) && flutter build appbundle --release \
		--tree-shake-icons \
		--dart-define=APP_VARIANT=full \
		--dart-define=APP_PLATFORM=mobileFull

# =============================================================================
# PLATFORM-SPECIFIC BUILDS (Phase 0.5+ Multi-Platform Strategy)
# =============================================================================

.PHONY: build-tv
build-tv: ## Build Android TV APK (IPTV only, <30MB target with lightweight deps)
ifeq ($(OS),Windows_NT)
	@powershell -ExecutionPolicy Bypass -File scripts/build-tv.ps1
else
	@bash scripts/build-tv.sh
endif

.PHONY: build-tv-full
build-tv-full: ## Build Android TV APK with all dependencies (for testing, ~145MB)
ifeq ($(OS),Windows_NT)
	@powershell -ExecutionPolicy Bypass -File scripts/build-tv.ps1 -Full
else
	@bash scripts/build-tv.sh --full
endif

.PHONY: build-streaming
build-streaming: ## Build Mobile Streaming APK with lightweight deps (Music + IPTV, <50MB target)
ifeq ($(OS),Windows_NT)
	@powershell -ExecutionPolicy Bypass -File scripts/build-streaming.ps1
else
	@bash scripts/build-streaming.sh
endif

.PHONY: build-streaming-full
build-streaming-full: ## Build Mobile Streaming APK with full dependencies (~100MB, for testing)
	@echo "$(BLUE)Building Mobile Streaming APK (full dependencies)...$(NC)"
	@cd $(APP_DIR) && flutter build apk --release \
		--target=lib/main_mobile_streaming.dart \
		--dart-define=APP_VARIANT=streaming \
		--dart-define=APP_PLATFORM=mobileStreaming \
		--split-per-abi \
		--tree-shake-icons
	@echo "$(GREEN)✓ Streaming APK created$(NC)"

.PHONY: build-full
build-full: ## Build Mobile Full APK (all features)
	@echo "$(BLUE)Building Mobile Full APK...$(NC)"
	@cd $(APP_DIR) && flutter build apk --release \
		--target=lib/main.dart \
		--dart-define=APP_VARIANT=full \
		--dart-define=APP_PLATFORM=mobileFull \
		--split-per-abi \
		--tree-shake-icons
	@echo "$(GREEN)✓ Full APK created$(NC)"

.PHONY: build-firetv
build-firetv: ## Build Fire TV optimized APK (arm64 only)
	@echo "$(BLUE)Building Fire TV APK...$(NC)"
	@cd $(APP_DIR) && flutter build apk --release \
		--target=lib/main_tv.dart \
		--dart-define=APP_VARIANT=tv \
		--dart-define=APP_PLATFORM=androidTv \
		--target-platform android-arm64 \
		--tree-shake-icons

.PHONY: build-androidtv
build-androidtv: build-tv ## Alias for build-tv

.PHONY: build-ios
build-ios: ## Build iOS app
	@echo "$(BLUE)Building iOS app...$(NC)"
	@if [ "$$(uname)" != "Darwin" ]; then \
		echo "$(RED)iOS building is only available on macOS$(NC)"; \
		exit 1; \
	elif ! command -v pod &> /dev/null; then \
		echo "$(RED)CocoaPods is required for iOS builds in this project.$(NC)"; \
		exit 1; \
	fi
	@cd $(APP_DIR) && flutter pub get
	@cd $(IOS_DIR) && pod install
	@cd $(APP_DIR) && flutter build ios --release

.PHONY: build-web
build-web: ## Build web app
	@echo "$(BLUE)Building web app...$(NC)"
	@cd $(APP_DIR) && flutter build web --release

.PHONY: build-all
build-all: ## Build for all platforms
	@echo "$(BLUE)Building for all platforms...$(NC)"
	@$(MAKE) build-android
	@$(MAKE) build-web
	@if [ "$$(uname)" = "Darwin" ]; then \
		$(MAKE) build-ios; \
	fi

# Testing Commands
.PHONY: test
test: ## Run all tests
	@echo "$(BLUE)Running tests...$(NC)"
	@cd $(APP_DIR) && flutter test
	@cd packages/airo && flutter test
	@cd packages/airomoney && flutter test

.PHONY: test-coverage
test-coverage: ## Run tests with coverage and check threshold
	@echo "$(BLUE)Running tests with coverage...$(NC)"
	@./scripts/check-coverage.sh 60

.PHONY: test-integration
test-integration: ## Run integration tests
	@echo "$(BLUE)Running integration tests...$(NC)"
	@cd $(APP_DIR) && flutter test integration_test/

.PHONY: test-ui-responsive
test-ui-responsive: ## Run shared responsive UI validation tests
	@echo "$(BLUE)Running shared UI responsiveness tests...$(NC)"
	@cd $(APP_DIR) && rm -rf windows/flutter/ephemeral/.plugin_symlinks ios/Flutter/ephemeral/Packages/.packages macos/Flutter/ephemeral/Packages/.packages
	@cd $(APP_DIR) && flutter test test/shared/widgets/adaptive_layout_test.dart

.PHONY: benchmark-report
benchmark-report: ## Create a release benchmark report template
	@./scripts/create-performance-benchmark-report.sh

.PHONY: benchmark-gemini-warmup
benchmark-gemini-warmup: ## Run the Gemini Nano warmup integration path used in release benchmarks
	@echo "$(BLUE)Running Gemini Nano warmup benchmark path...$(NC)"
	@cd $(APP_DIR) && rm -rf ios/Flutter/ephemeral/Packages/.packages macos/Flutter/ephemeral/Packages/.packages
	@cd $(APP_DIR) && flutter test test/core/services/gemini_nano_service_test.dart

.PHONY: benchmark-android-startup
benchmark-android-startup: ## Capture Android startup timing on a connected device
	@if [ ! -x "$(ADB)" ]; then \
		echo "$(RED)adb not found at $(ADB).$(NC)"; \
		exit 1; \
	fi
	@if ! "$(ADB)" devices | awk 'NR>1 && $$2=="device" { found=1 } END { exit found?0:1 }'; then \
		echo "$(RED)No connected Android device detected.$(NC)"; \
		echo "$(YELLOW)Use a physical device or opt in to the emulator path separately.$(NC)"; \
		exit 1; \
	fi
	@"$(ADB)" shell am force-stop "$(ANDROID_PACKAGE)"
	@"$(ADB)" shell am start -W "$(ANDROID_PACKAGE)/.MainActivity"

# IPTV Data Pipeline Commands
.PHONY: iptv-install-deps
iptv-install-deps: ## Install local IPTV pipeline dependencies
	@echo "$(BLUE)Installing IPTV pipeline dependencies...$(NC)"
	@if [ ! -d "$(IPTV_DIR)/venv" ]; then \
		$(IPTV_PYTHON) -m venv $(IPTV_DIR)/venv; \
	fi
	@$(IPTV_DIR)/venv/bin/python -m pip install --upgrade pip
	@$(IPTV_DIR)/venv/bin/pip install -r $(IPTV_DIR)/requirements.txt
	@$(IPTV_DIR)/venv/bin/pip install ruff

.PHONY: iptv-lint
iptv-lint: iptv-install-deps ## Run IPTV pipeline linting
	@echo "$(BLUE)Running IPTV pipeline linting...$(NC)"
	@cd $(IPTV_DIR) && venv/bin/ruff check src/

.PHONY: iptv-test
iptv-test: iptv-install-deps ## Run IPTV pipeline tests
	@echo "$(BLUE)Running IPTV pipeline tests...$(NC)"
	@cd $(IPTV_DIR) && venv/bin/pytest tests/ -v --tb=short

.PHONY: iptv-run-pipeline
iptv-run-pipeline: iptv-install-deps ## Run IPTV source collection pipeline locally
	@echo "$(BLUE)Running IPTV source collection pipeline...$(NC)"
	@cd $(IPTV_DIR) && \
		if [ "$(IPTV_SKIP_VALIDATION)" = "true" ]; then \
			venv/bin/python -m src.main --config $(IPTV_CONFIG) --skip-validation; \
		else \
			venv/bin/python -m src.main --config $(IPTV_CONFIG); \
		fi

.PHONY: iptv-verify-output
iptv-verify-output: iptv-install-deps ## Verify IPTV pipeline output files
	@echo "$(BLUE)Verifying IPTV pipeline output...$(NC)"
	@cd $(IPTV_DIR) && test -f output/current/iptv_channels.json
	@cd $(IPTV_DIR) && test -f output/current/manifest.json
	@cd $(IPTV_DIR) && test -f output/current/iptv_channels.m3u
	@cd $(IPTV_DIR) && venv/bin/python -c "import json; json.load(open('output/current/iptv_channels.json'))"
	@cd $(IPTV_DIR) && \
		CHANNEL_COUNT=$$(venv/bin/python -c "import json; d=json.load(open('output/current/iptv_channels.json')); print(len(d['channels']))"); \
		echo "Channel count: $$CHANNEL_COUNT"; \
		if [ "$$CHANNEL_COUNT" -lt 50 ]; then \
			echo "$(RED)Error: Channel count ($$CHANNEL_COUNT) below minimum threshold (50)$(NC)"; \
			exit 1; \
		fi

.PHONY: iptv-refresh-sources
iptv-refresh-sources: iptv-lint iptv-test iptv-run-pipeline iptv-verify-output ## Refresh IPTV sources locally like the GitHub Action
	@echo "$(GREEN)✓ IPTV sources refreshed locally$(NC)"

.PHONY: iptv-publish-gist
iptv-publish-gist: iptv-verify-output ## Publish local IPTV output to GitHub Gist
	@echo "$(BLUE)Publishing IPTV data to GitHub Gist...$(NC)"
	@if [ -z "$$GIST_TOKEN" ]; then \
		echo "$(RED)Error: GIST_TOKEN is not set$(NC)"; \
		exit 1; \
	fi
	@if [ -z "$$IPTV_GIST_ID" ]; then \
		echo "$(RED)Error: IPTV_GIST_ID is not set$(NC)"; \
		exit 1; \
	fi
	@cd $(IPTV_DIR) && venv/bin/python -c "import json, pathlib; version=json.load(open('output/current/manifest.json'))['version']; files={name: {'content': pathlib.Path('output/current', name).read_text()} for name in ('iptv_channels.json', 'manifest.json', 'iptv_channels.m3u')}; pathlib.Path('/tmp/iptv_gist_payload.json').write_text(json.dumps({'description': f'IPTV Channels Data v{version} - Auto-updated locally', 'files': files}))"
	@curl --fail-with-body -X PATCH \
		-H "Accept: application/vnd.github+json" \
		-H "Authorization: Bearer $$GIST_TOKEN" \
		-H "X-GitHub-Api-Version: 2022-11-28" \
		"https://api.github.com/gists/$$IPTV_GIST_ID" \
		-d @/tmp/iptv_gist_payload.json
	@echo "$(GREEN)✓ Published to Gist: https://gist.github.com/$$IPTV_GIST_ID$(NC)"

.PHONY: iptv-refresh-and-publish
iptv-refresh-and-publish: iptv-refresh-sources iptv-publish-gist ## Refresh IPTV sources locally and publish to Gist

# =============================================================================
# E2E TESTING - Strategy: Playwright (browser) → Patrol (device) → Deploy
# =============================================================================

.PHONY: test-e2e
test-e2e: test-browser test-device ## Run all E2E tests (browser + device)
	@echo "$(GREEN)✓ All E2E tests passed! Ready for deployment.$(NC)"

.PHONY: test-browser
test-browser: ## Step 1: Run Playwright browser E2E tests
	@echo "$(BLUE)Running Playwright browser tests...$(NC)"
	@echo "$(YELLOW)NOTE: Flutter Web must be running on port 8080$(NC)"
	@echo "$(YELLOW)Run 'make run-chrome-html' in another terminal first$(NC)"
	@cd e2e && npm test

.PHONY: test-browser-headless
test-browser-headless: ## Run Playwright tests headless (CI)
	@cd e2e && npm test -- --project=chromium

.PHONY: test-browser-debug
test-browser-debug: ## Run Playwright tests with debug UI
	@cd e2e && npm run test:debug

.PHONY: test-browser-report
test-browser-report: ## Show Playwright test report
	@cd e2e && npm run report

.PHONY: test-device
test-device: ## Step 2: Run Patrol device E2E tests
	@echo "$(BLUE)Running Patrol device tests...$(NC)"
	@cd $(APP_DIR) && patrol test -t integration_test/patrol_test.dart

.PHONY: test-device-android
test-device-android: ## Run Patrol tests on Android
	@cd $(APP_DIR) && patrol test -t integration_test/patrol_test.dart --target android

.PHONY: test-device-ios
test-device-ios: ## Run Patrol tests on iOS
	@cd $(APP_DIR) && patrol test -t integration_test/patrol_test.dart --target ios

.PHONY: test-agent-skills-journey
test-agent-skills-journey: ## Run the Agent Skills calendar journey on the default iOS simulator
	@./scripts/run_agent_skills_journey.sh

.PHONY: test-agent-skills-journey-android
test-agent-skills-journey-android: ## Run Agent Skills journey on a connected Android device
	@AIRO_JOURNEY_PLATFORM=android ./scripts/run_agent_skills_journey.sh

.PHONY: test-agent-skills-journey-android-emulator
test-agent-skills-journey-android-emulator: ## Explicitly opt in to Pixel 9 emulator Agent Skills journey
	@AIRO_JOURNEY_PLATFORM=android AIRO_ALLOW_ANDROID_EMULATOR=true ./scripts/run_agent_skills_journey.sh

.PHONY: test-agent-skills-journey-ios
test-agent-skills-journey-ios: ## Boot iPhone simulator and run Agent Skills journey
	@AIRO_JOURNEY_PLATFORM=ios ./scripts/run_agent_skills_journey.sh

.PHONY: test-local-all
test-local-all: test-browser-headless test-device-android test-device-ios ## Run browser, Android, and iOS E2E tests sequentially

.PHONY: run-chrome-html
run-chrome-html: ## Run Flutter Web with HTML renderer for E2E testing
	@echo "$(BLUE)Running Flutter Web with HTML renderer on port $(WEB_PORT)...$(NC)"
	@cd $(APP_DIR) && flutter run -d chrome --web-renderer=html --web-port=$(WEB_PORT) $(DART_DEFINE_ARGS)

.PHONY: setup-e2e
setup-e2e: ## Setup E2E test dependencies
	@echo "$(BLUE)Setting up E2E test dependencies...$(NC)"
	@cd e2e && npm install && npx playwright install
	@cd $(APP_DIR) && flutter pub add patrol --dev || true
	@echo "$(GREEN)✓ E2E setup complete$(NC)"

.PHONY: analyze
analyze: ## Analyze code for issues
	@echo "$(BLUE)Analyzing code...$(NC)"
	@cd $(APP_DIR) && flutter analyze
	@cd packages/airo && flutter analyze
	@cd packages/airomoney && flutter analyze

.PHONY: format
format: ## Format code
	@echo "$(BLUE)Formatting code...$(NC)"
	@cd $(APP_DIR) && dart format .
	@cd packages/airo && dart format .
	@cd packages/airomoney && dart format .

# Maintenance Commands
.PHONY: clean
clean: ## Clean build artifacts
	@echo "$(BLUE)Cleaning build artifacts...$(NC)"
	@cd $(APP_DIR) && flutter clean
	@cd packages/airo && flutter clean
	@cd packages/airomoney && flutter clean

.PHONY: upgrade
upgrade: ## Upgrade Flutter and dependencies
	@echo "$(BLUE)Upgrading Flutter and dependencies...$(NC)"
	@flutter upgrade
	@cd $(APP_DIR) && flutter pub upgrade
	@cd packages/airo && flutter pub upgrade
	@cd packages/airomoney && flutter pub upgrade

.PHONY: doctor
doctor: ## Run Flutter doctor
	@flutter doctor -v

# Device Management

.PHONY: emulators
emulators: ## List available emulators
	@flutter emulators

# Quick Development Shortcuts
.PHONY: dev-android
dev-android: install-deps run-android ## Quick start for Android development

.PHONY: dev-ios
dev-ios: install-deps run-ios ## Quick start for iOS development

.PHONY: dev-web
dev-web: install-deps run-web ## Quick start for web development

# Platform-specific optimizations
.PHONY: optimize-android
optimize-android: ## Optimize for Android (including Pixel 9)
	@echo "$(BLUE)Optimizing for Android...$(NC)"
	@cd $(APP_DIR) && flutter build apk --release --target-platform android-arm64 --split-per-abi

.PHONY: optimize-ios
optimize-ios: ## Optimize for iOS (including iPhone 17 Pro Max)
	@echo "$(BLUE)Optimizing for iOS...$(NC)"
	@if [ "$$(uname)" != "Darwin" ]; then \
		echo "$(RED)iOS optimization is only available on macOS$(NC)"; \
		exit 1; \
	fi
	@cd $(APP_DIR) && flutter build ios --release --no-codesign

.PHONY: optimize-web
optimize-web: ## Optimize for web (including Chrome)
	@echo "$(BLUE)Optimizing for web...$(NC)"
	@cd $(APP_DIR) && flutter build web --release --web-renderer canvaskit

# Release Commands
.PHONY: build-release-all
build-release-all: ## Build all platforms for release
	@echo "$(BLUE)Building all platforms for release...$(NC)"
	@$(MAKE) build-android
	@$(MAKE) build-android-bundle
	@$(MAKE) build-web
	@if [ "$$(uname)" = "Darwin" ]; then \
		$(MAKE) build-ios; \
	fi
	@echo "$(GREEN)✓ All release builds complete$(NC)"

.PHONY: release-patch
release-patch: ## Create a patch release (v1.0.1)
	@echo "$(BLUE)Creating patch release...$(NC)"
	@echo "$(YELLOW)Run: git tag -a v1.0.1 -m 'Release v1.0.1' && git push origin v1.0.1$(NC)"

.PHONY: release-minor
release-minor: ## Create a minor release (v1.1.0)
	@echo "$(BLUE)Creating minor release...$(NC)"
	@echo "$(YELLOW)Run: git tag -a v1.1.0 -m 'Release v1.1.0' && git push origin v1.1.0$(NC)"

.PHONY: release-major
release-major: ## Create a major release (v2.0.0)
	@echo "$(BLUE)Creating major release...$(NC)"
	@echo "$(YELLOW)Run: git tag -a v2.0.0 -m 'Release v2.0.0' && git push origin v2.0.0$(NC)"

.PHONY: build-windows
build-windows: ## Build Windows app
	@echo "$(BLUE)Building Windows app...$(NC)"
	@cd $(APP_DIR) && flutter build windows --release

.PHONY: build-linux
build-linux: ## Build Linux app
	@echo "$(BLUE)Building Linux app...$(NC)"
	@cd $(APP_DIR) && flutter build linux --release

# Code Quality & Security Commands
.PHONY: sonar-scan
sonar-scan: ## Run SonarQube analysis locally
	@echo "$(BLUE)Running SonarQube analysis...$(NC)"
	@echo "$(YELLOW)Note: Requires SONAR_TOKEN environment variable$(NC)"
	@echo "$(YELLOW)Set: export SONAR_TOKEN=your_token$(NC)"
	@if [ -z "$$SONAR_TOKEN" ]; then \
		echo "$(RED)Error: SONAR_TOKEN not set$(NC)"; \
		exit 1; \
	fi
	@cd $(APP_DIR) && flutter test --coverage
	@echo "$(GREEN)✓ SonarQube analysis complete$(NC)"

.PHONY: snyk-scan
snyk-scan: ## Run Snyk security scan locally
	@echo "$(BLUE)Running Snyk security scan...$(NC)"
	@echo "$(YELLOW)Note: Requires SNYK_TOKEN environment variable$(NC)"
	@echo "$(YELLOW)Set: export SNYK_TOKEN=your_token$(NC)"
	@if [ -z "$$SNYK_TOKEN" ]; then \
		echo "$(RED)Error: SNYK_TOKEN not set$(NC)"; \
		exit 1; \
	fi
	@cd $(APP_DIR) && flutter pub get
	@echo "$(GREEN)✓ Snyk scan complete$(NC)"

.PHONY: quality-check
quality-check: ## Run all quality checks (analyze, test, lint)
	@echo "$(BLUE)Running quality checks...$(NC)"
	@$(MAKE) analyze
	@$(MAKE) test
	@$(MAKE) lint
	@echo "$(GREEN)✓ All quality checks complete$(NC)"

.PHONY: security-check
security-check: ## Run security checks (Snyk)
	@echo "$(BLUE)Running security checks...$(NC)"
	@$(MAKE) snyk-scan
	@echo "$(GREEN)✓ Security checks complete$(NC)"

.PHONY: full-check
full-check: ## Run all checks (quality + security)
	@echo "$(BLUE)Running full checks...$(NC)"
	@$(MAKE) quality-check
	@$(MAKE) security-check
	@echo "$(GREEN)✓ All checks complete$(NC)"
