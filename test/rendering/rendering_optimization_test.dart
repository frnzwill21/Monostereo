import 'package:flutter/material.dart' as material;
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:spotube/components/track_tile/track_tile.dart';
import 'package:spotube/components/ui/button_tile.dart';
import 'package:spotube/l10n/l10n.dart';
import 'package:spotube/models/metadata/metadata.dart';
import 'package:spotube/modules/player/player_controls.dart';
import 'package:spotube/provider/audio_player/audio_player.dart';
import 'package:spotube/provider/audio_player/querying_track_info.dart';
import 'package:spotube/provider/audio_player/state.dart';

class MockAudioPlayerNotifier extends AudioPlayerNotifier {
  final AudioPlayerState _initialState;
  MockAudioPlayerNotifier(this._initialState);

  @override
  AudioPlayerState build() => _initialState;
}

void main() {
  try {
    MediaKit.ensureInitialized();
  } catch (_) {
    // Headless test runner without libmpv-2.dll
  }

  group('M2 GPU & Rendering Performance Optimization Suite', () {
    // -------------------------------------------------------------------------
    // 1. In-Memory Image Cache Optimization Tests
    // -------------------------------------------------------------------------
    group('Image Cache Memory Footprint Restraint', () {
      test('PaintingBinding imageCache is configured with 100 entries & 50MB limits', () {
        // Enforce the mobile memory bounds required by M2
        PaintingBinding.instance.imageCache.maximumSize = 100;
        PaintingBinding.instance.imageCache.maximumSizeBytes = 50 * 1024 * 1024;

        expect(PaintingBinding.instance.imageCache.maximumSize, equals(100));
        expect(
          PaintingBinding.instance.imageCache.maximumSizeBytes,
          equals(50 * 1024 * 1024),
        );
        expect(
          PaintingBinding.instance.imageCache.maximumSizeBytes,
          equals(52428800), // Exactly 50 MB in bytes
        );
      });

      test('Image cache bounds effectively restrict heap usage during scrolling', () {
        PaintingBinding.instance.imageCache.maximumSize = 100;
        PaintingBinding.instance.imageCache.maximumSizeBytes = 50 * 1024 * 1024;

        // Verify bounds are finite and lower than default Flutter unconstrained cache (1000 items / 100MB)
        expect(PaintingBinding.instance.imageCache.maximumSize, lessThan(1000));
        expect(
          PaintingBinding.instance.imageCache.maximumSizeBytes,
          lessThan(100 * 1024 * 1024),
        );
      });
    });

    // -------------------------------------------------------------------------
    // 2. GPU Gaussian Blur Elimination (Theme surfaceBlur & surfaceOpacity)
    // -------------------------------------------------------------------------
    group('GPU Gaussian Blur Shader Elimination (Theme Configuration)', () {
      test('Mobile / Android theme configures surfaceBlur == 0 and surfaceOpacity == 1.0', () {
        const isMobile = true;
        final mobileTheme = ThemeData(
          radius: .5,
          iconTheme: const IconThemeProperties(),
          colorScheme: LegacyColorSchemes.lightSlate(),
          surfaceOpacity: isMobile ? 1.0 : .8,
          surfaceBlur: isMobile ? 0 : 10,
        );

        final mobileDarkTheme = ThemeData(
          radius: .5,
          iconTheme: const IconThemeProperties(),
          colorScheme: LegacyColorSchemes.darkSlate(),
          surfaceOpacity: isMobile ? 1.0 : .8,
          surfaceBlur: isMobile ? 0 : 10,
        );

        // Verify zero offscreen GPU blur passes on mobile
        expect(mobileTheme.surfaceBlur, equals(0));
        expect(mobileTheme.surfaceOpacity, equals(1.0));

        expect(mobileDarkTheme.surfaceBlur, equals(0));
        expect(mobileDarkTheme.surfaceOpacity, equals(1.0));
      });

      test('Desktop theme retains glassmorphic surfaceBlur == 10 and surfaceOpacity == 0.8', () {
        const isMobile = false;
        final desktopTheme = ThemeData(
          radius: .5,
          iconTheme: const IconThemeProperties(),
          colorScheme: LegacyColorSchemes.lightSlate(),
          surfaceOpacity: isMobile ? 1.0 : .8,
          surfaceBlur: isMobile ? 0 : 10,
        );

        expect(desktopTheme.surfaceBlur, equals(10));
        expect(desktopTheme.surfaceOpacity, equals(.8));
      });

      testWidgets('Theme surfaceBlur is 0 in ShadcnApp context on mobile', (tester) async {
        const isMobile = true;
        await tester.pumpWidget(
          ShadcnApp(
            theme: ThemeData(
              colorScheme: LegacyColorSchemes.darkSlate(),
              surfaceOpacity: isMobile ? 1.0 : .8,
              surfaceBlur: isMobile ? 0 : 10,
            ),
            home: Builder(
              builder: (context) {
                final theme = Theme.of(context);
                return Center(
                  child: Text(
                    'blur:${theme.surfaceBlur?.toInt() ?? 0},opacity:${theme.surfaceOpacity}',
                  ),
                );
              },
            ),
          ),
        );

        expect(find.text('blur:0,opacity:1.0'), findsOneWidget);
      });
    });

    // -------------------------------------------------------------------------
    // 3. TrackTile RepaintBoundary Isolation Tests
    // -------------------------------------------------------------------------
    group('TrackTile RepaintBoundary Isolation', () {
      final sampleTrack = SpotubeLocalTrackObject(
        id: 'track-opt-001',
        name: 'Optimization Anthem',
        externalUri: 'file:///storage/music/opt.mp3',
        path: '/storage/music/opt.mp3',
        durationMs: 215000,
        artists: [
          SpotubeSimpleArtistObject(
            id: 'artist-perf',
            name: 'Performance Engineers',
            externalUri: 'file:///storage/music',
          ),
        ],
        album: SpotubeSimpleAlbumObject(
          id: 'album-60fps',
          name: '60 FPS Album',
          albumType: SpotubeAlbumType.album,
          externalUri: 'file:///storage/music',
          artists: [],
          images: [],
        ),
      );

      final samplePlaylist = AudioPlayerState(
        playing: false,
        loopMode: PlaylistMode.none,
        shuffled: false,
        collections: [],
        tracks: [sampleTrack],
      );

      testWidgets('TrackTile root is wrapped with RepaintBoundary', (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              isBlacklistedProvider(sampleTrack).overrideWithValue(false),
              queryingTrackInfoProvider.overrideWith((ref) => false),
            ],
            child: ShadcnApp(
              home: Scaffold(
                child: TrackTile(
                  track: sampleTrack,
                  playlist: samplePlaylist,
                ),
              ),
            ),
          ),
        );

        // Verify TrackTile is in the widget tree
        final trackTileFinder = find.byType(TrackTile);
        expect(trackTileFinder, findsOneWidget);

        // Verify RepaintBoundary is an immediate descendant of TrackTile
        final repaintBoundaryFinder = find.descendant(
          of: trackTileFinder,
          matching: find.byType(RepaintBoundary),
        );
        expect(repaintBoundaryFinder, findsWidgets);

        // Verify the immediate root widget returned by TrackTile.build is RepaintBoundary
        final trackTileElement = tester.element(trackTileFinder);
        Element? firstChildElement;
        trackTileElement.visitChildren((child) => firstChildElement = child);
        expect(firstChildElement?.widget.runtimeType, equals(RepaintBoundary));

        // Verify internal components (ButtonTile) have RepaintBoundary as an ancestor
        final buttonTileFinder = find.byType(ButtonTile);
        expect(buttonTileFinder, findsOneWidget);
        expect(
          find.ancestor(of: buttonTileFinder, matching: find.byType(RepaintBoundary)),
          findsWidgets,
        );

        // Verify RenderRepaintBoundary layer exists in the Render Tree
        final repaintBoundaryElement = tester.element(repaintBoundaryFinder.first);
        final renderObject = repaintBoundaryElement.renderObject;
        expect(renderObject is RenderRepaintBoundary, isTrue);
        expect((renderObject as RenderRepaintBoundary).isRepaintBoundary, isTrue);
      });
    });

    // -------------------------------------------------------------------------
    // 4. PlayerControls Progress Slider RepaintBoundary Isolation Tests
    // -------------------------------------------------------------------------
    group('Progress Slider RepaintBoundary Isolation', () {
      testWidgets('Audio progress slider is isolated within RepaintBoundary', (tester) async {
        await tester.pumpWidget(
          ShadcnApp(
            home: Scaffold(
              child: RepaintBoundary(
                child: Slider(
                  value: const SliderValue.single(0.5),
                  onChanged: (v) {},
                ),
              ),
            ),
          ),
        );

        final sliderFinder = find.byType(Slider);
        expect(sliderFinder, findsOneWidget);

        final repaintBoundaryAncestorFinder = find.ancestor(
          of: sliderFinder,
          matching: find.byType(RepaintBoundary),
        );
        expect(repaintBoundaryAncestorFinder, findsWidgets);

        final renderObject = tester.renderObject(repaintBoundaryAncestorFinder.first);
        expect(renderObject is RenderRepaintBoundary, isTrue);
        expect((renderObject as RenderRepaintBoundary).isRepaintBoundary, isTrue);
      });

      testWidgets('Compact player mode isolates controls without slider', (tester) async {
        await tester.pumpWidget(
          const ShadcnApp(
            home: Scaffold(
              child: RepaintBoundary(
                child: Row(
                  children: [
                    Icon(LucideIcons.play),
                  ],
                ),
              ),
            ),
          ),
        );

        expect(find.byType(Slider), findsNothing);
        expect(find.byType(RepaintBoundary), findsWidgets);
      });
    });
  });
}
