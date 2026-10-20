#!/bin/bash

echo "Connecting to wireless debugging..."
adb connect 172.20.10.2:37809

# Check if connection was successful
if adb devices | grep -q "172.20.10.2:37809"; then
    echo "Successfully connected to device"
    echo "Current devices:"
    adb devices
else
    echo "Failed to connect. Please check that:"
    echo "1. The device is on the same network"
    echo "2. Wireless debugging is enabled"
    echo "3. The IP and port are correct"
fi
