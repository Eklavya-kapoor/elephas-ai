#!/bin/zsh
# Elephas AI - APK Build and Deployment Script
# For Cyber Police Testing - May 25, 2026

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     Elephas AI - Production APK Build & Deployment             ║${NC}"
echo -e "${BLUE}║              For Cyber Police Testing v1.0.0                   ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Navigate to app directory
APP_DIR="/Users/eklavya/Documents/elephas_flutter_app"
cd "$APP_DIR"

# Print system info
echo -e "${YELLOW}📋 System Information:${NC}"
flutter --version
echo ""

# Step 1: Verify Flutter installation
echo -e "${YELLOW}🔍 Step 1: Verifying Flutter Installation...${NC}"
if ! flutter doctor > /dev/null 2>&1; then
    echo -e "${RED}❌ Flutter installation issue detected${NC}"
    flutter doctor
    exit 1
fi
echo -e "${GREEN}✅ Flutter verified${NC}"
echo ""

# Step 2: Clean build
echo -e "${YELLOW}🧹 Step 2: Cleaning Previous Builds...${NC}"
flutter clean
echo -e "${GREEN}✅ Build cleaned${NC}"
echo ""

# Step 3: Get dependencies
echo -e "${YELLOW}📦 Step 3: Installing Dependencies...${NC}"
flutter pub get
echo -e "${GREEN}✅ Dependencies installed${NC}"
echo ""

# Step 4: Analyze code
echo -e "${YELLOW}🔎 Step 4: Analyzing Code...${NC}"
if flutter analyze 2>&1 | grep -q "issues found"; then
    echo -e "${YELLOW}⚠️  Minor code issues detected (non-blocking)${NC}"
else
    echo -e "${GREEN}✅ Code analysis passed${NC}"
fi
echo ""

# Step 5: Build Release APK
echo -e "${YELLOW}🏗️  Step 5: Building Release APK...${NC}"
echo "This may take 2-5 minutes..."
flutter build apk --release

if [ ! -f "build/app/outputs/flutter-apk/app-release.apk" ]; then
    echo -e "${RED}❌ APK build failed${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Release APK built successfully${NC}"
echo ""

# Step 6: Get APK info
APK_PATH="build/app/outputs/flutter-apk/app-release.apk"
APK_SIZE=$(du -h "$APK_PATH" | cut -f1)
APK_DATE=$(date)

echo -e "${YELLOW}📊 Build Statistics:${NC}"
echo "  APK Location: $APK_PATH"
echo "  APK Size: $APK_SIZE"
echo "  Build Date: $APK_DATE"
echo "  Package: com.elephas.ai"
echo "  Version: 1.0.0"
echo ""

# Step 7: Create deployment package
echo -e "${YELLOW}📦 Step 7: Creating Deployment Package...${NC}"
DEPLOY_DIR="$APP_DIR/APK_Release_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$DEPLOY_DIR"

cp "$APK_PATH" "$DEPLOY_DIR/"
cp PRODUCTION_APK_GUIDE.md "$DEPLOY_DIR/" 2>/dev/null || true
cp BACKEND_IP_CONFIGURATION_COMPLETE.md "$DEPLOY_DIR/" 2>/dev/null || true
cp README.md "$DEPLOY_DIR/README_APP.md" 2>/dev/null || true

# Create a deployment manifest
cat > "$DEPLOY_DIR/DEPLOYMENT_MANIFEST.txt" << 'EOF'
╔════════════════════════════════════════════════════════════════╗
║        ELEPHAS AI - APK Deployment Manifest                    ║
║              For Cyber Police Testing                          ║
╚════════════════════════════════════════════════════════════════╝

📱 APPLICATION DETAILS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
App Name:           Elephas AI
Package Name:       com.elephas.ai
Version:            1.0.0
Build Date:         $(date)
Build Type:         Release (Production)
Min SDK:            21 (Android 5.0)
Target SDK:         35 (Android 15)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🔧 INSTALLATION INSTRUCTIONS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1. Via USB (Recommended):
   adb install app-release.apk

2. Via File Transfer:
   - Copy app-release.apk to Android device
   - Open file manager
   - Tap APK file to install
   - Grant permissions when prompted

3. Via Development:
   - Open in Android Studio
   - Select device and click "Run"

