#!/bin/bash

# This script finds and updates the Kotlin version in the Android project.
# It handles both old and new project structures.

set -e # Exit immediately if a command exits with a non-zero status.

NEW_KOTLIN_VERSION="1.9.24"

# --- Attempt to update the new config file (settings.gradle) ---
SETTINGS_FILE="android/settings.gradle"
if [ -f "$SETTINGS_FILE" ]; then
    echo "Found settings.gradle. Attempting to update Kotlin plugin version..."
    # This command finds the line with 'org.jetbrains.kotlin.android' and replaces the version
    sed -i -E "s/(id \"org.jetbrains.kotlin.android\" version \")[^\"]+(\")/\1$NEW_KOTLIN_VERSION\2/" "$SETTINGS_FILE"
    echo "Updated Kotlin plugin version in $SETTINGS_FILE to $NEW_KOTLIN_VERSION"
else
    echo "$SETTINGS_FILE not found."
fi

# --- Attempt to update the old config file (build.gradle) ---
BUILD_FILE="android/build.gradle"
if [ -f "$BUILD_FILE" ]; then
    echo "Found build.gradle. Attempting to update ext.kotlin_version..."
    if grep -q "ext.kotlin_version" "$BUILD_FILE"; then
        sed -i "s/ext.kotlin_version = .*/ext.kotlin_version = '$NEW_KOTLIN_VERSION'/" "$BUILD_FILE"
        echo "Updated ext.kotlin_version in $BUILD_FILE to $NEW_KOTLIN_VERSION"
    else
        # This case is less likely with the regenerate step, but included for safety
        sed -i "1i ext.kotlin_version = '$NEW_KOTLIN_VERSION'" "$BUILD_FILE"
        echo "Added ext.kotlin_version in $BUILD_FILE with version $NEW_KOTLIN_VERSION"
    fi
else
    echo "$BUILD_FILE not found."
fi

echo "Kotlin version update script finished."
