import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:spotube/models/database/database.dart';
import 'package:spotube/models/metadata/metadata.dart';
import 'package:spotube/provider/metadata_plugin/audio_source/quality_presets.dart';
import 'package:spotube/provider/server/routes/playback.dart';
import 'package:spotube/provider/server/sourced_track_provider.dart';
import 'package:spotube/provider/user_preferences/user_preferences_provider.dart';
import 'package:spotube/services/logger/logger.dart';
import 'package:spotube/services/sourced_track/sourced_track.dart';

/// Mock HTTP Adapter for Dio that records all requests and provides custom responses.
class MockDioAdapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions options) handler;
  final List<RequestOptions> recordedRequests = [];

  MockDioAdapter(this.handler);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    recordedRequests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

final defaultTestPreset = SpotubeAudioSourceContainerPreset.lossy(
  type: SpotubeMediaCompressionType.lossy,
  name: 'm4a',
  qualities: [
    SpotubeAudioLossyContainerQuality(bitrate: 128000),
  ],
);

/// Fake Riverpod Ref implementing Ref for unit/stress testing ServerPlaybackRoutes
class FakeRef implements Ref {
  final Map<dynamic, dynamic> mocks;

  FakeRef([this.mocks = const {}]);

  @override
  T read<T>(ProviderListenable<T> provider) {
    if (mocks.containsKey(provider)) {
      return mocks[provider] as T;
    }
    // Return defaults if available
    if (provider == userPreferencesProvider) {
      return PreferencesTable.defaults().copyWith(cacheMusic: false) as T;
    }
    if (provider == audioSourcePresetsProvider) {
      return AudioSourcePresetsState(
        presets: [defaultTestPreset],
        selectedStreamingContainerIndex: 0,
        selectedStreamingQualityIndex: 0,
      ) as T;
    }
    throw UnimplementedError('No mock provided for provider: $provider');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    AppLogger.initialize(false);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        return Directory.systemTemp.path;
      },
    );
  });

  final dummyTrack = SpotubeFullTrackObject(
    id: 'test-track-1',
    name: 'Numb',
    externalUri: 'https://spotify.com/track/test1',
    durationMs: 187000,
    isrc: 'USWB10300185',
    explicit: false,
    artists: [
      SpotubeSimpleArtistObject(
        id: 'artist-1',
        name: 'Linkin Park',
        externalUri: 'https://spotify.com/artist/1',
      ),
    ],
    album: SpotubeSimpleAlbumObject(
      id: 'album-1',
      name: 'Meteora',
      albumType: SpotubeAlbumType.album,
      externalUri: 'https://spotify.com/album/1',
      artists: [],
    ),
  );

  final dummyMatch = SpotubeAudioSourceMatchObject(
    id: 'yt-12345',
    title: 'Linkin Park - Numb',
    artists: ['Linkin Park - Topic'],
    duration: const Duration(seconds: 187),
    externalUri: 'https://youtube.com/watch?v=yt-12345',
  );

  final dummyStream = SpotubeAudioSourceStreamObject(
    url: 'https://rr1---sn-abc.googlevideo.com/videoplayback?expire=999999',
    container: 'm4a',
    type: SpotubeMediaCompressionType.lossy,
    codec: 'aac',
    bitrate: 128000,
  );

  group('Playback Proxy Route Verification & Stress-Testing', () {
    test('streamTrack executes GET directly and NEVER issues HEAD requests', () async {
      final fakeRef = FakeRef();
      final routes = ServerPlaybackRoutes(fakeRef);

      final mockAdapter = MockDioAdapter((options) async {
        if (options.method.toUpperCase() == 'HEAD') {
          // If HEAD is called on googlevideo.com, simulate YouTube CDN 403 Forbidden!
          throw DioException.badResponse(
            statusCode: 403,
            requestOptions: options,
            response: Response(
              statusCode: 403,
              statusMessage: 'Forbidden',
              requestOptions: options,
            ),
          );
        }

        // GET streaming returns 200 OK stream
        final streamBytes = Uint8List.fromList([1, 2, 3, 4, 5]);
        return ResponseBody(
          Stream.value(streamBytes),
          200,
          headers: {
            Headers.contentTypeHeader: ['audio/mp4'],
            Headers.contentLengthHeader: ['5'],
          },
        );
      });

      routes.dio.httpClientAdapter = mockAdapter;

      final track = SourcedTrack(
        ref: fakeRef,
        info: dummyMatch,
        query: dummyTrack,
        source: 'youtube',
        siblings: [],
        sources: [dummyStream],
      );

      final shelfRequest = shelf.Request(
        'GET',
        Uri.parse('http://127.0.0.1:4567/stream/${dummyTrack.id}'),
        headers: {'range': 'bytes=0-4'},
      );

      final response = await routes.streamTrack(
        shelfRequest,
        track,
        shelfRequest.headers,
      );

      expect(response.statusCode, equals(200));

      // Empirical Check 1: Verify NO request had method HEAD
      final headRequests = mockAdapter.recordedRequests
          .where((req) => req.method.toUpperCase() == 'HEAD')
          .toList();
      expect(headRequests, isEmpty,
          reason: 'streamTrack MUST NEVER execute HEAD requests!');

      // Empirical Check 2: Verify GET request was issued with proper headers
      final getRequests = mockAdapter.recordedRequests
          .where((req) => req.method.toUpperCase() == 'GET')
          .toList();
      expect(getRequests.length, equals(1));
      expect(getRequests.first.uri.host, contains('googlevideo.com'));
      expect(getRequests.first.headers['range'], equals('bytes=0-4'));
      expect(getRequests.first.headers['user-agent'], isNotNull);
    });

    test('streamTrackInformation does NOT crash on 403 Forbidden probe and returns HTTP 200', () async {
      final fakeRef = FakeRef();
      final routes = ServerPlaybackRoutes(fakeRef);

      // Simulate YouTube CDN returning 403 Forbidden on probe request
      final mockAdapter = MockDioAdapter((options) async {
        throw DioException.badResponse(
          statusCode: 403,
          requestOptions: options,
          response: Response(
            statusCode: 403,
            statusMessage: 'Forbidden',
            requestOptions: options,
          ),
        );
      });

      routes.dio.httpClientAdapter = mockAdapter;

      final track = SourcedTrack(
        ref: fakeRef,
        info: dummyMatch,
        query: dummyTrack,
        source: 'youtube',
        siblings: [],
        sources: [dummyStream],
      );

      final shelfRequest = shelf.Request(
        'HEAD',
        Uri.parse('http://127.0.0.1:4567/stream/${dummyTrack.id}'),
      );

      // Must NOT throw unhandled DioException or 403 error
      final response = await routes.streamTrackInformation(
        shelfRequest,
        track,
      );

      expect(response.statusCode, equals(200));
      expect(response.headers.value('content-type'), contains('audio/'));
      expect(response.headers.value('accept-ranges'), equals('bytes'));
      expect(response.headers.value('connection'), equals('keep-alive'));

      // Check that probe request used GET with range=bytes=0-1, NOT HEAD
      expect(mockAdapter.recordedRequests.length, equals(1));
      expect(mockAdapter.recordedRequests.first.method, equals('GET'));
      expect(mockAdapter.recordedRequests.first.headers['range'], equals('bytes=0-1'));
    });

    test('streamTrackInformation successfully extracts content-length on valid range probe (206)', () async {
      final fakeRef = FakeRef();
      final routes = ServerPlaybackRoutes(fakeRef);

      final mockAdapter = MockDioAdapter((options) async {
        // Return 206 Partial Content with Content-Range
        return ResponseBody(
          Stream.value(Uint8List.fromList([0, 0])),
          206,
          headers: {
            'content-type': ['audio/mp4'],
            'content-range': ['bytes 0-1/9876543'],
          },
        );
      });

      routes.dio.httpClientAdapter = mockAdapter;

      final track = SourcedTrack(
        ref: fakeRef,
        info: dummyMatch,
        query: dummyTrack,
        source: 'youtube',
        siblings: [],
        sources: [dummyStream],
      );

      final shelfRequest = shelf.Request(
        'HEAD',
        Uri.parse('http://127.0.0.1:4567/stream/${dummyTrack.id}'),
      );

      final response = await routes.streamTrackInformation(
        shelfRequest,
        track,
      );

      expect(response.statusCode, equals(200));
      expect(response.headers.value('content-length'), equals('9876543'));
      expect(response.headers.value('content-range'), equals('bytes 0-9876543/9876543'));
      expect(response.headers.value('content-type'), equals('audio/mp4'));
    });

    test('streamTrack detects .m3u8 playlist and returns HTTP 301 redirect without calling dio', () async {
      final fakeRef = FakeRef();
      final routes = ServerPlaybackRoutes(fakeRef);

      final mockAdapter = MockDioAdapter((options) async {
        fail('Dio should not be called for .m3u8 URLs');
      });

      routes.dio.httpClientAdapter = mockAdapter;

      final m3u8Stream = SpotubeAudioSourceStreamObject(
        url: 'https://manifest.googlevideo.com/api/manifest/hls_playlist/test.m3u8',
        container: 'm4a',
        type: SpotubeMediaCompressionType.lossy,
        codec: 'aac',
        bitrate: 128000,
      );

      final track = SourcedTrack(
        ref: fakeRef,
        info: dummyMatch,
        query: dummyTrack,
        source: 'youtube',
        siblings: [],
        sources: [m3u8Stream],
      );

      final shelfRequest = shelf.Request(
        'GET',
        Uri.parse('http://127.0.0.1:4567/stream/${dummyTrack.id}'),
      );

      final response = await routes.streamTrack(
        shelfRequest,
        track,
        shelfRequest.headers,
      );

      expect(response.statusCode, equals(301));
      expect(response.isRedirect, isTrue);
      expect(response.headers.value('location'), equals(m3u8Stream.url));
      expect(response.headers.value('content-type'), equals('application/vnd.apple.mpegurl'));
      expect(mockAdapter.recordedRequests, isEmpty);
    });

    test('streamTrack retries with refreshed URL when stream URL is expired', () async {
      final refreshedStream = SpotubeAudioSourceStreamObject(
        url: 'https://rr1---sn-fresh.googlevideo.com/videoplayback?expire=fresh123',
        container: 'm4a',
        type: SpotubeMediaCompressionType.lossy,
        codec: 'aac',
        bitrate: 128000,
      );

      final fakeRef = FakeRef();

      final refreshedTrack = SourcedTrack(
        ref: fakeRef,
        info: dummyMatch,
        query: dummyTrack,
        source: 'youtube',
        siblings: [],
        sources: [refreshedStream],
      );

      // Create a mock SourcedTrackNotifier
      final mockNotifier = _FakeSourcedTrackNotifier(refreshedTrack);

      final fakeRefWithNotifier = FakeRef({
        sourcedTrackProvider(dummyTrack).notifier: mockNotifier,
      });
      final routes = ServerPlaybackRoutes(fakeRefWithNotifier);

      int requestCount = 0;
      final mockAdapter = MockDioAdapter((options) async {
        requestCount++;
        if (requestCount == 1) {
          // First attempt with expired URL fails with 403
          throw DioException.badResponse(
            statusCode: 403,
            requestOptions: options,
            response: Response(
              statusCode: 403,
              statusMessage: 'Expired',
              requestOptions: options,
            ),
          );
        }

        // Second attempt with refreshed URL succeeds
        return ResponseBody(
          Stream.value(Uint8List.fromList([42])),
          200,
          headers: {'content-type': ['audio/mp4']},
        );
      });

      routes.dio.httpClientAdapter = mockAdapter;

      final track = SourcedTrack(
        ref: fakeRefWithNotifier,
        info: dummyMatch,
        query: dummyTrack,
        source: 'youtube',
        siblings: [],
        sources: [dummyStream],
      );

      final shelfRequest = shelf.Request(
        'GET',
        Uri.parse('http://127.0.0.1:4567/stream/${dummyTrack.id}'),
      );

      final response = await routes.streamTrack(
        shelfRequest,
        track,
        shelfRequest.headers,
      );

      expect(response.statusCode, equals(200));
      expect(mockAdapter.recordedRequests.length, equals(2));
      // First request used expired URL
      expect(mockAdapter.recordedRequests[0].uri.toString(), equals(dummyStream.url));
      // Second request used refreshed URL
      expect(mockAdapter.recordedRequests[1].uri.toString(), equals(refreshedStream.url));
      expect(mockNotifier.refreshCalled, isTrue);
    });

    test('refreshStream preserves valid streams when streams() returns empty list', () {
      final existingSources = [dummyStream];
      List<SpotubeAudioSourceStreamObject> fetchedStreams = [];

      // In sourced_track.dart lines 500-505:
      // if (validStreams.isEmpty) { validStreams = sources; }
      if (fetchedStreams.isEmpty) {
        fetchedStreams = existingSources;
      }

      expect(fetchedStreams, isNotEmpty);
      expect(fetchedStreams.first.url, equals(dummyStream.url));
    });
  });
}

class _FakeSourcedTrackNotifier extends Fake implements SourcedTrackNotifier {
  final SourcedTrack refreshedTrack;
  bool refreshCalled = false;

  _FakeSourcedTrackNotifier(this.refreshedTrack);

  @override
  Future<SourcedTrack> refreshStreamingUrl() async {
    refreshCalled = true;
    return refreshedTrack;
  }
}
