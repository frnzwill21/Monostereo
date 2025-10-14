import 'package:flutter_test/flutter_test.dart';
import 'package:spotube/models/metadata/metadata.dart';
import 'package:spotube/services/sourced_track/sourced_track.dart';

void main() {
  group('Adversarial Stress-Testing: SourcedTrack.rankResults', () {
    // -------------------------------------------------------------
    // Test Category 1: Non-Latin characters & Empty artistNorm Bug
    // -------------------------------------------------------------
    test('Non-Latin artist (아이유) causes empty artistNorm which falsely awards VEVO/Topic boosts to unrelated artists', () {
      final iuTrack = SpotubeFullTrackObject(
        id: 'iu-1',
        name: 'Good Day',
        externalUri: 'https://spotify.com/track/iu1',
        durationMs: 233000, // 3:53
        isrc: 'KMA011000001',
        explicit: false,
        artists: [
          SpotubeSimpleArtistObject(
            id: 'artist-iu',
            name: '아이유',
            externalUri: 'https://spotify.com/artist/iu',
          ),
        ],
        album: SpotubeSimpleAlbumObject(
          id: 'album-real',
          name: 'Real',
          albumType: SpotubeAlbumType.album,
          externalUri: 'https://spotify.com/album/real',
          artists: [],
        ),
      );

      // Unrelated Western VEVO track with identical duration
      final unrelatedVevo = SpotubeAudioSourceMatchObject(
        id: 'taylor-vevo',
        title: 'Taylor Swift - Shake It Off',
        artists: ['TaylorSwiftVEVO'],
        duration: const Duration(seconds: 233),
        externalUri: 'https://youtube.com/watch?v=taylor',
      );

      // Unrelated Topic channel track
      final unrelatedTopic = SpotubeAudioSourceMatchObject(
        id: 'random-topic',
        title: 'Random Western Band - Song',
        artists: ['Random Western Band - Topic'],
        duration: const Duration(seconds: 233),
        externalUri: 'https://youtube.com/watch?v=random',
      );

      // Authentic Korean upload from official distributor (1theK)
      final authenticRelease = SpotubeAudioSourceMatchObject(
        id: 'iu-official',
        title: '아이유 - Good Day',
        artists: ['1theK (원더케이)'],
        duration: const Duration(seconds: 233),
        externalUri: 'https://youtube.com/watch?v=iu',
      );

      final ranked = SourcedTrack.rankResults(
        [unrelatedVevo, unrelatedTopic, authenticRelease],
        iuTrack,
      );

      print('Ranked IDs for IU track: ${ranked.map((e) => e.id).toList()}');
      // EMPIRICAL VERIFICATION:
      // Does authenticRelease win? Or do unrelated VEVO/Topic steal rank #1?
      expect(ranked.first.id, equals('iu-official'),
          reason: 'BUG: Empty artistNorm caused unrelated Topic/VEVO channel to beat the authentic release!');
    });

    // -------------------------------------------------------------
    // Test Category 2: Accented Latin Characters (Motörhead, Björk, etc.)
    // -------------------------------------------------------------
    test('Accented Latin artist (Motörhead) strips vowels and fails VEVO and Topic matching', () {
      final motorheadTrack = SpotubeFullTrackObject(
        id: 'motorhead-1',
        name: 'Ace of Spades',
        externalUri: 'https://spotify.com/track/motorhead1',
        durationMs: 168000, // 2:48
        isrc: 'GBAYE8000001',
        explicit: false,
        artists: [
          SpotubeSimpleArtistObject(
            id: 'artist-motorhead',
            name: 'Motörhead',
            externalUri: 'https://spotify.com/artist/motorhead',
          ),
        ],
        album: SpotubeSimpleAlbumObject(
          id: 'album-ace',
          name: 'Ace of Spades',
          albumType: SpotubeAlbumType.album,
          externalUri: 'https://spotify.com/album/ace',
          artists: [],
        ),
      );

      // Official Topic channel uses standard Latin 'Motorhead - Topic'
      final officialTopic = SpotubeAudioSourceMatchObject(
        id: 'official-topic',
        title: 'Ace of Spades',
        artists: ['Motorhead - Topic'],
        duration: const Duration(seconds: 168),
        externalUri: 'https://youtube.com/watch?v=official-topic',
      );

      // Fan upload that keeps the umlaut 'Motörhead' in the title and adds 'Official Audio'
      final fanUpload = SpotubeAudioSourceMatchObject(
        id: 'fan-upload',
        title: 'Motörhead - Ace of Spades (Official Audio)',
        artists: ['ClassicRockFan'],
        duration: const Duration(seconds: 168),
        externalUri: 'https://youtube.com/watch?v=fan-upload',
      );

      final ranked = SourcedTrack.rankResults(
        [officialTopic, fanUpload],
        motorheadTrack,
      );

      print('Ranked IDs for Motörhead track: ${ranked.map((e) => e.id).toList()}');
      // EMPIRICAL VERIFICATION:
      // Official Topic channel MUST beat the fan upload
      expect(ranked.first.id, equals('official-topic'),
          reason: 'BUG: Motörhead stripping ö into mtrhead failed to match Motorhead - Topic!');
    });

    // -------------------------------------------------------------
    // Test Category 3: Can SEO reaction video beat official release?
    // -------------------------------------------------------------
    test('SEO Reaction video vs Official release with video intro', () {
      final targetTrack = SpotubeFullTrackObject(
        id: 'lp-numb',
        name: 'Numb',
        externalUri: 'https://spotify.com/track/numb',
        durationMs: 187000, // 3:07
        isrc: 'USWB10300185',
        explicit: false,
        artists: [
          SpotubeSimpleArtistObject(
            id: 'artist-lp',
            name: 'Linkin Park',
            externalUri: 'https://spotify.com/artist/lp',
          ),
        ],
        album: SpotubeSimpleAlbumObject(
          id: 'album-meteora',
          name: 'Meteora',
          albumType: SpotubeAlbumType.album,
          externalUri: 'https://spotify.com/album/meteora',
          artists: [],
        ),
      );

      // Official music video with narrative intro extending duration (+185s, diff > 180s => -45 penalty)
      final officialMusicVideoLong = SpotubeAudioSourceMatchObject(
        id: 'official-mv-long',
        title: 'Linkin Park - Numb (Official Music Video)',
        artists: ['Linkin Park'],
        duration: const Duration(seconds: 375), // 6:15
        externalUri: 'https://youtube.com/watch?v=mv-long',
      );

      // Official release on Topic channel
      final officialTopic = SpotubeAudioSourceMatchObject(
        id: 'official-topic',
        title: 'Numb',
        artists: ['Linkin Park - Topic'],
        duration: const Duration(seconds: 187),
        externalUri: 'https://youtube.com/watch?v=topic',
      );

      // SEO Reaction video on channel named "Linkin Park - Topic" or impersonator
      final seoReaction = SpotubeAudioSourceMatchObject(
        id: 'seo-reaction',
        title: 'Linkin Park - Numb (Official Audio) [Audio] Reaction',
        artists: ['Linkin Park - Topic'],
        duration: const Duration(seconds: 187),
        externalUri: 'https://youtube.com/watch?v=seo-reaction',
      );

      final ranked = SourcedTrack.rankResults(
        [officialMusicVideoLong, officialTopic, seoReaction],
        targetTrack,
      );

      print('Ranked IDs: ${ranked.map((e) => e.id).toList()}');
      expect(ranked.first.id, equals('official-topic'));
      expect(ranked.last.id, equals('seo-reaction'),
          reason: 'Reaction video should be ranked last');
    });

    test('Can SEO Reaction video bypass reactionRegex with alternative phrasing?', () {
      final targetTrack = SpotubeFullTrackObject(
        id: 'lp-numb',
        name: 'Numb',
        externalUri: 'https://spotify.com/track/numb',
        durationMs: 187000,
        isrc: 'USWB10300185',
        explicit: false,
        artists: [
          SpotubeSimpleArtistObject(
            id: 'artist-lp',
            name: 'Linkin Park',
            externalUri: 'https://spotify.com/artist/lp',
          ),
        ],
        album: SpotubeSimpleAlbumObject(
          id: 'album-meteora',
          name: 'Meteora',
          albumType: SpotubeAlbumType.album,
          externalUri: 'https://spotify.com/album/meteora',
          artists: [],
        ),
      );

      // Reaction video phrased without matching reactionRegex words:
      // "Listening to Linkin Park - Numb FOR THE FIRST TIME"
      final sneakyReaction = SpotubeAudioSourceMatchObject(
        id: 'sneaky-reaction',
        title: 'Listening to Linkin Park - Numb FOR THE FIRST TIME (Mind Blown)',
        artists: ['MusicLoverGuy'],
        duration: const Duration(seconds: 187),
        externalUri: 'https://youtube.com/watch?v=sneaky',
      );

      // Unofficial clean audio without artist in channel
      final cleanAudio = SpotubeAudioSourceMatchObject(
        id: 'clean-audio',
        title: 'Numb',
        artists: ['SomeUploader'],
        duration: const Duration(seconds: 187),
        externalUri: 'https://youtube.com/watch?v=clean',
      );

      final ranked = SourcedTrack.rankResults(
        [cleanAudio, sneakyReaction],
        targetTrack,
      );

      print('Sneaky reaction test ranking: ${ranked.map((e) => e.id).toList()}');
      // Sneaky reaction has Linkin Park in title (+4), Numb in title (+10) = 29
      // Clean audio only has Numb in title (+10) = 25
      // Sneaky reaction wins because it bypasses reactionRegex!
      expect(ranked.first.id, equals('clean-audio'),
          reason: 'Sneaky reaction bypassed reactionRegex and beat clean audio!');
    });

    // -------------------------------------------------------------
    // Test Category 4: Extreme Duration Anomalies (> 300s & durationMs = 0)
    // -------------------------------------------------------------
    test('Extreme duration difference (>300 seconds) vs missing track duration', () {
      // Case A: track has duration
      final normalTrack = SpotubeFullTrackObject(
        id: 'normal',
        name: 'In the End',
        externalUri: 'https://spotify.com/track/ite',
        durationMs: 216000, // 3:36
        isrc: 'USWB10000350',
        explicit: false,
        artists: [
          SpotubeSimpleArtistObject(
            id: 'artist-lp',
            name: 'Linkin Park',
            externalUri: 'https://spotify.com/artist/lp',
          ),
        ],
        album: SpotubeSimpleAlbumObject(
          id: 'album-ht',
          name: 'Hybrid Theory',
          albumType: SpotubeAlbumType.album,
          externalUri: 'https://spotify.com/album/ht',
          artists: [],
        ),
      );

      final tenHourVideo = SpotubeAudioSourceMatchObject(
        id: '10-hour',
        title: 'Linkin Park - In the End',
        artists: ['Linkin Park - Topic'],
        duration: const Duration(hours: 10),
        externalUri: 'https://youtube.com/watch?v=10h',
      );

      final standardVideo = SpotubeAudioSourceMatchObject(
        id: 'standard',
        title: 'In the End',
        artists: ['Linkin Park - Topic'],
        duration: const Duration(seconds: 216),
        externalUri: 'https://youtube.com/watch?v=std',
      );

      final rankedNormal = SourcedTrack.rankResults([tenHourVideo, standardVideo], normalTrack);
      expect(rankedNormal.first.id, equals('standard'));
      expect(rankedNormal.last.id, equals('10-hour'));

      // Case B: track durationMs is 0 (missing metadata)
      final zeroDurationTrack = SpotubeFullTrackObject(
        id: 'zero-dur',
        name: 'In the End',
        externalUri: 'https://spotify.com/track/ite',
        durationMs: 0, // Missing or unknown
        isrc: 'USWB10000350',
        explicit: false,
        artists: [
          SpotubeSimpleArtistObject(
            id: 'artist-lp',
            name: 'Linkin Park',
            externalUri: 'https://spotify.com/artist/lp',
          ),
        ],
        album: SpotubeSimpleAlbumObject(
          id: 'album-ht',
          name: 'Hybrid Theory',
          albumType: SpotubeAlbumType.album,
          externalUri: 'https://spotify.com/album/ht',
          artists: [],
        ),
      );

      final compilationVideo = SpotubeAudioSourceMatchObject(
        id: 'full-album',
        title: 'Linkin Park - In the End Full Album Discography',
        artists: ['Linkin Park'],
        duration: const Duration(hours: 3),
        externalUri: 'https://youtube.com/watch?v=comp',
      );

      final shortSingle = SpotubeAudioSourceMatchObject(
        id: 'short-single',
        title: 'In the End',
        artists: ['Linkin Park'],
        duration: const Duration(seconds: 216),
        externalUri: 'https://youtube.com/watch?v=single',
      );

      final rankedZero = SourcedTrack.rankResults([compilationVideo, shortSingle], zeroDurationTrack);
      print('Ranked for zero duration track: ${rankedZero.map((e) => e.id).toList()}');
      // Notice: compilationVideo has 'Linkin Park' in title (+4), shortSingle does not!
      // When durationMs == 0, duration check is bypassed, so 3-hour compilation beats single!
      expect(rankedZero.first.id, equals('short-single'),
          reason: 'When durationMs == 0, 3-hour video beat short single because duration check is skipped!');
    });
  });
}
