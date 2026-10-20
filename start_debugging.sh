#!/bin/bash

echo "====================================="
echo "   SCAMSHIELD FLUTTER APP SETUP     "
echo "====================================="
echo ""

# Check ADB installation
if ! command -v adb &> /dev/null; then
    echo "❌ ADB not found. Please install Android SDK platform tools first."
    echo "You can install it via Homebrew: brew install android-platform-tools"
    exit 1
fi

# Check Flutter installation
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter not found. Please install Flutter first."
    echo "Visit: https://flutter.dev/docs/get-started/install/macos"
    exit 1
fi

# Function to check device connection
check_device() {
    devices=$(flutter devices)
    if [[ $devices == *"No devices"* ]]; then
        return 1
    else
        return 0
    fi
}

echo "1. 📱 Connecting to device..."
echo "Please follow these steps on your Android device:"
echo "a) Enable Developer Options (Settings → About Phone → Tap Build Number 7 times)"
echo "b) Enable Wireless Debugging (Settings → Developer Options → Wireless Debugging)"
echo "c) Tap 'Pair device with pairing code' in Wireless Debugging"
echo ""
read -p "Enter the IP address shown (e.g., 192.168.1.XXX): " ip_address
read -p "Enter the port number shown: " port
read -p "Enter the pairing code shown: " pairing_code

echo ""
echo "Attempting to pair with device..."
adb pair "${ip_address}:${port}" "${pairing_code}"

if [ $? -eq 0 ]; then
    echo "✅ Pairing successful!"
    
    # Get the debugging port (usually 5555)
    echo ""
    read -p "Enter the debugging port shown in Wireless Debugging menu (default: 5555): " debug_port
    debug_port=${debug_port:-5555}
    
    echo "Connecting to device for debugging..."
    adb connect "${ip_address}:${debug_port}"
    
    if [ $? -eq 0 ]; then
        echo "✅ Connected successfully!"
    else
        echo "❌ Failed to connect. Please try again."
        exit 1
    fi
else
    echo "❌ Pairing failed. Please try again."
    exit 1
fi

echo ""
echo "2. 🚀 Installing and running the app..."

# Start the backend server in the background
./start_backend.sh &
backend_pid=$!

# Build and install the app
flutter pub get
flutter build apk --debug
flutter install

if [ $? -eq 0 ]; then
    echo "✅ App installed successfully!"
    echo ""
    echo "3. 📋 Testing checklist:"
    echo "   □ Grant SMS permissions"
    echo "   □ Grant call log permissions"
    echo "   □ Grant overlay permissions"
    echo "   □ Grant notification permissions"
    echo ""
    echo "4. 🔍 To test the app:"
    echo "   - Send a test SMS to the device"
    echo "   - Make a test call to the device"
    echo "   - Check if the overlay appears for suspicious messages/calls"
    echo ""
    echo "5. 🛠 Useful commands:"
    echo "   - View logs: flutter logs"
    echo "   - Restart app: flutter run"
    echo "   - Stop backend: kill $backend_pid"
    echo "   - Disconnect device: adb disconnect ${ip_address}:${debug_port}"
    echo ""
    echo "✨ Setup complete! The app should now be running on your device."
else
    echo "❌ Failed to install the app. Please check the error messages above."
    kill $backend_pid
    exit 1
fi
