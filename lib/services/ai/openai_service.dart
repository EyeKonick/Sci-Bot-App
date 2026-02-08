import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// OpenAI Service for GPT-4 API integration
/// Handles streaming responses and error handling
///
/// Week 3 Day 1 Implementation
/// Phase 0: Added 30-second timeout to all API calls
class OpenAIService {
  static final OpenAIService _instance = OpenAIService._internal();
  factory OpenAIService() => _instance;
  OpenAIService._internal();

  late final String _apiKey;
  late final String _model;
  late final double _temperature;
  late final int _maxTokens;
  bool _isInitialized = false;

  /// Timeout duration for all API calls
  static const Duration apiTimeout = Duration(seconds: 30);

  /// Initialize service with API key from .env
  Future<void> initialize() async {
    // Skip if already initialized
    if (_isInitialized) {
      print('OpenAI service already initialized');
      return;
    }

    await dotenv.load(fileName: ".env");
    
    _apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';
    _model = dotenv.env['OPENAI_MODEL'] ?? 'gpt-4-turbo-preview';
    _temperature = double.parse(dotenv.env['OPENAI_TEMPERATURE'] ?? '0.7');
    _maxTokens = int.parse(dotenv.env['OPENAI_MAX_TOKENS'] ?? '500');

    if (_apiKey.isEmpty || _apiKey == 'your_api_key_here') {
      throw Exception('OpenAI API key not configured. Please update .env file.');
    }

    _isInitialized = true;
    print('✅ OpenAI service initialized successfully');
  }

  /// Send chat completion request with streaming
  Stream<String> streamChatCompletion({
    required List<Map<String, dynamic>> messages,
    double? temperature,
    int? maxTokens,
  }) async* {
    final url = Uri.parse('https://api.openai.com/v1/chat/completions');
    
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $_apiKey',
    };

    final body = jsonEncode({
      'model': _model,
      'messages': messages,
      'temperature': temperature ?? _temperature,
      'max_tokens': maxTokens ?? _maxTokens,
      'stream': true,
    });

    try {
      final request = http.Request('POST', url);
      request.headers.addAll(headers);
      request.body = body;

      final response = await request.send().timeout(
        apiTimeout,
        onTimeout: () {
          throw TimeoutException(
            'OpenAI API request timed out after ${apiTimeout.inSeconds} seconds',
            apiTimeout,
          );
        },
      );

      if (response.statusCode != 200) {
        final errorBody = await response.stream.bytesToString().timeout(apiTimeout);
        throw Exception('OpenAI API error: ${response.statusCode} - $errorBody');
      }

      // Track time since last chunk to detect stalled streams
      var lastChunkTime = DateTime.now();

      await for (final chunk in response.stream.transform(utf8.decoder).transform(const LineSplitter())) {
        // Check if stream has stalled (no data for 30 seconds)
        final elapsed = DateTime.now().difference(lastChunkTime);
        if (elapsed > apiTimeout) {
          throw TimeoutException(
            'OpenAI API stream stalled after ${apiTimeout.inSeconds} seconds',
            apiTimeout,
          );
        }
        lastChunkTime = DateTime.now();

        if (chunk.startsWith('data: ')) {
          final data = chunk.substring(6);

          if (data == '[DONE]') {
            break;
          }

          try {
            final json = jsonDecode(data);
            final content = json['choices']?[0]?['delta']?['content'];

            if (content != null && content is String && content.isNotEmpty) {
              yield content;
            }
          } catch (e) {
            // Skip malformed chunks
            continue;
          }
        }
      }
    } on TimeoutException catch (e) {
      throw Exception('Request timed out: ${e.message}');
    } catch (e) {
      throw Exception('Failed to stream chat: $e');
    }
  }

  /// Non-streaming chat completion (for simple requests)
  Future<String> chatCompletion({
    required List<Map<String, dynamic>> messages,
    double? temperature,
    int? maxTokens,
  }) async {
    final url = Uri.parse('https://api.openai.com/v1/chat/completions');
    
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $_apiKey',
    };

    final body = jsonEncode({
      'model': _model,
      'messages': messages,
      'temperature': temperature ?? _temperature,
      'max_tokens': maxTokens ?? _maxTokens,
      'stream': false,
    });

    try {
      final response = await http.post(url, headers: headers, body: body).timeout(
        apiTimeout,
        onTimeout: () {
          throw TimeoutException(
            'OpenAI API request timed out after ${apiTimeout.inSeconds} seconds',
            apiTimeout,
          );
        },
      );

      if (response.statusCode != 200) {
        throw Exception('OpenAI API error: ${response.statusCode} - ${response.body}');
      }

      final json = jsonDecode(response.body);
      return json['choices'][0]['message']['content'] as String;
    } on TimeoutException catch (e) {
      throw Exception('Request timed out: ${e.message}');
    } catch (e) {
      throw Exception('Failed to get chat completion: $e');
    }
  }

  /// Check if API key is configured
  bool get isConfigured => _apiKey.isNotEmpty && _apiKey != 'your_api_key_here';

  /// Get current model name
  String get modelName => _model;
}