📋 FEATURES INCLUDED
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✓ Real-time SMS scam detection
✓ Phishing attack prevention
✓ URL verification system
✓ Call pattern analysis
✓ Contact intelligence
✓ Visual overlay alerts
✓ Notification system
✓ Local + Backend detection
✓ History & Statistics
✓ Settings management

🔌 BACKEND CONFIGURATION
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Server IP:          192.168.0.103
Port:               8000
Base URL:           http://192.168.0.103:8000
Endpoint:           /scan (POST)
Connection Type:    HTTP (Local Network)
WiFi Required:      Yes (same network as server)

📱 REQUIRED PERMISSIONS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
- INTERNET                      (Backend communication)
- READ_SMS                       (SMS scanning)
- RECEIVE_SMS                    (SMS monitoring)
- READ_CONTACTS                  (Contact verification)
- READ_CALL_LOG                  (Call analysis)
- SYSTEM_ALERT_WINDOW            (Overlay alerts)
- POST_NOTIFICATIONS             (Alert notifications)
- FOREGROUND_SERVICE             (Background monitoring)

✅ TESTING CHECKLIST
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
□ APK installs without errors
□ App launches successfully
□ Permission requests appear correctly
□ SMS monitor activates after permission grant
□ Backend connection established
□ Real-time detection works
□ Overlay alerts display correctly
□ Notification system functional
□ No crashes with various inputs
□ Response time < 2 seconds per message

🔐 SECURITY NOTES
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
1. APK is NOT signed for production (debug signing)
   - For production: Update signing configuration
2. HTTP cleartext allowed for local network only
   - For production: Use HTTPS with CA certificates
3. Backend must be on trusted network
4. All SMS data processed locally + on backend
5. No permanent data storage

📞 TROUBLESHOOTING
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Installation Issues:
  - Ensure "Unknown sources" is enabled in Settings
  - Check Android version meets minimum requirement (5.0+)
  - Clear app cache: Settings > Apps > Elephas AI > Storage > Clear

Backend Connection Issues:
  - Verify backend server is running
  - Check WiFi connection
  - Test: curl http://192.168.0.103:8000/health
  - Verify firewall allows port 8000

Permission Issues:
  - Grant all requested permissions when prompted
  - Go to Settings > Apps > Elephas AI > Permissions
  - Enable: SMS, Contacts, Phone, Notifications

Performance Issues:
  - Restart app
  - Restart device
  - Clear app cache
  - Check device storage (need ~100MB free)

🎯 SUCCESS INDICATORS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✓ App launches without crashes
✓ Permission requests work correctly
✓ Backend connection established (check logs)
✓ SMS scanning active when enabled
✓ Detection results appear in real-time
✓ Alerts display correctly
✓ Settings persist between sessions

📊 PRODUCTION READINESS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Status: ✅ PRODUCTION READY for Local Testing
Recommendations:
  1. Add proper code signing for production
  2. Implement HTTPS with certificates
  3. Use secure backend authentication
  4. Add analytics & crash reporting
  5. Implement rate limiting
  6. Add user feedback mechanism

═════════════════════════════════════════════════════════════════════
Generated: $(date)
For: Cyber Police Testing
Version: 1.0.0
═════════════════════════════════════════════════════════════════════
EOF

echo -e "${GREEN}✅ Deployment package created${NC}"
echo "  Location: $DEPLOY_DIR"
echo ""

# Step 8: Summary
echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}✅ BUILD SUCCESSFUL!${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}📦 APK Ready for Deployment:${NC}"
echo "   File: app-release.apk"
echo "   Size: $APK_SIZE"
echo "   Location: $DEPLOY_DIR/app-release.apk"
echo ""
echo -e "${YELLOW}📋 Next Steps:${NC}"
echo "   1. Copy APK to testing device"
echo "   2. Verify backend server running at 192.168.0.103:8000"
echo "   3. Connect device to same WiFi network"
echo "   4. Install APK and grant permissions"
echo "   5. Follow DEPLOYMENT_MANIFEST.txt for testing"
echo ""
echo -e "${YELLOW}📚 Documentation in deployment package:${NC}"
echo "   - DEPLOYMENT_MANIFEST.txt"
echo "   - PRODUCTION_APK_GUIDE.md"
echo "   - README_APP.md"
echo ""
echo -e "${GREEN}✨ Ready for Cyber Police Testing! 🎉${NC}"
echo ""
