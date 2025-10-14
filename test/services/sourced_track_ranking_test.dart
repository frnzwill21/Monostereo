import 'package:flutter_test/flutter_test.dart';
import 'package:spotube/models/metadata/metadata.dart';
import 'package:spotube/services/sourced_track/sourced_track.dart';

void main() {
  group('SourcedTrack.rankResults', () {
    final targetTrack = SpotubeFullTrackObject(
      id: 'track-1',
      name: 'Numb',
      externalUri: 'https://spotify.com/track/1',
      durationMs: 187000, // 3:07
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

    test('ranks official exact match first over covers, loops, and remixes', () {
      final officialVideo = SpotubeAudioSourceMatchObject(
        id: 'yt-1',
        title: 'Linkin Park - Numb (Official Music Video)',
        artists: ['Linkin Park'],
        duration: const Duration(seconds: 187),
        externalUri: 'https://youtube.com/watch?v=yt-1',
      );

      final coverVersion = SpotubeAudioSourceMatchObject(
        id: 'yt-2',
        title: 'Numb - Linkin Park (Cover by Someone)',
        artists: ['Someone'],
        duration: const Duration(seconds: 185),
        externalUri: 'https://youtube.com/watch?v=yt-2',
      );

      final hourLoop = SpotubeAudioSourceMatchObject(
        id: 'yt-3',
        title: 'Linkin Park - Numb 1 Hour Loop',
        artists: ['LoopMaster'],
        duration: const Duration(hours: 1),
        externalUri: 'https://youtube.com/watch?v=yt-3',
      );

      final karaokeVersion = SpotubeAudioSourceMatchObject(
        id: 'yt-4',
        title: 'Linkin Park - Numb (Karaoke / Instrumental)',
        artists: ['KaraokeChannel'],
        duration: const Duration(seconds: 187),
        externalUri: 'https://youtube.com/watch?v=yt-4',
      );

      final slowedVersion = SpotubeAudioSourceMatchObject(
        id: 'yt-5',
        title: 'Linkin Park - Numb (Slowed + Reverb)',
        artists: ['SlowVibes'],
        duration: const Duration(seconds: 220),
        externalUri: 'https://youtube.com/watch?v=yt-5',
      );

      final ranked = SourcedTrack.rankResults(
        [
          coverVersion,
          hourLoop,
          officialVideo,
          slowedVersion,
          karaokeVersion,
        ],
        targetTrack,
      );

      expect(ranked.first.id, equals('yt-1'));
      expect(ranked.last.id, equals('yt-3'));
    });

    test('duration proximity significantly affects scoring', () {
      final closeDuration = SpotubeAudioSourceMatchObject(
        id: 'close',
        title: 'Numb',
        artists: ['Linkin Park'],
        duration: const Duration(seconds: 188),
        externalUri: 'https://youtube.com/watch?v=close',
      );

      final farDuration = SpotubeAudioSourceMatchObject(
        id: 'far',
        title: 'Numb',
        artists: ['Linkin Park'],
        duration: const Duration(seconds: 350),
        externalUri: 'https://youtube.com/watch?v=far',
      );

      final ranked = SourcedTrack.rankResults([farDuration, closeDuration], targetTrack);
      expect(ranked.first.id, equals('close'));
    });

    test('prefers YouTube Music Topic channel and penalizes live concerts and reactions', () {
      final topicTrack = SpotubeAudioSourceMatchObject(
        id: 'topic',
        title: 'Numb',
        artists: ['Linkin Park - Topic'],
        duration: const Duration(seconds: 187),
        externalUri: 'https://youtube.com/watch?v=topic',
      );

      final liveConcert = SpotubeAudioSourceMatchObject(
        id: 'live',
        title: 'Linkin Park - Numb (Live in Texas 2003)',
        artists: ['Linkin Park'],
        duration: const Duration(seconds: 195),
        externalUri: 'https://youtube.com/watch?v=live',
      );

      final reactionVideo = SpotubeAudioSourceMatchObject(
        id: 'reaction',
        title: 'Vocal Coach Reacts to Linkin Park - Numb',
        artists: ['VocalCoach'],
        duration: const Duration(seconds: 190),
        externalUri: 'https://youtube.com/watch?v=reaction',
      );

      final ranked = SourcedTrack.rankResults([liveConcert, reactionVideo, topicTrack], targetTrack);
      expect(ranked.first.id, equals('topic'));
      expect(ranked.last.id, equals('reaction'));
    });

    test('VEVO channel matching with multi-word artist (Billie Eilish matches BillieEilishVEVO)', () {
      final billieTrack = SpotubeFullTrackObject(
        id: 'billie-1',
        name: 'bad guy',
        externalUri: 'https://spotify.com/track/billie1',
        durationMs: 194000, // 3:14
        isrc: 'USUM71900764',
        explicit: false,
        artists: [
          SpotubeSimpleArtistObject(
            id: 'artist-billie',
            name: 'Billie Eilish',
            externalUri: 'https://spotify.com/artist/billie',
          ),
        ],
        album: SpotubeSimpleAlbumObject(
          id: 'album-billie',
          name: 'WHEN WE ALL FALL ASLEEP, WHERE DO WE GO?',
          albumType: SpotubeAlbumType.album,
          externalUri: 'https://spotify.com/album/billie',
          artists: [],
        ),
      );

      final vevoTrack = SpotubeAudioSourceMatchObject(
        id: 'vevo',
        title: 'Billie Eilish - bad guy',
        artists: ['BillieEilishVEVO'],
        duration: const Duration(seconds: 194),
        externalUri: 'https://youtube.com/watch?v=vevo',
      );

      final fanAudio = SpotubeAudioSourceMatchObject(
        id: 'fan-audio',
        title: 'Billie Eilish - bad guy (Audio)',
        artists: ['RandomFanMusic'],
        duration: const Duration(seconds: 194),
        externalUri: 'https://youtube.com/watch?v=fan-audio',
      );

      final fanCover = SpotubeAudioSourceMatchObject(
        id: 'fan-cover',
        title: 'bad guy - Billie Eilish Cover',
        artists: ['AcousticVibes'],
        duration: const Duration(seconds: 194),
        externalUri: 'https://youtube.com/watch?v=fan-cover',
      );

      final ranked = SourcedTrack.rankResults(
        [fanCover, fanAudio, vevoTrack],
        billieTrack,
      );

      expect(ranked.first.id, equals('vevo'));
      expect(ranked.last.id, equals('fan-cover'));
    });

    test('Topic channel priority over fan lyric video (Linkin Park - Topic beats FanLyrics)', () {
      final inTheEndTrack = SpotubeFullTrackObject(
        id: 'ite-1',
        name: 'In the End',
        externalUri: 'https://spotify.com/track/ite1',
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
          id: 'album-hybrid',
          name: 'Hybrid Theory',
          albumType: SpotubeAlbumType.album,
          externalUri: 'https://spotify.com/album/hybrid',
          artists: [],
        ),
      );

      final topicTrack = SpotubeAudioSourceMatchObject(
        id: 'topic',
        title: 'In the End',
        artists: ['Linkin Park - Topic'],
        duration: const Duration(seconds: 216),
        externalUri: 'https://youtube.com/watch?v=topic',
      );

      final fanLyricVideo = SpotubeAudioSourceMatchObject(
        id: 'fan-lyrics',
        title: 'Linkin Park - In the End (Official Lyric Video)',
        artists: ['FanLyricsHD'],
        duration: const Duration(seconds: 216),
        externalUri: 'https://youtube.com/watch?v=fan-lyrics',
      );

      final genericUpload = SpotubeAudioSourceMatchObject(
        id: 'generic',
        title: 'Linkin Park - In the End',
        artists: ['RockUploader'],
        duration: const Duration(seconds: 216),
        externalUri: 'https://youtube.com/watch?v=generic',
      );

      final ranked = SourcedTrack.rankResults(
        [fanLyricVideo, genericUpload, topicTrack],
        inTheEndTrack,
      );

      expect(ranked.first.id, equals('topic'));
    });

    test('remastered title clean extraction (In the End - 2020 Remaster correctly matches In the End)', () {
      final remasteredTrack = SpotubeFullTrackObject(
        id: 'ite-remaster',
        name: 'In the End - 2020 Remaster',
        externalUri: 'https://spotify.com/track/ite-remaster',
        durationMs: 216000,
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
          id: 'album-hybrid-20',
          name: 'Hybrid Theory (20th Anniversary Edition)',
          albumType: SpotubeAlbumType.album,
          externalUri: 'https://spotify.com/album/hybrid20',
          artists: [],
        ),
      );

      final topicTrack = SpotubeAudioSourceMatchObject(
        id: 'topic',
        title: 'In the End',
        artists: ['Linkin Park - Topic'],
        duration: const Duration(seconds: 216),
        externalUri: 'https://youtube.com/watch?v=topic',
      );

      final fanCover = SpotubeAudioSourceMatchObject(
        id: 'cover',
        title: 'In the End - 2020 Remaster (Guitar Cover)',
        artists: ['GuitarHero'],
        duration: const Duration(seconds: 216),
        externalUri: 'https://youtube.com/watch?v=cover',
      );

      final reactionVideo = SpotubeAudioSourceMatchObject(
        id: 'reaction',
        title: 'First Time Hearing Linkin Park - In the End 2020 Remaster',
        artists: ['MusicReactor'],
        duration: const Duration(seconds: 216),
        externalUri: 'https://youtube.com/watch?v=reaction',
      );

      final ranked = SourcedTrack.rankResults(
        [fanCover, reactionVideo, topicTrack],
        remasteredTrack,
      );

      expect(ranked.first.id, equals('topic'));
      expect(ranked.last.id, equals('reaction'));
    });

    test('live recording suppression for studio tracks (Queen - Topic beats Live Aid 1985)', () {
      final studioQueenTrack = SpotubeFullTrackObject(
        id: 'queen-1',
        name: 'Bohemian Rhapsody',
        externalUri: 'https://spotify.com/track/queen1',
        durationMs: 354000, // 5:54
        isrc: 'GBUM71029606',
        explicit: false,
        artists: [
          SpotubeSimpleArtistObject(
            id: 'artist-queen',
            name: 'Queen',
            externalUri: 'https://spotify.com/artist/queen',
          ),
        ],
        album: SpotubeSimpleAlbumObject(
          id: 'album-queen',
          name: 'A Night at the Opera',
          albumType: SpotubeAlbumType.album,
          externalUri: 'https://spotify.com/album/queen',
          artists: [],
        ),
      );

      final topicTrack = SpotubeAudioSourceMatchObject(
        id: 'topic',
        title: 'Bohemian Rhapsody',
        artists: ['Queen - Topic'],
        duration: const Duration(seconds: 354),
        externalUri: 'https://youtube.com/watch?v=topic',
      );

      final liveAidConcert = SpotubeAudioSourceMatchObject(
        id: 'live-aid',
        title: 'Queen - Bohemian Rhapsody (Live Aid 1985)',
        artists: ['Queen'],
        duration: const Duration(seconds: 360),
        externalUri: 'https://youtube.com/watch?v=live-aid',
      );

      final liveWembley = SpotubeAudioSourceMatchObject(
        id: 'live-wembley',
        title: 'Queen - Bohemian Rhapsody (Live at Wembley Stadium)',
        artists: ['Queen Official'],
        duration: const Duration(seconds: 375),
        externalUri: 'https://youtube.com/watch?v=live-wembley',
      );

      final ranked = SourcedTrack.rankResults(
        [liveAidConcert, liveWembley, topicTrack],
        studioQueenTrack,
      );

      expect(ranked.first.id, equals('topic'));
      expect(ranked, contains(liveAidConcert));
      expect(ranked, contains(liveWembley));
    });

    test('live album intent preservation (MTV Unplugged in New York boosts live version)', () {
      final liveAlbumTrack = SpotubeFullTrackObject(
        id: 'nirvana-1',
        name: 'About a Girl',
        externalUri: 'https://spotify.com/track/nirvana1',
        durationMs: 217000, // 3:37 live
        isrc: 'USGF19448001',
        explicit: false,
        artists: [
          SpotubeSimpleArtistObject(
            id: 'artist-nirvana',
            name: 'Nirvana',
            externalUri: 'https://spotify.com/artist/nirvana',
          ),
        ],
        album: SpotubeSimpleAlbumObject(
          id: 'album-unplugged',
          name: 'MTV Unplugged in New York',
          albumType: SpotubeAlbumType.album,
          externalUri: 'https://spotify.com/album/unplugged',
          artists: [],
        ),
      );

      final liveUnplugged = SpotubeAudioSourceMatchObject(
        id: 'live-unplugged',
        title: 'Nirvana - About a Girl (Live / MTV Unplugged)',
        artists: ['Nirvana - Topic'],
        duration: const Duration(seconds: 217),
        externalUri: 'https://youtube.com/watch?v=live-unplugged',
      );

      final studioBleach = SpotubeAudioSourceMatchObject(
        id: 'studio-bleach',
        title: 'Nirvana - About a Girl',
        artists: ['Nirvana - Topic'],
        duration: const Duration(seconds: 168), // 2:48
        externalUri: 'https://youtube.com/watch?v=studio-bleach',
      );

      final ranked = SourcedTrack.rankResults(
        [studioBleach, liveUnplugged],
        liveAlbumTrack,
      );

      expect(ranked.first.id, equals('live-unplugged'));
    });

    test('reaction video suppression (First Time Hearing Numb ranked dead last with negative score)', () {
      final reactionVideo = SpotubeAudioSourceMatchObject(
        id: 'reaction',
        title: 'First Time Hearing Linkin Park - Numb (Mind Blown!)',
        artists: ['ReactionKing'],
        duration: const Duration(seconds: 187),
        externalUri: 'https://youtube.com/watch?v=reaction',
      );

      final vocalCoachReview = SpotubeAudioSourceMatchObject(
        id: 'vocal-coach',
        title: 'Vocal Coach Analysis of Linkin Park - Numb',
        artists: ['CoachVocal'],
        duration: const Duration(seconds: 187),
        externalUri: 'https://youtube.com/watch?v=coach',
      );

      final officialVideo = SpotubeAudioSourceMatchObject(
        id: 'official-video',
        title: 'Linkin Park - Numb (Official Music Video)',
        artists: ['Linkin Park'],
        duration: const Duration(seconds: 187),
        externalUri: 'https://youtube.com/watch?v=official',
      );

      final topicTrack = SpotubeAudioSourceMatchObject(
        id: 'topic',
        title: 'Numb',
        artists: ['Linkin Park - Topic'],
        duration: const Duration(seconds: 187),
        externalUri: 'https://youtube.com/watch?v=topic',
      );

      final ranked = SourcedTrack.rankResults(
        [reactionVideo, vocalCoachReview, officialVideo, topicTrack],
        targetTrack,
      );

      expect(ranked.first.id, equals('topic'));
      expect(ranked.contains(reactionVideo), isTrue);
      expect(ranked.indexOf(reactionVideo), greaterThanOrEqualTo(2));
      expect(ranked.indexOf(vocalCoachReview), greaterThanOrEqualTo(2));
    });

    test('officialAudioRegex matches (Audio) and [Audio] surrounded by spaces', () {
      expect(officialAudioRegex.hasMatch('Song (Audio)'), isTrue);
      expect(officialAudioRegex.hasMatch('Song [Audio]'), isTrue);
      expect(officialAudioRegex.hasMatch('Song (Official Audio)'), isTrue);
      expect(officialAudioRegex.hasMatch('Song [Official Audio]'), isTrue);
    });

    test('studio track named Alive does not trigger isTargetLive and suppresses concert bootleg', () {
      final aliveTrack = SpotubeFullTrackObject(
        id: 'alive-1',
        name: 'Alive',
        externalUri: 'https://spotify.com/track/alive1',
        durationMs: 340000,
        isrc: 'USSM19100001',
        explicit: false,
        artists: [
          SpotubeSimpleArtistObject(
            id: 'artist-pj',
            name: 'Pearl Jam',
            externalUri: 'https://spotify.com/artist/pj',
          ),
        ],
        album: SpotubeSimpleAlbumObject(
          id: 'album-ten',
          name: 'Ten',
          albumType: SpotubeAlbumType.album,
          externalUri: 'https://spotify.com/album/ten',
          artists: [],
        ),
      );

      final studioVideo = SpotubeAudioSourceMatchObject(
        id: 'pj-studio',
        title: 'Pearl Jam - Alive (Official Video)',
        artists: ['Pearl Jam'],
        duration: const Duration(seconds: 340),
        externalUri: 'https://youtube.com/watch?v=pj-studio',
      );

      final liveBootleg = SpotubeAudioSourceMatchObject(
        id: 'pj-live',
        title: 'Pearl Jam - Alive (Live at Pinkpop 1992)',
        artists: ['Pearl Jam'],
        duration: const Duration(seconds: 340),
        externalUri: 'https://youtube.com/watch?v=pj-live',
      );

      final ranked = SourcedTrack.rankResults([liveBootleg, studioVideo], aliveTrack);
      expect(ranked.first.id, equals('pj-studio'));
      expect(ranked.last.id, equals('pj-live'));
    });

    test('band named Live is exempt from live penalty on official uploads', () {
      final bandLiveTrack = SpotubeFullTrackObject(
        id: 'live-band-1',
        name: 'Lightning Crashes',
        externalUri: 'https://spotify.com/track/lc1',
        durationMs: 325000,
        isrc: 'USMC19400001',
        explicit: false,
        artists: [
          SpotubeSimpleArtistObject(
            id: 'artist-live-band',
            name: 'Live',
            externalUri: 'https://spotify.com/artist/live',
          ),
        ],
        album: SpotubeSimpleAlbumObject(
          id: 'album-throwing-copper',
          name: 'Throwing Copper',
          albumType: SpotubeAlbumType.album,
          externalUri: 'https://spotify.com/album/tc',
          artists: [],
        ),
      );

      final officialBandVideo = SpotubeAudioSourceMatchObject(
        id: 'band-live-official',
        title: 'Live - Lightning Crashes (Official Music Video)',
        artists: ['LiveVEVO'],
        duration: const Duration(seconds: 325),
        externalUri: 'https://youtube.com/watch?v=blo',
      );

      final fanUpload = SpotubeAudioSourceMatchObject(
        id: 'fan-audio-only',
        title: 'Lightning Crashes (Audio Only)',
        artists: ['RandomGuy'],
        duration: const Duration(seconds: 325),
        externalUri: 'https://youtube.com/watch?v=fan',
      );

      final ranked = SourcedTrack.rankResults([fanUpload, officialBandVideo], bandLiveTrack);
      expect(ranked.first.id, equals('band-live-official'));
    });

    test('songs titled Breakdown or Chain Reaction are not penalized by reactionRegex', () {
      final breakdownTrack = SpotubeFullTrackObject(
        id: 'tp-breakdown',
        name: 'Breakdown',
        externalUri: 'https://spotify.com/track/breakdown',
        durationMs: 164000,
        isrc: 'USMC17600001',
        explicit: false,
        artists: [
          SpotubeSimpleArtistObject(
            id: 'artist-tp',
            name: 'Tom Petty and the Heartbreakers',
            externalUri: 'https://spotify.com/artist/tp',
          ),
        ],
        album: SpotubeSimpleAlbumObject(
          id: 'album-tp',
          name: 'Tom Petty and the Heartbreakers',
          albumType: SpotubeAlbumType.album,
          externalUri: 'https://spotify.com/album/tp',
          artists: [],
        ),
      );

      final officialBreakdown = SpotubeAudioSourceMatchObject(
        id: 'tp-official',
        title: 'Tom Petty and the Heartbreakers - Breakdown (Official Audio)',
        artists: ['Tom Petty and the Heartbreakers - Topic'],
        duration: const Duration(seconds: 164),
        externalUri: 'https://youtube.com/watch?v=tp-breakdown',
      );

      final unofficialOther = SpotubeAudioSourceMatchObject(
        id: 'other-song',
        title: 'Some Other Upload',
        artists: ['Other'],
        duration: const Duration(seconds: 164),
        externalUri: 'https://youtube.com/watch?v=other',
      );

      final ranked = SourcedTrack.rankResults([unofficialOther, officialBreakdown], breakdownTrack);
      expect(ranked.first.id, equals('tp-official'));
    });
  });
}
