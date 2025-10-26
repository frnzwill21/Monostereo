import 'package:flutter_test/flutter_test.dart';
import 'package:spotube/models/metadata/metadata.dart';
import 'package:spotube/services/audio_player/audio_player.dart';
import 'package:spotube/services/sourced_track/sourced_track.dart';

void main() {
  group('SpotubeMedia Localhost Socket Binding', () {
    final fullTrack = SpotubeFullTrackObject(
      id: 'stream-track-123',
      name: 'Numb',
      externalUri: 'https://spotify.com/track/123',
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

    test('SpotubeMedia._host resolves to loopback 127.0.0.1', () {
      expect(SpotubeMedia.host, equals('127.0.0.1'));
    });

    test('SpotubeMedia constructs proxy URL targeting 127.0.0.1', () {
      SpotubeMedia.serverPort = 65432;
      final media = SpotubeMedia(fullTrack);

      expect(media.uri, equals('http://127.0.0.1:65432/stream/stream-track-123'));
    });

    test('SpotubeMedia reflects serverPort updates with 127.0.0.1 loopback', () {
      SpotubeMedia.serverPort = 43210;
      final media = SpotubeMedia(fullTrack);

      expect(media.uri, startsWith('http://127.0.0.1:43210/stream/'));
    });

    test('SpotubeMedia preserves local file path for local tracks without proxy URL', () {
      final localTrack = SpotubeLocalTrackObject(
        id: 'local-file-456',
        name: 'Local Song',
        externalUri: 'file:///music/song.mp3',
        path: '/storage/emulated/0/Music/song.mp3',
        durationMs: 200000,
        artists: [],
        album: SpotubeSimpleAlbumObject(
          id: 'local-album',
          name: 'Local Album',
          albumType: SpotubeAlbumType.album,
          externalUri: 'file:///music',
          artists: [],
        ),
      );

      final media = SpotubeMedia(localTrack);
      expect(media.uri, equals('/storage/emulated/0/Music/song.mp3'));
    });
  });

  group('SourcedTrack.getStreamOfQuality Container Fallback', () {
    final queryTrack = SpotubeFullTrackObject(
      id: 'query-1',
      name: 'In the End',
      externalUri: 'https://spotify.com/track/query-1',
      durationMs: 216000,
      isrc: 'USWB10000216',
      explicit: false,
      artists: [],
      album: SpotubeSimpleAlbumObject(
        id: 'album-query',
        name: 'Hybrid Theory',
        albumType: SpotubeAlbumType.album,
        externalUri: 'https://spotify.com/album/query',
        artists: [],
      ),
    );

    final matchInfo = SpotubeAudioSourceMatchObject(
      id: 'yt-match',
      title: 'In the End',
      artists: ['Linkin Park'],
      duration: const Duration(seconds: 216),
      externalUri: 'https://youtube.com/watch?v=yt-match',
    );

    final lossyM4aPreset = SpotubeAudioSourceContainerPreset.lossy(
      type: SpotubeMediaCompressionType.lossy,
      name: 'm4a',
      qualities: [
        SpotubeAudioLossyContainerQuality(bitrate: 128000),
        SpotubeAudioLossyContainerQuality(bitrate: 256000),
      ],
    );

    final lossyOpusPreset = SpotubeAudioSourceContainerPreset.lossy(
      type: SpotubeMediaCompressionType.lossy,
      name: 'opus',
      qualities: [
        SpotubeAudioLossyContainerQuality(bitrate: 128000),
        SpotubeAudioLossyContainerQuality(bitrate: 256000),
      ],
    );

    final lossyWebmPreset = SpotubeAudioSourceContainerPreset.lossy(
      type: SpotubeMediaCompressionType.lossy,
      name: 'webm',
      qualities: [
        SpotubeAudioLossyContainerQuality(bitrate: 128000),
        SpotubeAudioLossyContainerQuality(bitrate: 256000),
      ],
    );

    final lossyMp4Preset = SpotubeAudioSourceContainerPreset.lossy(
      type: SpotubeMediaCompressionType.lossy,
      name: 'mp4',
      qualities: [
        SpotubeAudioLossyContainerQuality(bitrate: 128000),
        SpotubeAudioLossyContainerQuality(bitrate: 256000),
      ],
    );

    final streamWebm128 = SpotubeAudioSourceStreamObject(
      url: 'https://googlevideo.com/stream/webm_128',
      container: 'webm',
      type: SpotubeMediaCompressionType.lossy,
      codec: 'opus',
      bitrate: 128000,
    );

    final streamWebm256 = SpotubeAudioSourceStreamObject(
      url: 'https://googlevideo.com/stream/webm_256',
      container: 'webm',
      type: SpotubeMediaCompressionType.lossy,
      codec: 'opus',
      bitrate: 256000,
    );

    final streamMp4128 = SpotubeAudioSourceStreamObject(
      url: 'https://googlevideo.com/stream/mp4_128',
      container: 'mp4',
      type: SpotubeMediaCompressionType.lossy,
      codec: 'aac',
      bitrate: 128000,
    );

    final streamM4a256 = SpotubeAudioSourceStreamObject(
      url: 'https://googlevideo.com/stream/m4a_256',
      container: 'm4a',
      type: SpotubeMediaCompressionType.lossy,
      codec: 'aac',
      bitrate: 256000,
    );

    final streamOpus160 = SpotubeAudioSourceStreamObject(
      url: 'https://googlevideo.com/stream/opus_160',
      container: 'opus',
      type: SpotubeMediaCompressionType.lossy,
      codec: 'opus',
      bitrate: 160000,
    );

    test('returns null when sources list is empty', () {
      final track = SourcedTrack(
        info: matchInfo,
        query: queryTrack,
        source: 'youtube',
        siblings: [],
        sources: [],
      );

      final stream = track.getStreamOfQuality(lossyM4aPreset, 0);
      expect(stream, isNull);
    });

    test('selects exact match when requested container and quality are available', () {
      final track = SourcedTrack(
        info: matchInfo,
        query: queryTrack,
        source: 'youtube',
        siblings: [],
        sources: [streamWebm128, streamM4a256],
      );

      final stream = track.getStreamOfQuality(lossyM4aPreset, 1);
      expect(stream, isNotNull);
      expect(stream!.container, equals('m4a'));
      expect(stream.bitrate, equals(256000));
      expect(stream.url, equals('https://googlevideo.com/stream/m4a_256'));
    });

    test('m4a preset falls back to mp4 when m4a is absent without StateError: No element', () {
      final track = SourcedTrack(
        info: matchInfo,
        query: queryTrack,
        source: 'youtube',
        siblings: [],
        sources: [streamWebm128, streamMp4128],
      );

      final stream = track.getStreamOfQuality(lossyM4aPreset, 0);
      expect(stream, isNotNull);
      expect(stream!.container, equals('mp4'));
      expect(stream.url, equals('https://googlevideo.com/stream/mp4_128'));
    });

    test('m4a preset falls back to webm when m4a and mp4 are absent without StateError: No element', () {
      final track = SourcedTrack(
        info: matchInfo,
        query: queryTrack,
        source: 'youtube',
        siblings: [],
        sources: [streamWebm128, streamWebm256],
      );

      final stream = track.getStreamOfQuality(lossyM4aPreset, 1);
      expect(stream, isNotNull);
      expect(stream!.container, equals('webm'));
      expect(stream.bitrate, equals(256000));
    });

    test('m4a preset falls back to opus when only opus source is present without StateError: No element', () {
      final track = SourcedTrack(
        info: matchInfo,
        query: queryTrack,
        source: 'youtube',
        siblings: [],
        sources: [streamOpus160],
      );

      final stream = track.getStreamOfQuality(lossyM4aPreset, 0);
      expect(stream, isNotNull);
      expect(stream!.container, equals('opus'));
      expect(stream.url, equals('https://googlevideo.com/stream/opus_160'));
    });

    test('opus preset falls back to webm when opus is absent without StateError: No element', () {
      final track = SourcedTrack(
        info: matchInfo,
        query: queryTrack,
        source: 'youtube',
        siblings: [],
        sources: [streamWebm128, streamWebm256],
      );

      final stream = track.getStreamOfQuality(lossyOpusPreset, 0);
      expect(stream, isNotNull);
      expect(stream!.container, equals('webm'));
      expect(stream.bitrate, equals(128000));
    });

    test('opus preset falls back to m4a or mp4 when webm is absent without StateError: No element', () {
      final track = SourcedTrack(
        info: matchInfo,
        query: queryTrack,
        source: 'youtube',
        siblings: [],
        sources: [streamMp4128],
      );

      final stream = track.getStreamOfQuality(lossyOpusPreset, 0);
      expect(stream, isNotNull);
      expect(stream!.container, equals('mp4'));
    });

    test('webm preset falls back to opus or mp4 without StateError: No element', () {
      final track = SourcedTrack(
        info: matchInfo,
        query: queryTrack,
        source: 'youtube',
        siblings: [],
        sources: [streamMp4128, streamOpus160],
      );

      final stream = track.getStreamOfQuality(lossyWebmPreset, 0);
      expect(stream, isNotNull);
      expect(stream!.container, equals('opus'));
    });

    test('mp4 preset falls back to webm when mp4 is absent without StateError: No element', () {
      final track = SourcedTrack(
        info: matchInfo,
        query: queryTrack,
        source: 'youtube',
        siblings: [],
        sources: [streamWebm128],
      );

      final stream = track.getStreamOfQuality(lossyMp4Preset, 0);
      expect(stream, isNotNull);
      expect(stream!.container, equals('webm'));
    });

    test('unknown container preset falls back across all available sources without StateError: No element', () {
      final unknownPreset = SpotubeAudioSourceContainerPreset.lossy(
        type: SpotubeMediaCompressionType.lossy,
        name: 'custom_audio_format',
        qualities: [
          SpotubeAudioLossyContainerQuality(bitrate: 320000),
        ],
      );

      final track = SourcedTrack(
        info: matchInfo,
        query: queryTrack,
        source: 'youtube',
        siblings: [],
        sources: [streamWebm256],
      );

      final stream = track.getStreamOfQuality(unknownPreset, 0);
      expect(stream, isNotNull);
      expect(stream!.container, equals('webm'));
      expect(stream.bitrate, equals(256000));
    });

    test('out-of-bounds qualityIndex falls back safely to first quality without RangeError', () {
      final track = SourcedTrack(
        info: matchInfo,
        query: queryTrack,
        source: 'youtube',
        siblings: [],
        sources: [streamWebm128, streamWebm256],
      );

      final streamHighIndex = track.getStreamOfQuality(lossyWebmPreset, 99);
      expect(streamHighIndex, isNotNull);

      final streamNegIndex = track.getStreamOfQuality(lossyWebmPreset, -1);
      expect(streamNegIndex, isNotNull);
    });

    test('lossless container preset safely evaluates sampleRate and bitDepth', () {
      final losslessPreset = SpotubeAudioSourceContainerPreset.lossless(
        type: SpotubeMediaCompressionType.lossless,
        name: 'flac',
        qualities: [
          SpotubeAudioLosslessContainerQuality(bitDepth: 16, sampleRate: 44100),
          SpotubeAudioLosslessContainerQuality(bitDepth: 24, sampleRate: 96000),
        ],
      );

      final losslessStream1 = SpotubeAudioSourceStreamObject(
        url: 'https://example.com/audio1.flac',
        container: 'flac',
        type: SpotubeMediaCompressionType.lossless,
        bitDepth: 16,
        sampleRate: 44100,
      );

      final losslessStream2 = SpotubeAudioSourceStreamObject(
        url: 'https://example.com/audio2.flac',
        container: 'flac',
        type: SpotubeMediaCompressionType.lossless,
        bitDepth: 24,
        sampleRate: 96000,
      );

      final track = SourcedTrack(
        info: matchInfo,
        query: queryTrack,
        source: 'youtube',
        siblings: [],
        sources: [losslessStream1, losslessStream2],
      );

      final stream = track.getStreamOfQuality(losslessPreset, 1);
      expect(stream, isNotNull);
      expect(stream!.bitDepth, equals(24));
      expect(stream.sampleRate, equals(96000));
    });
  });
}
