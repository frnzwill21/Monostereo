import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spotube/models/database/database.dart';
import 'package:spotube/models/metadata/metadata.dart';
import 'package:spotube/models/playback/track_sources.dart';
import 'package:spotube/provider/database/database.dart';
import 'package:spotube/provider/metadata_plugin/audio_source/quality_presets.dart';
import 'package:spotube/provider/metadata_plugin/metadata_plugin_provider.dart';
import 'package:spotube/services/dio/dio.dart';
import 'package:spotube/services/logger/logger.dart';
import 'package:spotube/services/metadata/errors/exceptions.dart';
import 'package:spotube/services/sourced_track/exceptions.dart';

final officialMusicRegex = RegExp(
  r"(\bofficial\s*(video|audio|music\s*video|lyric\s*video|visualizer|track|hd\s*video|4k\s*video)\b|\b(official\s+audio|official\s+video)\b|\(audio\)|\[audio\])",
  caseSensitive: false,
);

final officialAudioRegex = RegExp(
  r"(\b(official\s+audio|official\s+track|audio\s+visualizer)\b|\(audio\)|\[audio\])",
  caseSensitive: false,
);

final officialVisualRegex = RegExp(
  r"(\bofficial\s*(video|music\s*video|lyric\s*video|visualizer|hd\s*video|4k\s*video)\b|\b(official\s+video)\b)",
  caseSensitive: false,
);

final reactionRegex = RegExp(
  r"(\b(react|reacts|reaction|reacting|first\s*time\s*(hearing|listening)|breakdown|vocal\s*coach|producer\s*reacts|analysis|review|lesson|how\s*to\s*play|tutorial|parody)\b|for\s+the\s+first\s+time|listening\s+to\s+.*?\bfirst\s*time\b)",
  caseSensitive: false,
);

final coverRegex = RegExp(
  r"\b(cover|covered\s+by|acoustic\s+cover|guitar\s+cover|drum\s+cover|piano\s+cover|vocal\s+cover|fingerstyle|tribute|fan\s+cover)\b",
  caseSensitive: false,
);

final liveRegex = RegExp(
  r"\b(live|concert|tour|live\s+at|live\s+in|live\s+from|unplugged|festival|sessions|on\s+mtv|bbc\s+session|tiny\s+desk|glastonbury|coachella|rock\s+in\s+rio)\b",
  caseSensitive: false,
);

final alteredAudioRegex = RegExp(
  r"\b(slowed|reverb|sped\s+up|speed\s+up|nightcore|8d\s+audio|bass\s+boost|bass\s+boosted|pitch\s+shift|clean\s+edit|tiktok\s+version|1\s+hour|10\s+hour|10\s+hours|hour\s+loop|loop|loops)\b",
  caseSensitive: false,
);

final majorLabelRegex = RegExp(
  r"\b(warner|sony\s*music|universal\s*music|atlantic\s*records|interscope|columbia\s*records|epic\s*records|republic\s*records|capitol\s*records|def\s*jam|island\s*records|virgin\s*records|rca\s*records|polydor|spinnin|monstercat|sub\s*pop|epitaph|nuclear\s*blast|ultra\s*records|dirty\s*hit)\b",
  caseSensitive: false,
);

String _foldDiacritics(String text) {
  const map = {
    'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a', 'ā': 'a', 'ă': 'a', 'ą': 'a',
    'æ': 'ae', 'ç': 'c', 'ć': 'c', 'č': 'c',
    'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e', 'ē': 'e', 'ė': 'e', 'ę': 'e', 'ě': 'e',
    'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i', 'ī': 'i', 'į': 'i',
    'ñ': 'n', 'ń': 'n', 'ň': 'n',
    'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o', 'ø': 'o', 'ō': 'o', 'ő': 'o',
    'œ': 'oe',
    'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u', 'ū': 'u', 'ů': 'u', 'ű': 'u',
    'ý': 'y', 'ÿ': 'y',
    'ß': 'ss',
    'ž': 'z', 'ź': 'z', 'ż': 'z',
    'š': 's', 'ś': 's',
    'ř': 'r', 'ŕ': 'r',
    'ł': 'l',
    'đ': 'd',
  };
  final lower = text.toLowerCase();
  final buffer = StringBuffer();
  for (var i = 0; i < lower.length; i++) {
    final char = lower[i];
    buffer.write(map[char] ?? char);
  }
  return buffer.toString();
}

