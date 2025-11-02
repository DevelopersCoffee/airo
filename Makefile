# Airo Super App Makefile
# Cross-platform build and development automation

# Variables
FLUTTER_VERSION := 3.24.0
APP_DIR := app
ANDROID_DIR := $(APP_DIR)/android
IOS_DIR := $(APP_DIR)/ios
WEB_DIR := $(APP_DIR)/web

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
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | grep -E '(android|ios|web|chrome|pixel)' | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2}'

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
		else \
			cd $(IOS_DIR) && pod install; \
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

.PHONY: run-android-auto
run-android-auto: ## Run app on any connected Android device
	@echo "$(BLUE)Running on Android (auto-detect)...$(NC)"
	@cd $(APP_DIR) && flutter run -d android

.PHONY: run-android
run-android: ## Run app on Android device/emulator (Pixel 9)
	@echo "$(BLUE)Running on Android (Pixel 9)...$(NC)"
	@cd $(APP_DIR) && flutter run --device-id "4C031VDAQ000GG"

.PHONY: run-pixel9
run-pixel9: ## Run app specifically optimized for Pixel 9
	@echo "$(BLUE)Running on Pixel 9 (Android)...$(NC)"
	@cd $(APP_DIR) && flutter run --device-id "4C031VDAQ000GG" --target-platform android-arm64

.PHONY: run-ios
run-ios: ## Run app on iOS device/simulator
	@echo "$(BLUE)Running on iOS...$(NC)"
	@if [ "$$(uname)" != "Darwin" ]; then \
		echo "$(RED)iOS development is only available on macOS$(NC)"; \
		exit 1; \
	fi
	@cd $(APP_DIR) && flutter run -d ios

.PHONY: run-iphone13
run-iphone13: ## Run app on iPhone 13 Pro Max simulator
	@echo "$(BLUE)Running on iPhone 13 Pro Max...$(NC)"
	@if [ "$$(uname)" != "Darwin" ]; then \
		echo "$(RED)iOS development is only available on macOS$(NC)"; \
		exit 1; \
	fi
	@cd $(APP_DIR) && flutter run -d "iPhone 13 Pro Max"

.PHONY: run-web
run-web: ## Run app on web browser
	@echo "$(BLUE)Running on web...$(NC)"
	@cd $(APP_DIR) && flutter run -d web-server --web-port 8080

.PHONY: run-chrome
run-chrome: ## Run app specifically on Chrome browser
	@echo "$(BLUE)Running on Chrome...$(NC)"
	@cd $(APP_DIR) && flutter run -d chrome --web-port 8080

# Build Commands
.PHONY: build-android
build-android: ## Build Android APK
	@echo "$(BLUE)Building Android APK...$(NC)"
	@cd $(APP_DIR) && flutter build apk --release

.PHONY: build-android-bundle
build-android-bundle: ## Build Android App Bundle for Play Store
	@echo "$(BLUE)Building Android App Bundle...$(NC)"
	@cd $(APP_DIR) && flutter build appbundle --release

.PHONY: build-ios
build-ios: ## Build iOS app
	@echo "$(BLUE)Building iOS app...$(NC)"
	@if [ "$$(uname)" != "Darwin" ]; then \
		echo "$(RED)iOS building is only available on macOS$(NC)"; \
		exit 1; \
	fi
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

.PHONY: test-integration
test-integration: ## Run integration tests
	@echo "$(BLUE)Running integration tests...$(NC)"
	@cd $(APP_DIR) && flutter test integration_test/

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
optimize-ios: ## Optimize for iOS (including iPhone 13 Pro Max)
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
