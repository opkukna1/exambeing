#!/bin/bash

# This script finds and updates the Kotlin version in the Android build file.

set -e # Exit immediately if a command exits with a non-zero status.

BUILD_FILE="android/build.gradle"

if [ ! -f "$BUILD_FILE" ]; then
    echo "build.gradle not found at $BUILD_FILE. Skipping Kotlin version update."
    exit 0
fi

if grep -q "ext.kotlin_version" "$BUILD_FILE"; then
    sed -i "s/ext.kotlin_version = .*/ext.kotlin_version = '1.9.22'/" "$BUILD_FILE"
    echo "Kotlin version updated to 1.9.22"
else
    # A more robust way to insert the line at the top of the file
    awk 'NR==1{print "ext.kotlin_version = \'1.9.22\'"}1' "$BUILD_FILE" > tmpfile && mv tmpfile "$BUILD_FILE"
    echo "Added Kotlin version 1.9.22"
fi
