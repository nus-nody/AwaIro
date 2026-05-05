# AwaIro — root Makefile
# All targets operate on SPM packages under packages/.
# Xcode App target is added in Phase 1.

PACKAGES := AwaIroDomain AwaIroData AwaIroPlatform AwaIroPresentation
SWIFT_FORMAT := $(shell command -v swift-format 2>/dev/null)

.PHONY: all bootstrap build test test-ios test-snapshot test-app-smoke lint verify archive-kmp clean clean-build help

all: verify

help:
	@echo "AwaIro Makefile targets:"
	@echo "  bootstrap     - Resolve SPM dependencies for all packages"
	@echo "  build         - swift build all packages"
	@echo "  test          - swift test all packages"
	@echo "  test-ios      - test-snapshot + test-app-smoke"
	@echo "  test-snapshot - run snapshot tests (xcodebuild on iOS Simulator)"
	@echo "  test-app-smoke - boot sim, install, launch, verify no crash (3s observation)"
	@echo "  lint          - swift-format --lint (no-op if not installed)"
	@echo "  verify        - build + test + test-ios + lint (DoD check)"
	@echo "  archive-kmp   - guarded helper: archive any remaining KMP files"
	@echo "                  Set ARCHIVE_CONFIRM=1 to actually delete (HITL)"
	@echo "  clean         - remove .build directories under packages/"
	@echo "  clean-build   - remove root build/ (xcodebuild derived artifacts)"

bootstrap:
	@for pkg in $(PACKAGES); do \
		echo "==> Resolving packages/$$pkg"; \
		(cd packages/$$pkg && swift package resolve) || exit 1; \
	done

build:
	@for pkg in $(PACKAGES); do \
		echo "==> Building packages/$$pkg"; \
		(cd packages/$$pkg && swift build) || exit 1; \
	done

test:
	@for pkg in $(PACKAGES); do \
		echo "==> Testing packages/$$pkg"; \
		(cd packages/$$pkg && swift test) || exit 1; \
	done

test-ios: test-snapshot test-app-smoke

test-app-smoke:
	@bash scripts/smoke-app.sh

test-snapshot:
	@echo "==> Snapshot tests via xcodebuild (AwaIroPresentation SPM package)"
	@cd packages/AwaIroPresentation && xcodebuild test \
		-scheme AwaIroPresentation \
		-destination 'platform=iOS Simulator,name=iPhone 16 (AwaIro)' \
		-only-testing:AwaIroPresentationTests/HomeScreenSnapshotTests \
		-only-testing:AwaIroPresentationTests/MemoScreenSnapshotTests \
		-only-testing:AwaIroPresentationTests/GalleryScreenSnapshotTests \
		-only-testing:AwaIroPresentationTests/PhotoDetailScreenSnapshotTests \
		-only-testing:AwaIroPresentationTests/PaletteSheetSnapshotTests \
		2>&1 | grep -E '(passed|failed|error:|TEST (SUCCEEDED|FAILED))' | tail -15

lint:
ifeq ($(SWIFT_FORMAT),)
	@echo "WARN: swift-format not found in PATH. Skipping lint."
	@echo "      Install via: brew install swift-format"
else
	@echo "==> swift-format lint --recursive --strict packages/"
	@$(SWIFT_FORMAT) lint --recursive --strict packages/
endif

verify: build test test-ios lint
	@echo ""
	@echo "✅ make verify passed (build + test + test-ios + lint)"

archive-kmp:
	@KMP_FILES=$$(ls build.gradle.kts settings.gradle.kts gradlew gradlew.bat gradle.properties 2>/dev/null; \
		ls -d gradle composeApp iosApp 2>/dev/null; \
		ls .github/workflows/ci.yml 2>/dev/null) ; \
	if [ -z "$$KMP_FILES" ]; then \
		echo "✅ No KMP files found at repo root. Nothing to archive."; \
		exit 0; \
	fi; \
	echo "Found KMP files/dirs:"; \
	echo "$$KMP_FILES"; \
	if [ "$$ARCHIVE_CONFIRM" != "1" ]; then \
		echo ""; \
		echo "🟡 dry-run mode. To actually delete, run:"; \
		echo "   ARCHIVE_CONFIRM=1 make archive-kmp"; \
		echo "   (HITL approval required before execution)"; \
		exit 0; \
	fi; \
	echo "🔴 ARCHIVE_CONFIRM=1 detected. Deleting..."; \
	echo "$$KMP_FILES" | xargs -I{} git rm -r {} ; \
	echo "✅ KMP files removed. Commit with: git commit -m 'chore: archive remaining KMP files'"

clean:
	@for pkg in $(PACKAGES); do \
		rm -rf packages/$$pkg/.build packages/$$pkg/.swiftpm; \
	done
	@echo "✅ Cleaned all package build artifacts"

clean-build:
	@if [ -d build ]; then \
		echo "==> Removing root build/ (xcodebuild derived artifacts)"; \
		rm -rf build/; \
		echo "✅ Cleaned build/"; \
	else \
		echo "✅ No build/ directory to clean"; \
	fi
