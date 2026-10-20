#!/usr/bin/env python3
import requests
import json
import time

def test_overlay_trigger():
    url = 'http://127.0.0.1:8000/api/detect'
    
    # Test message with urgent scam patterns to trigger overlay
    test_message = {
        'message': '🚨 URGENT: Your bank account has been compromised! Call +1-555-0123 immediately or your funds will be lost. Requires immediate verification of your credentials.',
        'metadata': {
            'source': 'sms',
            'language': 'en',
            'timestamp': '2025-08-13T10:00:00Z',
            'priority': 'high',
            'requires_overlay': True
        }
    }
    
    try:
        print('🔍 Sending high-priority test message to trigger overlay...')
        response = requests.post(url, json=test_message)
        response.raise_for_status()
        
        result = response.json()
        print('\n📝 Detection Results:')
        print(json.dumps(result, indent=2))
        
        if result.get('is_scam'):
            print('\n🚨 Scam Detected!')
            print(f"Confidence: {result.get('confidence', 0) * 100:.1f}%")
            print(f"Primary Reason: {result.get('primary_reason', 'Unknown')}")
            print('\nOverlay should appear on device if permissions are granted.')
        else:
            print('\n⚠️ Message not detected as scam - overlay won\'t show')
            
    except requests.RequestException as e:
        print(f'\n❌ Error testing API: {e}')

if __name__ == '__main__':
    test_overlay_trigger()
