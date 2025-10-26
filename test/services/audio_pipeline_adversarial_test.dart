import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:spotube/models/metadata/metadata.dart';
import 'package:spotube/services/audio_player/audio_player.dart';
import 'package:spotube/services/sourced_track/sourced_track.dart';

void main() {
  group('Empirical Challenge: SpotubeMedia Loopback & URL Construction', () {
    final fullTrack = SpotubeFullTrackObject(
      id: 'track-uuid-9876',
      name: 'Test Song',
      externalUri: 'https://spotify.com/track/9876',
      durationMs: 200000,
      isrc: 'USWB10000987',
      explicit: false,
      artists: [
        SpotubeSimpleArtistObject(
          id: 'art-1',
          name: 'Artist One',
          externalUri: 'https://spotify.com/artist/1',
        ),
      ],
      album: SpotubeSimpleAlbumObject(
        id: 'alb-1',
        name: 'Album One',
        albumType: SpotubeAlbumType.album,
        externalUri: 'https://spotify.com/album/1',
        artists: [],
      ),
    );

    test('SpotubeMedia.host is invariant and strictly 127.0.0.1', () {
      expect(SpotubeMedia.host, equals('127.0.0.1'));
      expect(SpotubeMedia.host, isNot(equals('0.0.0.0')));
      expect(SpotubeMedia.host, isNot(equals('localhost')));
    });

    test('SpotubeMedia constructs correct loopback URI across boundary ports', () {
      final testPorts = [0, 80, 443, 1024, 8080, 43210, 65535];
      for (final port in testPorts) {
        SpotubeMedia.serverPort = port;
        final media = SpotubeMedia(fullTrack);
        // Standard HTTP port 80 is omitted in normalized Uri.toString() per RFC 3986
        final expectedUri = port == 80
            ? 'http://127.0.0.1/stream/${fullTrack.id}'
            : 'http://127.0.0.1:$port/stream/${fullTrack.id}';
        expect(
          media.uri,
          equals(expectedUri),
          reason: 'Failed on uri for port $port',
        );
      }
    });

    test('SpotubeMedia handles track IDs with special characters/symbols', () {
      SpotubeMedia.serverPort = 8080;
      final specialIds = [
        'normal_123',
        'yt-video_id-99',
        'track:with:colons',
        'unicode-곡-123',
      ];

      for (final id in specialIds) {
        final specialTrack = SpotubeFullTrackObject(
          id: id,
          name: 'Special ID Song',
          externalUri: 'https://spotify.com/track/$id',
          durationMs: 180000,
          isrc: 'USWB10000001',
          explicit: false,
          artists: [],
          album: SpotubeSimpleAlbumObject(
            id: 'alb-special',
            name: 'Special Album',
            albumType: SpotubeAlbumType.album,
            externalUri: 'https://spotify.com/album/special',
            artists: [],
          ),
        );

        final media = SpotubeMedia(specialTrack);
        expect(media.uri, equals(Uri.parse('http://127.0.0.1:8080/stream/$id').toString()));
      }
    });

    test('SpotubeMedia unconditionally preserves local file paths without loopback URL', () {
      final paths = [
        '/storage/emulated/0/Music/song.mp3',
        'C:\\Users\\User\\Music\\song.flac',
        '/data/user/0/com.spotube/cache/audio.m4a',
        'relative/path/to/audio.opus',
      ];

      for (final p in paths) {
        final localTrack = SpotubeLocalTrackObject(
          id: 'local-test',
          name: 'Local Song',
          externalUri: 'file://$p',
          path: p,
          durationMs: 200000,
          artists: [],
          album: SpotubeSimpleAlbumObject(
            id: 'alb-local',
            name: 'Local',
            albumType: SpotubeAlbumType.album,
            externalUri: 'file:///',
            artists: [],
          ),
        );

        final media = SpotubeMedia(localTrack);
        expect(media.uri, equals(p));
        expect(media.uri, isNot(contains('127.0.0.1')));
        expect(media.uri, isNot(contains('http://')));
      }
    });
  });

  group('Empirical Challenge: SourcedTrack.getStreamOfQuality Adversarial Stress', () {
    final queryTrack = SpotubeFullTrackObject(
      id: 'query-adv',
      name: 'Adversarial Track',
      externalUri: 'https://spotify.com/track/adv',
      durationMs: 200000,
      isrc: 'USWB10000002',
      explicit: false,
      artists: [],
      album: SpotubeSimpleAlbumObject(
        id: 'alb-adv',
        name: 'Adversarial Album',
        albumType: SpotubeAlbumType.album,
        externalUri: 'https://spotify.com/album/adv',
        artists: [],
      ),
    );

    final matchInfo = SpotubeAudioSourceMatchObject(
      id: 'match-adv',
      title: 'Adversarial Match',
      artists: ['Artist'],
      duration: const Duration(seconds: 200),
      externalUri: 'https://youtube.com/watch?v=adv',
    );

    final m4aPreset = SpotubeAudioSourceContainerPreset.lossy(
      type: SpotubeMediaCompressionType.lossy,
      name: 'm4a',
      qualities: [
        SpotubeAudioLossyContainerQuality(bitrate: 128000),
        SpotubeAudioLossyContainerQuality(bitrate: 256000),
      ],
    );

    final webmPreset = SpotubeAudioSourceContainerPreset.lossy(
      type: SpotubeMediaCompressionType.lossy,
      name: 'webm',
      qualities: [
        SpotubeAudioLossyContainerQuality(bitrate: 128000),
        SpotubeAudioLossyContainerQuality(bitrate: 256000),
      ],
    );

    final opusPreset = SpotubeAudioSourceContainerPreset.lossy(
      type: SpotubeMediaCompressionType.lossy,
      name: 'opus',
      qualities: [
        SpotubeAudioLossyContainerQuality(bitrate: 160000),
      ],
    );

    final mp4Preset = SpotubeAudioSourceContainerPreset.lossy(
      type: SpotubeMediaCompressionType.lossy,
      name: 'mp4',
      qualities: [
        SpotubeAudioLossyContainerQuality(bitrate: 128000),
      ],
    );

    test('Adversarial 1: Empty sources list always yields null safely', () {
      final track = SourcedTrack(
        info: matchInfo,
        query: queryTrack,
        source: 'youtube',
        siblings: [],
        sources: [],
      );

      expect(track.getStreamOfQuality(m4aPreset, 0), isNull);
      expect(track.getStreamOfQuality(m4aPreset, -1), isNull);
      expect(track.getStreamOfQuality(m4aPreset, 9999), isNull);
      expect(track.getStreamOfQuality(webmPreset, 0), isNull);
      expect(track.getStreamOfQuality(opusPreset, 0), isNull);
      expect(track.getStreamOfQuality(mp4Preset, 0), isNull);
    });

    test('Adversarial 2: Empty preset qualities handled without RangeError or NullPointer', () {
      final emptyQualityPreset = SpotubeAudioSourceContainerPreset.lossy(
        type: SpotubeMediaCompressionType.lossy,
        name: 'm4a',
        qualities: [],
      );

      final streamWebm = SpotubeAudioSourceStreamObject(
        url: 'https://googlevideo.com/stream/webm',
        container: 'webm',
        type: SpotubeMediaCompressionType.lossy,
        codec: 'opus',
        bitrate: 128000,
      );

      final track = SourcedTrack(
        info: matchInfo,
        query: queryTrack,
        source: 'youtube',
        siblings: [],
        sources: [streamWebm],
      );

      final stream = track.getStreamOfQuality(emptyQualityPreset, 0);
      expect(stream, isNotNull);
      expect(stream!.url, equals('https://googlevideo.com/stream/webm'));
    });

    test('Adversarial 3: Out-of-bounds qualityIndex boundary values (-99999 to +99999)', () {
      final stream1 = SpotubeAudioSourceStreamObject(
        url: 'https://googlevideo.com/stream/1',
        container: 'm4a',
        type: SpotubeMediaCompressionType.lossy,
        codec: 'aac',
        bitrate: 128000,
      );
      final stream2 = SpotubeAudioSourceStreamObject(
        url: 'https://googlevideo.com/stream/2',
        container: 'm4a',
        type: SpotubeMediaCompressionType.lossy,
        codec: 'aac',
        bitrate: 256000,
      );

      final track = SourcedTrack(
        info: matchInfo,
        query: queryTrack,
        source: 'youtube',
        siblings: [],
        sources: [stream1, stream2],
      );

      final extremeIndices = [-99999, -100, -1, 2, 3, 100, 99999];
      for (final idx in extremeIndices) {
        final result = track.getStreamOfQuality(m4aPreset, idx);
        expect(result, isNotNull, reason: 'Failed for qualityIndex: $idx');
        // When idx is out of bounds, fallback uses preset.qualities.firstOrNull (128000), which matches stream1 exactly
        expect(result!.bitrate, equals(128000));
      }
    });

    test('Adversarial 4: Single-source lists with completely mismatched containers', () {
      final exoticContainers = ['flv', 'ogg', 'wav', 'aac', '3gp', 'unknown_format', ''];

      for (final containerName in exoticContainers) {
        final singleStream = SpotubeAudioSourceStreamObject(
          url: 'https://googlevideo.com/stream/$containerName',
          container: containerName,
          type: SpotubeMediaCompressionType.lossy,
          codec: 'unknown',
          bitrate: 96000,
        );

        final track = SourcedTrack(
          info: matchInfo,
          query: queryTrack,
          source: 'youtube',
          siblings: [],
          sources: [singleStream],
        );

        // Test with all presets
        for (final preset in [m4aPreset, webmPreset, opusPreset, mp4Preset]) {
          final stream = track.getStreamOfQuality(preset, 0);
          expect(stream, isNotNull, reason: 'Failed for container $containerName with preset ${preset.name}');
          expect(stream!.url, equals('https://googlevideo.com/stream/$containerName'));
        }
      }
    });

    test('Adversarial 5: Case-insensitive container matching in all permutations', () {
      final streamM4A = SpotubeAudioSourceStreamObject(
        url: 'https://googlevideo.com/stream/M4A_UPPER',
        container: 'M4A',
        type: SpotubeMediaCompressionType.lossy,
        codec: 'aac',
        bitrate: 256000,
      );

      final track = SourcedTrack(
        info: matchInfo,
        query: queryTrack,
        source: 'youtube',
        siblings: [],
        sources: [streamM4A],
      );

      final stream = track.getStreamOfQuality(m4aPreset, 1);
      expect(stream, isNotNull);
      expect(stream!.url, equals('https://googlevideo.com/stream/M4A_UPPER'));

      // Also test preset with uppercase name
      final upperPreset = SpotubeAudioSourceContainerPreset.lossy(
        type: SpotubeMediaCompressionType.lossy,
        name: 'M4A',
        qualities: [SpotubeAudioLossyContainerQuality(bitrate: 256000)],
      );
      final stream2 = track.getStreamOfQuality(upperPreset, 0);
      expect(stream2, isNotNull);
      expect(stream2!.url, equals('https://googlevideo.com/stream/M4A_UPPER'));
    });

    test('Adversarial 6: Null and missing bitrate/sampleRate fields gracefully handled', () {
      final streamNullBitrate1 = SpotubeAudioSourceStreamObject(
        url: 'https://googlevideo.com/stream/null_br_1',
        container: 'mp4',
        type: SpotubeMediaCompressionType.lossy,
        codec: 'aac',
        bitrate: null,
      );

      final streamNullBitrate2 = SpotubeAudioSourceStreamObject(
        url: 'https://googlevideo.com/stream/null_br_2',
        container: 'mp4',
        type: SpotubeMediaCompressionType.lossy,
        codec: 'aac',
        bitrate: null,
      );

      final track = SourcedTrack(
        info: matchInfo,
        query: queryTrack,
        source: 'youtube',
        siblings: [],
        sources: [streamNullBitrate1, streamNullBitrate2],
      );

      // Should not throw NoSuchMethodError on null.abs()
      final stream = track.getStreamOfQuality(mp4Preset, 0);
      expect(stream, isNotNull);
    });

    test('Adversarial 7: Multi-tier fallback order correctness across all presets', () {
      final streamWebm = SpotubeAudioSourceStreamObject(
        url: 'url_webm',
        container: 'webm',
        type: SpotubeMediaCompressionType.lossy,
        codec: 'opus',
        bitrate: 128000,
      );
      final streamOpus = SpotubeAudioSourceStreamObject(
        url: 'url_opus',
        container: 'opus',
        type: SpotubeMediaCompressionType.lossy,
        codec: 'opus',
        bitrate: 128000,
      );
      final streamMp4 = SpotubeAudioSourceStreamObject(
        url: 'url_mp4',
        container: 'mp4',
        type: SpotubeMediaCompressionType.lossy,
        codec: 'aac',
        bitrate: 128000,
      );

      // When m4a requested: fallback order is mp4 -> webm -> opus
      // Test when only opus & webm present -> webm beats opus for m4a? Wait, fallback order is mp4, webm, opus
      final trackM4a = SourcedTrack(
        info: matchInfo,
        query: queryTrack,
        source: 'youtube',
        siblings: [],
        sources: [streamOpus, streamWebm],
      );
      expect(trackM4a.getStreamOfQuality(m4aPreset, 0)?.url, equals('url_webm'));

      // Test when only mp4 and webm present -> mp4 beats webm for m4a
      final trackM4aWithMp4 = SourcedTrack(
        info: matchInfo,
        query: queryTrack,
        source: 'youtube',
        siblings: [],
        sources: [streamWebm, streamMp4],
      );
      expect(trackM4aWithMp4.getStreamOfQuality(m4aPreset, 0)?.url, equals('url_mp4'));

      // When opus requested: fallback order is webm -> m4a -> mp4
      final trackOpus = SourcedTrack(
        info: matchInfo,
        query: queryTrack,
        source: 'youtube',
        siblings: [],
        sources: [streamMp4, streamWebm],
      );
      expect(trackOpus.getStreamOfQuality(opusPreset, 0)?.url, equals('url_webm'));
    });

    test('Adversarial 8: Fuzzing matrix (100 randomized source configurations)', () {
      final rng = Random(42);
      final containers = ['m4a', 'webm', 'opus', 'mp4', 'flac', 'wav', 'ogg', '3gp', 'unknown_ext'];
      final List<double?> bitrates = [null, 0.0, 48000.0, 64000.0, 96000.0, 128000.0, 160000.0, 192000.0, 256000.0, 320000.0];
      final presets = [m4aPreset, webmPreset, opusPreset, mp4Preset];

      for (int i = 0; i < 100; i++) {
        final count = rng.nextInt(15) + 1; // 1 to 15 sources
        final sources = List.generate(count, (idx) {
          final c = containers[rng.nextInt(containers.length)];
          final br = bitrates[rng.nextInt(bitrates.length)];
          return SpotubeAudioSourceStreamObject(
            url: 'https://test.stream/$i/$idx.$c',
            container: c,
            type: SpotubeMediaCompressionType.lossy,
            codec: 'test_codec',
            bitrate: br,
          );
        });

        final track = SourcedTrack(
          info: matchInfo,
          query: queryTrack,
          source: 'youtube',
          siblings: [],
          sources: sources,
        );

        final selectedPreset = presets[rng.nextInt(presets.length)];
        final randomQualityIdx = rng.nextInt(20) - 5; // range: -5 to +14

        // Invariant: MUST NEVER throw StateError, RangeError, NoSuchMethodError, etc.
        // and MUST ALWAYS return a non-null stream because sources is non-empty!
        final result = track.getStreamOfQuality(selectedPreset, randomQualityIdx);
        expect(result, isNotNull, reason: 'Failed iteration $i with count $count');
        expect(sources.contains(result), isTrue);
      }
    });
  });
}
