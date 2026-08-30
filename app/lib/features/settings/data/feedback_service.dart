import 'dart:convert';
import 'dart:io';

class FeedbackService {
  const FeedbackService();

  static const endpoint = String.fromEnvironment(
    'FEEDBACK_API_URL',
    defaultValue: 'https://mera-markaz.vercel.app/api/feedback',
  );

  Future<void> submit({
    required String message,
    String? name,
    String? phone,
  }) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final request = await client.postUrl(Uri.parse(endpoint));
      request.headers.contentType = ContentType.json;
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.write(
        jsonEncode({
          'name': name?.trim(),
          'phone': phone?.trim(),
          'message': message.trim(),
          'source': 'Mera Markaz Android',
        }),
      );
      final response = await request.close().timeout(
        const Duration(seconds: 12),
      );
      final body = await utf8.decoder.bind(response).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        String detail = 'Feedback could not be sent.';
        try {
          detail =
              (jsonDecode(body) as Map<String, dynamic>)['error'] as String;
        } catch (_) {}
        throw FeedbackSubmissionException(detail);
      }
    } on FeedbackSubmissionException {
      rethrow;
    } catch (_) {
      throw const FeedbackSubmissionException(
        'Could not contact the feedback service. Check your internet connection and try again.',
      );
    } finally {
      client.close(force: true);
    }
  }
}

class FeedbackSubmissionException implements Exception {
  const FeedbackSubmissionException(this.message);
  final String message;
}