String _normalizeText(String input) {
  return _foldDiacritics(input).replaceAll(RegExp(r"[^a-z0-9]"), "");
}

String _extractCleanTitle(String title) {
  return title
      .replaceAll(
        RegExp(
          r"\s*[-–]\s*.*?(remaster|anniversary|deluxe|edition|version|feat\.|bonus).*$|\s*[\(\[][^\)\]]*(remaster|anniversary|deluxe|edition|version|feat\.|bonus)[^\)\]]*[\)\]]",
          caseSensitive: false,
        ),
        "",
      )
      .trim();
}


class SourcedTrack extends BasicSourcedTrack {
  final Ref ref;

  SourcedTrack({
    required this.ref,
    required super.info,
    required super.query,
    required super.source,
    required super.siblings,
    required super.sources,
  });

  static Future<SourcedTrack> fetchFromTrack({
    required SpotubeFullTrackObject query,
    required Ref ref,
  }) async {
    final audioSource = await ref.read(audioSourcePluginProvider.future);
    final audioSourceConfig = await ref.read(metadataPluginsProvider
        .selectAsync((data) => data.defaultAudioSourcePluginConfig));
    if (audioSource == null || audioSourceConfig == null) {
      throw MetadataPluginException.noDefaultAudioSourcePlugin();
    }

    final database = ref.read(databaseProvider);
    final cachedSource = await (database.select(database.sourceMatchTable)
          ..where((s) =>
              s.trackId.equals(query.id) &
              s.sourceType.equals(audioSourceConfig.slug))
          ..limit(1)
          ..orderBy([
            (s) =>
                OrderingTerm(expression: s.createdAt, mode: OrderingMode.desc),
          ]))
        .get()
        .then((s) => s.firstOrNull);

    if (cachedSource == null) {
      final siblings = await fetchSiblings(ref: ref, query: query);
      if (siblings.isEmpty) {
        throw TrackNotFoundError(query);
      }

      await database.into(database.sourceMatchTable).insert(
            SourceMatchTableCompanion.insert(
              trackId: query.id,
              sourceInfo: Value(jsonEncode(siblings.first)),
              sourceType: audioSourceConfig.slug,
            ),
          );

      final manifest = await audioSource.audioSource.streams(siblings.first);

      return SourcedTrack(
        ref: ref,
        siblings: siblings.skip(1).toList(),
        info: siblings.first,
        source: audioSourceConfig.slug,
        sources: manifest,
        query: query,
      );
    }
    final item = SpotubeAudioSourceMatchObject.fromJson(
      jsonDecode(cachedSource.sourceInfo),
    );
    final manifest = await audioSource.audioSource.streams(item);

    final sourcedTrack = SourcedTrack(
      ref: ref,
      siblings: [],
      sources: manifest,
      info: item,
      query: query,
      source: audioSourceConfig.slug,
    );

    AppLogger.log.i("${query.name}: ${sourcedTrack.url}");

    return sourcedTrack;
  }

