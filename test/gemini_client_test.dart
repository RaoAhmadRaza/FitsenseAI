import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dio/dio.dart';
import 'package:ai_fitness_tracker/core/network/gemini_client.dart';

class _MockHttpClientAdapter extends Mock implements HttpClientAdapter {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GeminiClient', () {
    setUpAll(() {
      registerFallbackValue(RequestOptions(path: '/'));
    });

    test('basic response and token extraction', () async {
      final adapter = _MockHttpClientAdapter();
      final dio = Dio(
        BaseOptions(headers: {'Content-Type': 'application/json'}),
      )..httpClientAdapter = adapter;
      final client = GeminiClient('test-key', dio: dio);

      final fake = {
        'candidates': [
          {
            'content': {
              'parts': [
                {'text': 'Hello!'},
              ],
            },
          },
        ],
        'usageMetadata': {'totalTokenCount': 42},
      };

      when(() => adapter.fetch(any(), any(), any())).thenAnswer((inv) async {
        return ResponseBody.fromString(
          jsonEncode(fake),
          200,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        );
      });

      final res = await client.sendPrompt('hi');
      expect(res['candidates'], isNotNull);
      expect(client.extractTokenCount(res), 42);
    });

    test('error handling maps 401', () async {
      final adapter = _MockHttpClientAdapter();
      final dio = Dio(
        BaseOptions(headers: {'Content-Type': 'application/json'}),
      )..httpClientAdapter = adapter;
      final client = GeminiClient('k', dio: dio);
      when(() => adapter.fetch(any(), any(), any())).thenAnswer((_) async {
        return ResponseBody.fromString('unauthorized', 401);
      });
      expect(
        () => client.sendPrompt('x'),
        throwsA(
          isA<GeminiException>().having((e) => e.code, 'code', 'unauthorized'),
        ),
      );
    });

    test('error handling maps 429', () async {
      final adapter = _MockHttpClientAdapter();
      final dio = Dio(
        BaseOptions(headers: {'Content-Type': 'application/json'}),
      )..httpClientAdapter = adapter;
      final client = GeminiClient('k', dio: dio);
      when(() => adapter.fetch(any(), any(), any())).thenAnswer((_) async {
        return ResponseBody.fromString('rate', 429);
      });
      expect(
        () => client.sendPrompt('x'),
        throwsA(
          isA<GeminiException>().having((e) => e.code, 'code', 'rateLimit'),
        ),
      );
    });

    test('error handling maps timeout to networkOffline', () async {
      final adapter = _MockHttpClientAdapter();
      final dio = Dio(
        BaseOptions(headers: {'Content-Type': 'application/json'}),
      )..httpClientAdapter = adapter;
      final client = GeminiClient('k', dio: dio);
      when(() => adapter.fetch(any(), any(), any())).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: 'test'),
          type: DioExceptionType.connectionTimeout,
        ),
      );
      expect(
        () => client.sendPrompt('x'),
        throwsA(
          isA<GeminiException>().having(
            (e) => e.code,
            'code',
            'networkOffline',
          ),
        ),
      );
    });

    test('error handling maps 500 to serverError', () async {
      final adapter = _MockHttpClientAdapter();
      final dio = Dio(
        BaseOptions(headers: {'Content-Type': 'application/json'}),
      )..httpClientAdapter = adapter;
      final client = GeminiClient('k', dio: dio);
      when(() => adapter.fetch(any(), any(), any())).thenAnswer((_) async {
        return ResponseBody.fromString('oops', 500);
      });
      expect(
        () => client.sendPrompt('x'),
        throwsA(
          isA<GeminiException>().having((e) => e.code, 'code', 'serverError'),
        ),
      );
    });

    test('streamPrompt throws normalized error when request fails', () async {
      final adapter = _MockHttpClientAdapter();
      final dio = Dio(
        BaseOptions(headers: {'Content-Type': 'application/json'}),
      )..httpClientAdapter = adapter;
      final client = GeminiClient('k', dio: dio);
      when(() => adapter.fetch(any(), any(), any())).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: 'stream'),
          type: DioExceptionType.connectionError,
        ),
      );
      await expectLater(
        client.streamPrompt('x'),
        emitsError(
          isA<GeminiException>().having(
            (e) => e.code,
            'code',
            'networkOffline',
          ),
        ),
      );
    });

    test('extractTokenCount returns null when usage metadata missing', () {
      final client = GeminiClient('k');
      expect(client.extractTokenCount({'foo': 'bar'}), isNull);
    });

    test('streaming yields expected chunks', () async {
      final adapter = _MockHttpClientAdapter();
      final dio = Dio(
        BaseOptions(headers: {'Content-Type': 'application/json'}),
      )..httpClientAdapter = adapter;
      final client = GeminiClient('k', dio: dio);

      final controller = StreamController<Uint8List>();
      addTearDown(() => controller.close());

      when(() => adapter.fetch(any(), any(), any())).thenAnswer((inv) async {
        Future.microtask(() {
          final evt1 =
              'data: ' +
              jsonEncode({
                'candidates': [
                  {
                    'content': {
                      'parts': [
                        {'text': 'Hello'},
                      ],
                    },
                  },
                ],
              }) +
              '\n\n';

          final evt2 =
              'data: ' +
              jsonEncode({
                'candidates': [
                  {
                    'content': {
                      'parts': [
                        {'text': ' world!'},
                      ],
                    },
                  },
                ],
              }) +
              '\n\n';

          controller.add(Uint8List.fromList(utf8.encode(evt1)));
          controller.add(Uint8List.fromList(utf8.encode(evt2)));
          controller.close();
        });

        return ResponseBody(controller.stream, 200);
      });

      final chunks = <String>[];
      await for (final c in client.streamPrompt('x')) {
        chunks.add(c);
      }
      expect(chunks, ['Hello', ' world!']);
      expect(chunks.join(), 'Hello world!');
    });
  });
}
