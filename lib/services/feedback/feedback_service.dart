import 'package:emailjs/emailjs.dart' as emailjs;

/// Sends user feedback to scibot05@gmail.com via the official EmailJS Flutter SDK.
/// Credentials are embedded directly because EmailJS keys are client-side
/// by design (always visible in network traffic) and intended for client use.
///
/// REQUIRED: Enable "Allow EmailJS API for non-browser applications" in
/// EmailJS Dashboard → Account → Security, otherwise calls return 403.
class FeedbackService {
  static final FeedbackService _instance = FeedbackService._internal();
  factory FeedbackService() => _instance;
  FeedbackService._internal();

  // EmailJS client-side credentials — safe to embed (designed for client use).
  static const _serviceId  = 'service_ua0x0rn';
  static const _templateId = 'template_d56kmzi';
  static const _publicKey  = '1qc-OVQ8Sx2VQ297G';
  static const _privateKey = 'xktkH8Z38ks0qVxUaWNR0';

  Future<void> sendFeedback({
    required String senderEmail,
    required String userName,
    String? gender,
    String? gradeSection,
    String? school,
    String? intent,
    required String message,
    required String timestamp,
  }) async {
    await emailjs.send(
      _serviceId,
      _templateId,
      {
        'from_email': senderEmail,
        'from_name': userName,
        'user_gender': gender ?? 'N/A',
        'user_grade': gradeSection ?? 'N/A',
        'user_school': school ?? 'N/A',
        'user_intent': (intent == null || intent.isEmpty) ? 'N/A' : intent,
        'message': message.isEmpty ? 'N/A' : message,
        'timestamp': timestamp,
      },
      const emailjs.Options(
        publicKey: _publicKey,
        privateKey: _privateKey,
      ),
    );
  }
}
