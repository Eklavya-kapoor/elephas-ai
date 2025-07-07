#!/bin/bash
# Script to test the Elephas AI mixed language detection

echo "====== ELEPHAS AI TEST RUNNER ======"
echo "Starting backend API..."

# Path to your backend API
BACKEND_PATH="/Users/eklavya/Desktop/scamshield-ai"

# Start the backend in a separate terminal
echo "Starting backend..."
cd "$BACKEND_PATH" && python run.py &
BACKEND_PID=$!

echo "Waiting for backend to start (5 seconds)..."
sleep 5

# Run the test
echo "Running mixed language tests..."
cd /Users/eklavya/Documents/scamshield_flutter_app
flutter run -d chrome test_scripts/test_mixed_language.dart

# Clean up
echo "Tests complete. Stopping backend..."
kill $BACKEND_PID

echo "Done!"