  static List<SpotubeAudioSourceMatchObject> rankResults(
    List<SpotubeAudioSourceMatchObject> results,
    SpotubeFullTrackObject track,
  ) {
    final lowerTrackName = track.name.toLowerCase();
    final cleanTrackName = _extractCleanTitle(track.name).toLowerCase();
    final lowerAlbumName = track.album.name.toLowerCase();

    final liveWordRegex =
        RegExp(r"\b(live|concert|unplugged|sessions|festival)\b", caseSensitive: false);
    final isTargetLive =
        liveWordRegex.hasMatch(lowerTrackName) || liveWordRegex.hasMatch(lowerAlbumName);
    final isBandLive =
        track.artists.any((a) => a.name.trim().toLowerCase() == "live");

    final isTargetCover =
        lowerTrackName.contains("cover") || lowerTrackName.contains("tribute");

    final isTargetRemix =
        lowerTrackName.contains("remix") || lowerTrackName.contains("mix");

    final isTargetInstrumental = lowerTrackName.contains("karaoke") ||
        lowerTrackName.contains("instrumental") ||
        lowerTrackName.contains("backing track");

    final isTargetAltered = lowerTrackName.contains("slowed") ||
        lowerTrackName.contains("reverb") ||
        lowerTrackName.contains("nightcore") ||
        lowerTrackName.contains("sped up");

    final isTargetReaction = reactionRegex.hasMatch(lowerTrackName);

    return results
        .map((sibling) {
          int score = 0;
          final lowerSiblingTitle = sibling.title.toLowerCase();
          final siblingNorm = _normalizeText(sibling.title);

          final hasReactionMarker = reactionRegex.hasMatch(lowerSiblingTitle);
          final isActualReaction = hasReactionMarker && !isTargetReaction;

          var hasTopicBoost = false;
          var hasSameArtistBoost = false;
          var hasVevoBoost = false;
          var hasMajorLabelBoost = false;

          for (final artist in track.artists) {
            final artistNameLower = artist.name.toLowerCase();
            final artistNorm = _normalizeText(artist.name);

            for (final rawChannel in sibling.artists) {
              final channelLower = rawChannel.toLowerCase();
              final channelNorm = _normalizeText(rawChannel);

              // 1. Topic Channel (Tier 1: Record label studio master)
              final bool isTopicChannel;
              if (artistNorm.isNotEmpty) {
                isTopicChannel = channelLower.endsWith(" - topic") &&
                    (channelNorm.contains(artistNorm) ||
                        artistNorm.contains(channelNorm.replaceAll("topic", "")));
              } else {
                isTopicChannel = channelLower.endsWith(" - topic") &&
                    channelLower.contains(artistNameLower);
              }
              if (isTopicChannel && !hasTopicBoost && !isActualReaction) {
                score += 30;
                hasTopicBoost = true;
              }

              // 2. Same Channel Artist or Official Handle
              final bool isSameChannelArtist;
              if (artistNorm.isNotEmpty) {
                isSameChannelArtist = channelNorm == artistNorm ||
                    channelNorm == "${artistNorm}official" ||
                    channelNorm == "official$artistNorm";
              } else {
                isSameChannelArtist = channelLower == artistNameLower ||
                    channelLower.contains(artistNameLower);
              }
              if (isSameChannelArtist && !hasSameArtistBoost && !isActualReaction) {
                score += 15;
                hasSameArtistBoost = true;
              }

              // 3. VEVO Channel (Normalized to handle spaces like BillieEilishVEVO)
              final bool isVevoChannel;
              if (artistNorm.isNotEmpty) {
                isVevoChannel = channelNorm.contains("${artistNorm}vevo") ||
                    (channelNorm.endsWith("vevo") && channelNorm.contains(artistNorm));
              } else {
                isVevoChannel = channelLower.endsWith("vevo") &&
                    channelLower.contains(artistNameLower);
              }
              if (isVevoChannel && !hasVevoBoost && !isActualReaction) {
                score += 22;
                hasVevoBoost = true;
              }
            }

            if (lowerSiblingTitle.contains(artistNameLower) ||
                (artistNorm.isNotEmpty && siblingNorm.contains(artistNorm))) {
              score += 4;
            }
          }

          // 4. Known Record Label Upload
          for (final rawChannel in sibling.artists) {
            final channelLower = rawChannel.toLowerCase();
            if (majorLabelRegex.hasMatch(channelLower) && !hasMajorLabelBoost) {
              score += 12;
              hasMajorLabelBoost = true;
            }
          }

          // Title Matching (exact, core, or substring)
          final exactTitleMatch = lowerSiblingTitle.contains(lowerTrackName);
          final cleanTitleMatch =
              cleanTrackName.isNotEmpty && lowerSiblingTitle.contains(cleanTrackName);

          if (exactTitleMatch) {
            score += 10;
          } else if (cleanTitleMatch) {
            score += 7;
          }

          // Official badges in title
          final hasOfficialAudio = officialAudioRegex.hasMatch(lowerSiblingTitle);
          final hasOfficialVisual = officialVisualRegex.hasMatch(lowerSiblingTitle);

          if (hasOfficialAudio && !isActualReaction) {
            score += 10;
          } else if (hasOfficialVisual && !isActualReaction) {
            score += 6;
          }

          // Duration proximity matching
          if (track.durationMs > 0) {
            final trackDurationSec = track.durationMs ~/ 1000;
            final diff = (sibling.duration.inSeconds - trackDurationSec).abs();
            if (diff <= 2) {
              score += 15;
            } else if (diff <= 5) {
              score += 10;
            } else if (diff <= 10) {
              score += 5;
            } else if (diff > 300) {
              score -= 80;
            } else if (diff > 180) {
              score -= 45;
            } else if (diff > 60) {
              score -= 25;
            } else if (diff > 30) {
              score -= 12;
            }
          } else {
            // Missing or zero track duration metadata: penalize long compilations/albums
            if (sibling.duration > const Duration(minutes: 10)) {
              score -= 80;
            }
          }

          // Intent-aware Penalties vs Preferences
          if (!isTargetCover && coverRegex.hasMatch(lowerSiblingTitle)) {
            score -= 45;
          }

          if (!isTargetLive && !isBandLive && liveRegex.hasMatch(lowerSiblingTitle)) {
            score -= 35;
          } else if (isTargetLive && liveRegex.hasMatch(lowerSiblingTitle)) {
            score += 15;
          }

          if (!isTargetInstrumental &&
              (lowerSiblingTitle.contains("karaoke") ||
                  lowerSiblingTitle.contains("instrumental"))) {
            score -= 30;
          }

          if (!isTargetRemix && lowerSiblingTitle.contains("remix")) {
            score -= 20;
          }

          if (!isTargetAltered && alteredAudioRegex.hasMatch(lowerSiblingTitle)) {
            score -= 50;
          }

          if (isActualReaction) {
            score -= 75;
          }

          return (sibling: sibling, score: score);
        })
        .sorted((a, b) => b.score.compareTo(a.score))
        .map((e) => e.sibling)
        .toList();
  }

