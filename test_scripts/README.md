# Elephas AI Testing Guide

This guide helps you test the mixed-language scam detection capabilities of Elephas AI.

## Prerequisites

1. Make sure your backend API is running
2. Ensure you have Python installed with the 'requests' library (`pip install requests`)

## Testing Options

### Option 1: Quick Python Test (Recommended)

This is the easiest way to test the mixed-language capabilities:

```bash
# First, start the backend API in one terminal:
cd /Users/eklavya/Desktop/scamshield-ai
python run.py

# In another terminal, run the Python test script:
cd /Users/eklavya/Documents/scamshield_flutter_app
./test_scripts/python_test.py
```

### Option 2: Using the Flutter Test

If you want to test using the Flutter environment:

```bash
cd /Users/eklavya/Documents/scamshield_flutter_app
flutter run -d chrome test_scripts/test_mixed_language.dart
```

## What to Expect

The test will run 6 sample messages through the system:

1. English scam message
2. English normal message
3. Hinglish scam message
4. Hinglish normal message
5. Hinglish lottery scam
6. Ambiguous mixed-language message

For each message, you'll see:
- The risk level and score
- The explanation
- Whether mixed-language detection was triggered
- Whether the score was adjusted based on mixed-language patterns

## Interpreting Results

- **HIGH RISK / CRITICAL RISK**: These messages should trigger alerts
- **MEDIUM RISK**: These messages may show a warning
- **LOW RISK**: These are likely safe messages

## Real Device Testing

To test on a real device, install the app and:

1. Enable accessibility services
2. Grant all required permissions
3. Send yourself test messages or view them in WhatsApp
4. Watch for the overlay warning when a scam is detected

## Troubleshooting

If the API tests fail:
- Make sure the backend is running on port 8000
- Check that the API endpoint URL is correct
- Verify there are no firewall issues blocking connections
