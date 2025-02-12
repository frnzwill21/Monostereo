import 'package:hetu_script/hetu_script.dart';
import 'package:hetu_script/values.dart';
import 'package:spotube/models/metadata/metadata.dart';

class MetadataPluginSearchEndpoint {
  final Hetu hetu;
  MetadataPluginSearchEndpoint(this.hetu);

  HTInstance get hetuMetadataSearch =>
      (hetu.fetch("metadataPlugin") as HTInstance).memberGet("search")
          as HTInstance;

  List<String> get chips {
    return (hetuMetadataSearch.memberGet("chips") as List).cast<String>();
  }

  Future<SpotubeSearchResponseObject> all(String query) async {
    if (query.isEmpty) {
      return SpotubeSearchResponseObject(
        albums: [],
        artists: [],
        playlists: [],
        tracks: [],
      );
    }

    try {
      final raw = await hetuMetadataSearch.invoke(
        "all",
        positionalArgs: [query],
      );

      if (raw is! Map) {
        return SpotubeSearchResponseObject(
          albums: [],
          artists: [],
          playlists: [],
          tracks: [],
        );
      }

      return SpotubeSearchResponseObject.fromJson(raw.cast<String, dynamic>());
    } catch (e) {
      return SpotubeSearchResponseObject(
        albums: [],
        artists: [],
        playlists: [],
        tracks: [],
      );
    }
  }

  Future<SpotubePaginationResponseObject<SpotubeSimpleAlbumObject>> albums(
    String query, {
    int? limit,
    int? offset,
  }) async {
    if (query.isEmpty) {
      return SpotubePaginationResponseObject<SpotubeSimpleAlbumObject>(
        items: [],
        total: 0,
        limit: limit ?? 20,
        hasMore: false,
        nextOffset: null,
      );
    }

    try {
      final raw = await hetuMetadataSearch.invoke(
        "albums",
        positionalArgs: [query],
        namedArgs: {
          "limit": limit,
          "offset": offset,
        }..removeWhere((key, value) => value == null),
      );

      if (raw is! Map) {
        return SpotubePaginationResponseObject<SpotubeSimpleAlbumObject>(
          items: [],
          total: 0,
          limit: limit ?? 20,
          hasMore: false,
          nextOffset: null,
        );
      }

      return SpotubePaginationResponseObject<SpotubeSimpleAlbumObject>.fromJson(
        raw.cast<String, dynamic>(),
        (json) => SpotubeSimpleAlbumObject.fromJson(json.cast<String, dynamic>()),
      );
    } catch (e) {
      return SpotubePaginationResponseObject<SpotubeSimpleAlbumObject>(
        items: [],
        total: 0,
        limit: limit ?? 20,
        hasMore: false,
        nextOffset: null,
      );
    }
  }

  Future<SpotubePaginationResponseObject<SpotubeFullArtistObject>> artists(
    String query, {
    int? limit,
    int? offset,
  }) async {
    if (query.isEmpty) {
      return SpotubePaginationResponseObject<SpotubeFullArtistObject>(
        items: [],
        total: 0,
        limit: limit ?? 20,
        hasMore: false,
        nextOffset: null,
      );
    }

    try {
      final raw = await hetuMetadataSearch.invoke(
        "artists",
        positionalArgs: [query],
        namedArgs: {
          "limit": limit,
          "offset": offset,
        }..removeWhere((key, value) => value == null),
      );

      if (raw is! Map) {
        return SpotubePaginationResponseObject<SpotubeFullArtistObject>(
          items: [],
          total: 0,
          limit: limit ?? 20,
          hasMore: false,
          nextOffset: null,
        );
      }

      return SpotubePaginationResponseObject<SpotubeFullArtistObject>.fromJson(
        raw.cast<String, dynamic>(),
        (json) => SpotubeFullArtistObject.fromJson(
          json.cast<String, dynamic>(),
        ),
      );
    } catch (e) {
      return SpotubePaginationResponseObject<SpotubeFullArtistObject>(
        items: [],
        total: 0,
        limit: limit ?? 20,
        hasMore: false,
        nextOffset: null,
      );
    }
  }

  Future<SpotubePaginationResponseObject<SpotubeSimplePlaylistObject>>
      playlists(
    String query, {
    int? limit,
    int? offset,
  }) async {
    if (query.isEmpty) {
      return SpotubePaginationResponseObject<SpotubeSimplePlaylistObject>(
        items: [],
        total: 0,
        limit: limit ?? 20,
        hasMore: false,
        nextOffset: null,
      );
    }

    try {
      final raw = await hetuMetadataSearch.invoke(
        "playlists",
        positionalArgs: [query],
        namedArgs: {
          "limit": limit,
          "offset": offset,
        }..removeWhere((key, value) => value == null),
      );

      if (raw is! Map) {
        return SpotubePaginationResponseObject<
            SpotubeSimplePlaylistObject>(
          items: [],
          total: 0,
          limit: limit ?? 20,
          hasMore: false,
          nextOffset: null,
        );
      }

      return SpotubePaginationResponseObject<
          SpotubeSimplePlaylistObject>.fromJson(
        raw.cast<String, dynamic>(),
        (json) => SpotubeSimplePlaylistObject.fromJson(
          json.cast<String, dynamic>(),
        ),
      );
    } catch (e) {
      return SpotubePaginationResponseObject<
          SpotubeSimplePlaylistObject>(
        items: [],
        total: 0,
        limit: limit ?? 20,
        hasMore: false,
        nextOffset: null,
      );
    }
  }

  Future<SpotubePaginationResponseObject<SpotubeFullTrackObject>> tracks(
    String query, {
    int? limit,
    int? offset,
  }) async {
    if (query.isEmpty) {
      return SpotubePaginationResponseObject<SpotubeFullTrackObject>(
        items: [],
        total: 0,
        limit: limit ?? 20,
        hasMore: false,
        nextOffset: null,
      );
    }

    try {
      final raw = await hetuMetadataSearch.invoke(
        "tracks",
        positionalArgs: [query],
        namedArgs: {
          "limit": limit,
          "offset": offset,
        }..removeWhere((key, value) => value == null),
      );

      if (raw is! Map) {
        return SpotubePaginationResponseObject<SpotubeFullTrackObject>(
          items: [],
          total: 0,
          limit: limit ?? 20,
          hasMore: false,
          nextOffset: null,
        );
      }

      return SpotubePaginationResponseObject<SpotubeFullTrackObject>.fromJson(
        raw.cast<String, dynamic>(),
        (json) => SpotubeFullTrackObject.fromJson(json.cast<String, dynamic>()),
      );
    } catch (e) {
      return SpotubePaginationResponseObject<SpotubeFullTrackObject>(
        items: [],
        total: 0,
        limit: limit ?? 20,
        hasMore: false,
        nextOffset: null,
      );
    }
  }
}