  static Future<List<SpotubeAudioSourceMatchObject>> fetchSiblings({
    required SpotubeFullTrackObject query,
    required Ref ref,
  }) async {
    final audioSource = await ref.read(audioSourcePluginProvider.future);

    if (audioSource == null) {
      throw MetadataPluginException.noDefaultAudioSourcePlugin();
    }

    final isDirectYouTube = query.externalUri.contains("youtube.com") ||
        (query.id.length == 11 && !query.id.contains("-"));

    if (isDirectYouTube) {
      final uri = Uri.tryParse(query.externalUri);
      final videoId = (uri != null && uri.queryParameters.containsKey("v"))
          ? uri.queryParameters["v"]!
          : query.id;

      final directMatch = SpotubeAudioSourceMatchObject(
        id: videoId,
        title: query.name,
        artists: query.artists.map((a) => a.name).toList(),
        duration: Duration(milliseconds: query.durationMs),
        thumbnail: query.album.images.firstOrNull?.url,
        externalUri: "https://youtube.com/watch?v=$videoId",
      );

      return [directMatch];
    }

    final searchResults = await audioSource.audioSource.matches(query);

    final rankedResults = rankResults(searchResults, query);

    return rankedResults.toSet().toList();
  }

  Future<SourcedTrack> copyWithSibling() async {
    if (siblings.isNotEmpty) {
      return this;
    }
    final fetchedSiblings = await fetchSiblings(ref: ref, query: query);

    return SourcedTrack(
      ref: ref,
      siblings: fetchedSiblings.where((s) => s.id != info.id).toList(),
      source: source,
      sources: sources,
      info: info,
      query: query,
    );
  }

  Future<SourcedTrack?> swapWithSibling(
    SpotubeAudioSourceMatchObject sibling,
  ) async {
    if (sibling.id == info.id) {
      return null;
    }

    final audioSource = await ref.read(audioSourcePluginProvider.future);
    final audioSourceConfig = await ref.read(metadataPluginsProvider
        .selectAsync((data) => data.defaultAudioSourcePluginConfig));
    if (audioSource == null || audioSourceConfig == null) {
      throw MetadataPluginException.noDefaultAudioSourcePlugin();
    }

    // a sibling source that was fetched from the search results
    final isStepSibling = siblings.none((s) => s.id == sibling.id);

    final newSourceInfo = isStepSibling
        ? sibling
        : siblings.firstWhere((s) => s.id == sibling.id);

    final newSiblings = siblings.where((s) => s.id != sibling.id).toList()
      ..insert(0, info);

    final manifest = await audioSource.audioSource.streams(newSourceInfo);

    final database = ref.read(databaseProvider);

    // Delete the old Entry
    await (database.sourceMatchTable.delete()
          ..where(
            (table) =>
                table.trackId.equals(query.id) &
                table.sourceType.equals(audioSourceConfig.slug),
          ))
        .go();

    await database.into(database.sourceMatchTable).insert(
          SourceMatchTableCompanion.insert(
            trackId: query.id,
            sourceInfo: Value(jsonEncode(sibling)),
            sourceType: audioSourceConfig.slug,
            createdAt: Value(DateTime.now()),
          ),
          mode: InsertMode.replace,
        );

    return SourcedTrack(
      ref: ref,
      source: source,
      siblings: newSiblings,
      sources: manifest,
      info: newSourceInfo,
      query: query,
    );
  }

