#!/bin/bash

# ScamShield Flutter App - Rebuild and Install Script
# This script builds the app and installs it on the connected device

echo "🔧 ScamShield Flutter App - Rebuild and Install"
echo "=================================================="

# Change to the Flutter app directory
cd /Users/eklavya/Documents/scamshield_flutter_app

# Clean the build
echo "🧹 Cleaning previous build..."
flutter clean

# Get dependencies
echo "📦 Getting dependencies..."
flutter pub get

# Build the app
echo "🏗️ Building APK..."
flutter build apk --release

# Install the app
echo "📱 Installing app on device..."
flutter install

echo "✅ App installed successfully!"
echo "🚀 You can now test the enhanced permissions screen and quick scan features!"
echo ""
echo "🆕 NEW FEATURES:"
echo "• Fixed Quick Scan UI - green for safe, red for scam"
echo "• Comprehensive permissions screen with detailed explanations"
echo "• Permission summary showing exact coverage percentage"
echo "• Critical vs optional permission indicators"
echo "• Detailed explanations for partial protection status"
echo "• Better protection level indicators with tips"
echo ""
echo "🔍 TESTING TIPS:"
echo "1. Test quick scan with safe messages (should show green)"
echo "2. Check permissions screen from home screen toolbar"
echo "3. Grant permissions step by step and see coverage increase"
echo "4. Notice how protection level changes with more permissions"
echo "💡 Check the logs with: flutter logs"
