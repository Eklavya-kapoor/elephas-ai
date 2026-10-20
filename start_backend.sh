#!/bin/bash
# Start the Elephas AI backend server

echo "Starting Elephas AI backend server..."
echo "This will provide the AI scam detection capabilities for your app."
echo ""

# Change directory to the scamshield-ai folder
cd /Users/eklavya/Desktop/scamshield-ai

# Start the server
echo "Starting server on 192.168.0.106:8000..."
python3 run.py --host 192.168.0.106 --port 8000