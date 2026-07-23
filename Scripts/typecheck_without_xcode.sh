#!/bin/sh
set -eu

SDK_PATH=$(xcrun --sdk macosx --show-sdk-path)
TYPECHECK_DIR=/private/tmp/catatwork-typecheck
MODULE_CACHE_DIR=/private/tmp/catatwork-module-cache
mkdir -p "$TYPECHECK_DIR" "$MODULE_CACHE_DIR"

xcrun swiftc -emit-module -parse-as-library -enable-testing -swift-version 6 \
  -enable-bare-slash-regex -module-name CatAtWorkCore -sdk "$SDK_PATH" \
  -module-cache-path "$MODULE_CACHE_DIR" Sources/CatAtWorkCore/*.swift \
  -emit-module-path "$TYPECHECK_DIR/CatAtWorkCore.swiftmodule"

xcrun swiftc -emit-module -parse-as-library -swift-version 6 -module-name Sparkle \
  -sdk "$SDK_PATH" -module-cache-path "$MODULE_CACHE_DIR" Scripts/TypecheckSupport/SparkleStub.swift \
  -emit-module-path "$TYPECHECK_DIR/Sparkle.swiftmodule"

xcrun swiftc -typecheck -parse-as-library -swift-version 6 -enable-bare-slash-regex \
  -I "$TYPECHECK_DIR" -sdk "$SDK_PATH" -module-cache-path "$MODULE_CACHE_DIR" \
  Sources/CatAtWork/*.swift Scripts/TypecheckSupport/BundleModuleStub.swift

xcrun swiftc -swift-version 6 -enable-bare-slash-regex -sdk "$SDK_PATH" \
  -module-cache-path "$MODULE_CACHE_DIR" Sources/CatAtWorkCore/*.swift Scripts/core_smoke.swift \
  -o "$TYPECHECK_DIR/core-smoke"
"$TYPECHECK_DIR/core-smoke" Sources/CatAtWork/Resources/DefaultPet.catpet
