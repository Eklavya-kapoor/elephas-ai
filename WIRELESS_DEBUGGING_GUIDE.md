# 📱 Wireless Android Debugging Setup Guide

## Method 1: Wireless Debugging (Android 11+) - RECOMMENDED

### Step 1: Enable Developer Options
1. **Go to Settings** → **About Phone**
2. **Tap "Build Number" 7 times** until you see "You are now a developer"
3. **Go back to Settings** → **System** → **Developer Options**

### Step 2: Enable Wireless Debugging
1. In **Developer Options**, find **"Wireless Debugging"**
2. **Toggle it ON**
3. **Tap "Wireless Debugging"** to enter the settings

### Step 3: Pair Your Device
1. In Wireless Debugging settings, tap **"Pair device with pairing code"**
2. **Write down the IP address, Port, and 6-digit code** shown on screen
3. **Keep this screen open** on your phone

### Step 4: Connect from Your Computer
Run this command in terminal (replace with your device's details):
```bash
adb pair 192.168.1.XXX:XXXXX
# Enter the 6-digit pairing code when prompted
```

### Step 5: Connect for Debugging
After pairing, connect using:
```bash
adb connect 192.168.1.XXX:5555
# Use the IP shown in "Wireless debugging" main screen
```

### Step 6: Verify Connection
```bash
flutter devices
# Your device should now appear as "Android Device"
```

---

## Method 2: WiFi ADB (Older Android) - ALTERNATIVE

### If your Android is older than 11:
1. **Connect via USB once** to enable WiFi debugging
2. **Enable USB Debugging** in Developer Options
3. Run: `adb tcpip 5555`
4. **Disconnect USB cable**
5. Find your device's WiFi IP in Settings → WiFi → Connected Network
6. Run: `adb connect 192.168.1.XXX:5555` (replace XXX with device IP)

---

## Method 3: QR Code Pairing (Android 11+)

### Alternative wireless setup:
1. **Enable Wireless Debugging** (Steps 1-2 above)
2. In Wireless Debugging, tap **"Pair device with QR code"**
3. Run on computer: `adb pair`
4. **Scan the QR code** shown on computer with your phone
5. Device will pair automatically

---

## 🔧 Troubleshooting

### If device doesn't appear:
```bash
# Check ADB devices
adb devices

# Restart ADB server
adb kill-server
adb start-server

# Check Flutter devices again
flutter devices
```

### If connection fails:
1. **Ensure both devices are on same WiFi network**
2. **Disable VPN** if using one
3. **Restart Wireless Debugging** on phone
4. **Re-pair** if needed

### Common commands:
```bash
# List paired devices
adb devices

# Disconnect device
adb disconnect 192.168.1.XXX:5555

# Reconnect
adb connect 192.168.1.XXX:5555

# Check Flutter devices
flutter devices
```

---

## 🚀 Deploy Your App Wirelessly

Once connected, you can:
```bash
# Run app on wireless device
flutter run

# Build and install APK
flutter build apk --release
flutter install
```

## ✅ Benefits of Wireless Debugging:
- **No USB cable needed**
- **Test app while moving around**
- **Multiple devices can connect**
- **Stable connection once set up**

**Your Elephas AI app will now run wirelessly on your Android device for testing!**