  Future<SourcedTrack?> swapWithSiblingOfIndex(int index) {
    return swapWithSibling(siblings[index]);
  }

  Future<SourcedTrack> refreshStream() async {
    final audioSource = await ref.read(audioSourcePluginProvider.future);
    final audioSourceConfig = await ref.read(metadataPluginsProvider
        .selectAsync((data) => data.defaultAudioSourcePluginConfig));
    if (audioSource == null || audioSourceConfig == null) {
      throw MetadataPluginException.noDefaultAudioSourcePlugin();
    }

    List<SpotubeAudioSourceStreamObject> validStreams = [];

    final stringBuffer = StringBuffer();
    for (final source in sources) {
      final res = await globalDio.head(
        source.url,
        options:
            Options(validateStatus: (status) => status != null && status < 500),
      );

      stringBuffer.writeln(
        "[${query.id}] ${res.statusCode} ${source.container} ${source.codec} ${source.bitrate}",
      );

      if (res.statusCode! < 400) {
        validStreams.add(source);
      }
    }

    AppLogger.log.d(stringBuffer.toString());

    if (validStreams.isEmpty) {
      validStreams = await audioSource.audioSource.streams(info);
    }

    final sourcedTrack = SourcedTrack(
      ref: ref,
      siblings: siblings,
      source: source,
      sources: validStreams,
      info: info,
      query: query,
    );

    AppLogger.log.i("Refreshing ${query.name}: ${sourcedTrack.url}");

    return sourcedTrack;
  }

  String? get url {
    final preferences = ref.read(audioSourcePresetsProvider);

    return getUrlOfQuality(
      preferences.presets[preferences.selectedStreamingContainerIndex],
      preferences.selectedStreamingQualityIndex,
    );
  }

  /// Returns the URL of the track based on the codec and quality preferences.
  /// If an exact match is not found, it will return the closest match based on
  /// the user's audio quality preference.
  ///
  /// If no sources match the codec, it will return the first or last source
  /// based on the user's audio quality preference.
  SpotubeAudioSourceStreamObject? getStreamOfQuality(
    SpotubeAudioSourceContainerPreset preset,
    int qualityIndex,
  ) {
    if (sources.isEmpty) return null;

    final quality = preset.qualities[qualityIndex];

    final exactMatch = sources.firstWhereOrNull(
      (source) {
        if (source.container != preset.name) return false;

        if (quality case SpotubeAudioLosslessContainerQuality()) {
          return source.sampleRate == quality.sampleRate &&
              source.bitDepth == quality.bitDepth;
        } else {
          return source.bitrate ==
              (quality as SpotubeAudioLossyContainerQuality).bitrate;
        }
      },
    );

    if (exactMatch != null) {
      return exactMatch;
    }

    // Find the preset with closest quality to the supplied quality
    return sources.where((source) {
      return source.container == preset.name;
    }).reduce((prev, curr) {
      if (quality is SpotubeAudioLosslessContainerQuality) {
        final prevDiff = ((prev.sampleRate ?? 0) - quality.sampleRate).abs() +
            ((prev.bitDepth ?? 0) - quality.bitDepth).abs();
        final currDiff = ((curr.sampleRate ?? 0) - quality.sampleRate).abs() +
            ((curr.bitDepth ?? 0) - quality.bitDepth).abs();
        return currDiff < prevDiff ? curr : prev;
      } else {
        final prevDiff = ((prev.bitrate ?? 0) -
                (quality as SpotubeAudioLossyContainerQuality).bitrate)
            .abs();
        final currDiff = ((curr.bitrate ?? 0) - quality.bitrate).abs();
        return currDiff < prevDiff ? curr : prev;
      }
    });
  }

  String? getUrlOfQuality(
    SpotubeAudioSourceContainerPreset preset,
    int qualityIndex,
  ) {
    return getStreamOfQuality(preset, qualityIndex)?.url;
  }

  SpotubeAudioSourceContainerPreset? get qualityPreset {
    final presetState = ref.read(audioSourcePresetsProvider);
    return presetState.presets
        .elementAtOrNull(presetState.selectedStreamingContainerIndex);
  }
}
