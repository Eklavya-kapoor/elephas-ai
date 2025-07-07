// test_scripts/test_mixed_language.dart
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';

// A simple console test app to verify mixed-language scam detection
void main() async {
  debugPrint("======= ELEPHAS AI MIXED LANGUAGE TEST =======");
  debugPrint("Testing scam detection on various text samples...");
  debugPrint("-----------------------------------------------");

  const apiUrl = 'http://127.0.0.1:8000/scan'; // Local API endpoint

  // Sample texts to test (including mixed language examples)
  final testTexts = [
    // English only - obvious scam
    "URGENT: Your bank account has been suspended. Click here to verify your details immediately: http://fakebank.com",

    // English only - not a scam
    "Hi there! Just checking in to see how you're doing today. Let's meet for coffee tomorrow?",

    // Hinglish - scam
    "Hello, kya haal hai? Aapke bank account mein suspicious activity hai. Jaldi apna OTP bhejo or account band ho jayega. Urgent!",

    // Hinglish - not a scam
    "Hey bhai, kya haal hai? Long time no see. Coffee peene chalte hai kal subah? Let me know.",

    // Hinglish with money scam
    "Congratulations! Aapne 10 lakh rupees jeeta hai lottery mein. Claim karne ke liye 5000 rupees processing fee bhejo is account mein: 1234567890",

    // Ambiguous case
    "Bank se call aaya tha. Kuch verification karne ke liye bola hai. Kal office jaakar dekhna padega."
  ];

  // Test each text
  for (var i = 0; i < testTexts.length; i++) {
    final text = testTexts[i];
    debugPrint("\n[$i] TESTING TEXT:");
    debugPrint(text);
    debugPrint("-----------------------------------------------");

    try {
      // Call with mixed_language detection enabled
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'text': text,
          'metadata': {
            'app': 'elephas_ai',
            'version': '1.0.0',
            'detect_mixed_language': true,
          }
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        debugPrint(
            "RESULT: ${data['risk_level']} (Score: ${data['risk_score'].toStringAsFixed(2)})");
        debugPrint("EXPLANATION: ${data['explanation']}");

        if (data.containsKey('mixed_language_detection')) {
          debugPrint("MIXED LANGUAGE: Detected");
          debugPrint(
              "ADJUSTED SCORE: ${data['mixed_language_detection']['adjusted_score'] ? 'Yes' : 'No'}");
        } else {
          debugPrint("MIXED LANGUAGE: Not detected");
        }
      } else {
        debugPrint("Error: Status code ${response.statusCode}");
        debugPrint(response.body);
      }
    } catch (e) {
      debugPrint("Error: $e");
      debugPrint(
          "(API server may not be running. Make sure to start the backend first.)");
    }

    debugPrint("-----------------------------------------------");
  }

  debugPrint("\nTest complete! You can now analyze the results.");
}
