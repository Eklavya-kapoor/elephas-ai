#!/usr/bin/env python3
import requests
import json

def test_scam_detection():
    url = 'http://localhost:5000/api/detect'
    
    # Test message with common scam patterns
    test_message = {
        'message': 'Congratulations! You have won $5000! To claim your prize, send us your bank details and a processing fee of $50.',
        'metadata': {
            'source': 'sms',
            'language': 'en',
            'timestamp': '2025-08-12T10:00:00Z'
        }
    }
    
    try:
        print('🔍 Testing scam detection API...')
        response = requests.post(url, json=test_message)
        response.raise_for_status()
        
        result = response.json()
        print('\n📝 Results:')
        print(json.dumps(result, indent=2))
        
        if result.get('is_scam'):
            print('\n🚨 Scam Detected!')
            print(f"Confidence: {result.get('confidence', 0) * 100:.1f}%")
            print(f"Primary Reason: {result.get('primary_reason', 'Unknown')}")
        else:
            print('\n✅ Message appears safe')
            
    except requests.RequestException as e:
        print(f'\n❌ Error testing API: {e}')
        
if __name__ == '__main__':
    test_scam_detection()
