import 'dart:convert';

import 'package:firebase_ai/firebase_ai.dart';

import '../domain/markaz_ai.dart';

class FirebaseMarkazAiGateway implements ExternalAiGateway {
  FirebaseMarkazAiGateway()
    : _model = FirebaseAI.googleAI().generativeModel(
        model: 'gemini-3.5-flash-lite',
        systemInstruction: Content.system(_systemInstruction),
        generationConfig: GenerationConfig(
          maxOutputTokens: 220,
          temperature: 0.2,
          thinkingConfig: ThinkingConfig.withThinkingLevel(
            ThinkingLevel.minimal,
          ),
        ),
      );

  final GenerativeModel _model;

  @override
  bool get configured => true;

  @override
  Future<String> send({
    required String prompt,
    required Map<String, Object?> data,
  }) async {
    final response = await _model
        .generateContent([Content.text(_buildUserContent(prompt, data))])
        .timeout(const Duration(seconds: 30));
    final answer = response.text?.trim();
    if (answer == null || answer.isEmpty) {
      throw StateError('Gemini returned an empty response.');
    }
    return answer;
  }

  @override
  Stream<String> sendStream({
    required String prompt,
    required Map<String, Object?> data,
  }) async* {
    final stream = _model
        .generateContentStream([Content.text(_buildUserContent(prompt, data))])
        .timeout(const Duration(seconds: 30));
    var receivedAny = false;
    await for (final chunk in stream) {
      final text = chunk.text;
      if (text != null && text.isNotEmpty) {
        receivedAny = true;
        yield text;
      }
    }
    if (!receivedAny) {
      throw StateError('Gemini returned an empty response.');
    }
  }

  String _buildUserContent(String prompt, Map<String, Object?> data) {
    final compact = <String, Object?>{};
    data.forEach((key, value) {
      if (value == null) return;
      if (value is List && value.isEmpty) return;
      compact[key] = value;
    });
    return 'Financial summary: ${jsonEncode(compact)}\nUser question: $prompt';
  }

  static const _systemInstruction = '''
You are Markaz AI, the financial assistant inside MeraMarkaz.

Rules:
- Reply in the language used by the user.
- Support English, Urdu and Roman Urdu.
- Use only the financial summary supplied by MeraMarkaz.
- Never invent balances, transactions, tax rates or utility tariffs.
- Never request passwords, CNIC numbers, payment-card details or authentication tokens.
- Never claim to be a financial, tax, legal or religious professional.
- Clearly state when the supplied data is insufficient.
- Treat all generated responses as informational.
- Do not create, edit or delete financial records.
- If the user asks to change data, explain that confirmation is required inside the app.
- Keep answers concise and suitable for a Pakistani audience.
- Answer in 2 to 4 short sentences unless the user explicitly asks for detail.
''';
}
