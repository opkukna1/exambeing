#!/bin/bash

# This script finds and updates the Kotlin version in the Android build file.

set -e # Exit immediately if a command exits with a non-zero status.

BUILD_FILE="android/build.gradle"
NEW_KOTLIN_VERSION="1.9.24" # Using a newer version

if [ ! -f "$BUILD_FILE" ]; then
    echo "build.gradle not found at $BUILD_FILE. Skipping Kotlin version update."
    exit 0
fi

if grep -q "ext.kotlin_version" "$BUILD_FILE"; then
    # ✅ FIX: Updated to the new Kotlin version
    sed -i "s/ext.kotlin_version = .*/ext.kotlin_version = '$NEW_KOTLIN_VERSION'/" "$BUILD_FILE"
    echo "Kotlin version updated to $NEW_KOTLIN_VERSION"
else
    # ✅ FIX: Updated to the new Kotlin version
    sed -i "1i ext.kotlin_version = '$NEW_KOTLIN_VERSION'" "$BUILD_FILE"
    echo "Added Kotlin version $NEW_KOTLIN_VERSION"
fi
