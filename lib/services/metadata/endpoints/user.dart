import 'package:hetu_script/hetu_script.dart';
import 'package:hetu_script/values.dart';
import 'package:spotube/models/metadata/metadata.dart';

class MetadataPluginUserEndpoint {
  final Hetu hetu;
  MetadataPluginUserEndpoint(this.hetu);

  HTInstance get hetuMetadataUser =>
      (hetu.fetch("metadataPlugin") as HTInstance).memberGet("user")
          as HTInstance;

  Future<SpotubeUserObject?> me() async {
    try {
      final raw = await hetuMetadataUser.invoke("me");
      if (raw is! Map) return null;

      return SpotubeUserObject.fromJson(
        raw.cast<String, dynamic>(),
      );
    } catch (e) {
      return null;
    }
  }

  Future<SpotubePaginationResponseObject<SpotubeFullTrackObject>> savedTracks({
    int? offset,
    int? limit,
  }) async {
    try {
      final raw = await hetuMetadataUser.invoke(
        "savedTracks",
        namedArgs: {
          "offset": offset,
          "limit": limit,
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
        (Map json) =>
            SpotubeFullTrackObject.fromJson(json.cast<String, dynamic>()),
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

  Future<SpotubePaginationResponseObject<SpotubeSimplePlaylistObject>>
      savedPlaylists({
    int? offset,
    int? limit,
  }) async {
    try {
      final raw = await hetuMetadataUser.invoke(
        "savedPlaylists",
        namedArgs: {
          "offset": offset,
          "limit": limit,
        }..removeWhere((key, value) => value == null),
      );

      if (raw is! Map) {
        return SpotubePaginationResponseObject<SpotubeSimplePlaylistObject>(
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
        (Map json) =>
            SpotubeSimplePlaylistObject.fromJson(json.cast<String, dynamic>()),
      );
    } catch (e) {
      return SpotubePaginationResponseObject<SpotubeSimplePlaylistObject>(
        items: [],
        total: 0,
        limit: limit ?? 20,
        hasMore: false,
        nextOffset: null,
      );
    }
  }

  Future<SpotubePaginationResponseObject<SpotubeSimpleAlbumObject>>
      savedAlbums({
    int? offset,
    int? limit,
  }) async {
    try {
      final raw = await hetuMetadataUser.invoke(
        "savedAlbums",
        namedArgs: {
          "offset": offset,
          "limit": limit,
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
        (Map json) =>
            SpotubeSimpleAlbumObject.fromJson(json.cast<String, dynamic>()),
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

  Future<SpotubePaginationResponseObject<SpotubeFullArtistObject>>
      savedArtists({
    int? offset,
    int? limit,
  }) async {
    try {
      final raw = await hetuMetadataUser.invoke(
        "savedArtists",
        namedArgs: {
          "offset": offset,
          "limit": limit,
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
        (Map json) =>
            SpotubeFullArtistObject.fromJson(json.cast<String, dynamic>()),
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

  Future<bool> isSavedPlaylist(String playlistId) async {
    try {
      final raw = await hetuMetadataUser.invoke(
        "isSavedPlaylist",
        positionalArgs: [playlistId],
      );
      return raw == true;
    } catch (e) {
      return false;
    }
  }

  Future<List<bool>> isSavedTracks(List<String> ids) async {
    try {
      final values = await hetuMetadataUser.invoke(
        "isSavedTracks",
        positionalArgs: [ids],
      );
      if (values is! List) return ids.map((e) => false).toList();
      return values.cast<bool>();
    } catch (e) {
      return ids.map((e) => false).toList();
    }
  }

  Future<List<bool>> isSavedAlbums(List<String> ids) async {
    try {
      final values = await hetuMetadataUser.invoke(
        "isSavedAlbums",
        positionalArgs: [ids],
      );
      if (values is! List) return ids.map((e) => false).toList();
      return values.cast<bool>();
    } catch (e) {
      return ids.map((e) => false).toList();
    }
  }

  Future<List<bool>> isSavedArtists(List<String> ids) async {
    try {
      final values = await hetuMetadataUser.invoke(
        "isSavedArtists",
        positionalArgs: [ids],
      );
      if (values is! List) return ids.map((e) => false).toList();
      return values.cast<bool>();
    } catch (e) {
      return ids.map((e) => false).toList();
    }
  }
}
