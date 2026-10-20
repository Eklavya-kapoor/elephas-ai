#!/bin/zsh
# 🛡️ ELEPHAS AI - Flutter APK Build Script
# Builds production APK for 50+ officer deployment

FLUTTER_DIR="/Users/eklavya/Documents/elephas_flutter_app"
OUTPUT_DIR="$FLUTTER_DIR/build/app/outputs/flutter-apk"

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║              ELEPHAS AI - APK BUILD SCRIPT                   ║"
echo "║              Production Release v1.0.0                       ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Check Flutter installation
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter not found. Please install Flutter."
    exit 1
fi

cd "$FLUTTER_DIR"

echo "📋 Build Information:"
echo "   Project: $FLUTTER_DIR"
echo "   Flutter: $(flutter --version | head -1)"
echo ""

echo "🔧 Preparing build..."
echo "   - Cleaning previous builds..."
flutter clean

echo "   - Fetching dependencies..."
flutter pub get

echo ""
echo "🏗️  Building release APK..."
echo "   (This may take 2-5 minutes)"
echo ""

flutter build apk --release

if [ ! -f "$OUTPUT_DIR/app-release.apk" ]; then
    echo "❌ Build failed - APK not found"
    exit 1
fi

APK_SIZE=$(du -h "$OUTPUT_DIR/app-release.apk" | cut -f1)

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                    ✅ BUILD SUCCESSFUL                       ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "📦 APK Details:"
echo "   Location: $OUTPUT_DIR/app-release.apk"
echo "   Size: $APK_SIZE"
echo "   Build Date: $(date)"
echo ""
echo "📋 Next Steps for Deployment:"
echo "   1. Copy APK to distribution system"
echo "   2. Distribute to 50+ officer devices"
echo "   3. Install via: adb install app-release.apk"
echo "   4. Or send via WhatsApp/Email for manual install"
echo ""
echo "🌐 Backend Configuration:"
echo "   - Server: http://192.168.0.103:8000"
echo "   - Scanendpoint: /scan"
echo "   - No API key needed"
echo ""
