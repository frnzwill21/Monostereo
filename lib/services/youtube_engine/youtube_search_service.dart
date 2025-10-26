import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:spotube/models/metadata/metadata.dart';
import 'package:spotube/provider/metadata_plugin/metadata_plugin_provider.dart';
import 'package:spotube/provider/youtube_engine/youtube_engine.dart';
import 'package:spotube/services/logger/logger.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

final youtubeSearchServiceProvider = Provider<YouTubeSearchService>((ref) {
  return YouTubeSearchService(ref);
});

class YouTubeSearchService {
  final Ref ref;
  YouTubeSearchService(this.ref);

  static final _noiseRegex = RegExp(
    r"\s*[\(\[](official\s*(music\s*)?video|official\s*audio|lyrics?|lyric\s*video|audio|visualizer|hd|4k|hq|mv|music\s*video|m\/v|clip\s*officiel|video\s*clip|ost)[\)\]]",
    caseSensitive: false,
  );

  static SpotubeFullTrackObject parseVideoToTrack(Video video) {
    final rawTitle = video.title.trim();
    String trackName = rawTitle;
    List<String> artistNames = [video.author];

    final cleaned = rawTitle.replaceAll(_noiseRegex, "").trim();

    if (cleaned.contains(" - ")) {
      final parts = cleaned.split(" - ");
      final artistPart = parts[0].trim();
      final titlePart = parts.sublist(1).join(" - ").trim();

      if (artistPart.isNotEmpty && titlePart.isNotEmpty) {
        trackName = titlePart;
        final splitArtists = artistPart
            .split(RegExp(r"\s*(?:,|&|feat\.|ft\.|x)\s*", caseSensitive: false))
            .map((a) => a.trim())
            .where((a) => a.isNotEmpty)
            .toList();
        if (splitArtists.isNotEmpty) {
          artistNames = splitArtists;
        }
      }
    } else {
      trackName = cleaned.isNotEmpty ? cleaned : rawTitle;
    }

    trackName = trackName
        .replaceAll(RegExp(r"[\(\[]\s*[\)\]]"), "")
        .trim();

    final artists = artistNames.map((name) {
      return SpotubeSimpleArtistObject(
        id: video.channelId.value,
        name: name,
        externalUri: "https://youtube.com/channel/${video.channelId.value}",
      );
    }).toList();

    final imageUrl = video.thumbnails.highResUrl.isNotEmpty
        ? video.thumbnails.highResUrl
        : (video.thumbnails.mediumResUrl.isNotEmpty
            ? video.thumbnails.mediumResUrl
            : video.thumbnails.lowResUrl);

    final uploadDateStr = video.uploadDate != null
        ? DateFormat("yyyy-MM-dd").format(video.uploadDate!)
        : "1970-01-01";

    final album = SpotubeSimpleAlbumObject(
      id: video.id.value,
      name: trackName,
      externalUri: "https://youtube.com/watch?v=${video.id.value}",
      albumType: SpotubeAlbumType.single,
      artists: artists,
      releaseDate: uploadDateStr,
      images: [
        SpotubeImageObject(
          url: imageUrl,
          width: 500,
          height: 500,
        ),
      ],
    );

    return SpotubeFullTrackObject(
      id: video.id.value,
      name: trackName,
      externalUri: "https://youtube.com/watch?v=${video.id.value}",
      artists: artists,
      album: album,
      durationMs: video.duration?.inMilliseconds ?? 0,
      isrc: "",
      explicit: false,
    );
  }

  Future<SpotubePaginationResponseObject<SpotubeFullTrackObject>> searchTracks(
    String query, {
    int? limit,
    int? offset,
  }) async {
    if (query.trim().isEmpty) {
      return SpotubePaginationResponseObject<SpotubeFullTrackObject>(
        items: [],
        total: 0,
        limit: limit ?? 20,
        hasMore: false,
        nextOffset: null,
      );
    }

    try {
      final engine = ref.read(youtubeEngineProvider);
      final videos = await engine.searchVideos(query);

      final tracks = videos.map(parseVideoToTrack).toList();

      final currentOffset = offset ?? 0;
      final currentLimit = limit ?? 20;

      final pagedItems = tracks.skip(currentOffset).take(currentLimit).toList();
      final hasMore = currentOffset + pagedItems.length < tracks.length;

      return SpotubePaginationResponseObject<SpotubeFullTrackObject>(
        items: pagedItems.isNotEmpty ? pagedItems : tracks,
        total: tracks.length,
        limit: currentLimit,
        hasMore: hasMore,
        nextOffset: hasMore ? currentOffset + currentLimit : null,
      );
    } catch (e, stack) {
      AppLogger.log.e("YouTubeSearchService.searchTracks failed",
          error: e, stackTrace: stack);
      return SpotubePaginationResponseObject<SpotubeFullTrackObject>(
        items: [],
        total: 0,
        limit: limit ?? 20,
        hasMore: false,
        nextOffset: null,
      );
    }
  }

  Future<SpotubeSearchResponseObject> searchAll(String query) async {
    if (query.trim().isEmpty) {
      return SpotubeSearchResponseObject(
        albums: [],
        artists: [],
        playlists: [],
        tracks: [],
      );
    }

    try {
      final tracksFuture = searchTracks(query, limit: 10);
      SpotubeSearchResponseObject? mbResults;
      try {
        final metadataPlugin = await ref.read(metadataPluginProvider.future);
        if (metadataPlugin != null) {
          mbResults = await metadataPlugin.search.all(query).timeout(
            const Duration(seconds: 2),
            onTimeout: () => SpotubeSearchResponseObject(
              albums: [],
              artists: [],
              playlists: [],
              tracks: [],
            ),
          );
        }
      } catch (e) {
        AppLogger.log.w("MusicBrainz search.all fallback failed or timed out: $e");
      }

      final ytTracks = await tracksFuture;
      return SpotubeSearchResponseObject(
        tracks: ytTracks.items,
        albums: mbResults?.albums ?? [],
        artists: mbResults?.artists ?? [],
        playlists: mbResults?.playlists ?? [],
      );
    } catch (e, stack) {
      AppLogger.log.e("YouTubeSearchService.searchAll failed",
          error: e, stackTrace: stack);
      return SpotubeSearchResponseObject(
        albums: [],
        artists: [],
        playlists: [],
        tracks: [],
      );
    }
  }
}
