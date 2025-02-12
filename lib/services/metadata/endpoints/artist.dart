import 'package:hetu_script/hetu_script.dart';
import 'package:hetu_script/values.dart';
import 'package:spotube/models/metadata/metadata.dart';

class MetadataPluginArtistEndpoint {
  final Hetu hetu;
  MetadataPluginArtistEndpoint(this.hetu);

  HTInstance get hetuMetadataArtist =>
      (hetu.fetch("metadataPlugin") as HTInstance).memberGet("artist")
          as HTInstance;

  Future<SpotubeFullArtistObject> getArtist(String id) async {
    final raw = await hetuMetadataArtist
        .invoke("getArtist", positionalArgs: [id]);
    if (raw is! Map) {
      throw Exception("Artist not found or invalid response for id: $id");
    }

    return SpotubeFullArtistObject.fromJson(
      raw.cast<String, dynamic>(),
    );
  }

  Future<SpotubePaginationResponseObject<SpotubeFullTrackObject>> topTracks(
    String id, {
    int? offset,
    int? limit,
  }) async {
    try {
      final raw = await hetuMetadataArtist.invoke(
        "topTracks",
        positionalArgs: [id],
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
        (Map json) => SpotubeFullTrackObject.fromJson(
          json.cast<String, dynamic>(),
        ),
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

  Future<SpotubePaginationResponseObject<SpotubeSimpleAlbumObject>> albums(
    String id, {
    int? offset,
    int? limit,
  }) async {
    try {
      final raw = await hetuMetadataArtist.invoke(
        "albums",
        positionalArgs: [id],
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
        (Map json) => SpotubeSimpleAlbumObject.fromJson(
          json.cast<String, dynamic>(),
        ),
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

  Future<void> save(List<String> ids) async {
    await hetuMetadataArtist.invoke(
      "save",
      positionalArgs: [ids],
    );
  }

  Future<void> unsave(List<String> ids) async {
    await hetuMetadataArtist.invoke(
      "unsave",
      positionalArgs: [ids],
    );
  }

  Future<SpotubePaginationResponseObject<SpotubeFullArtistObject>> related(
    String id, {
    int? offset,
    int? limit,
  }) async {
    try {
      final raw = await hetuMetadataArtist.invoke(
        "related",
        positionalArgs: [id],
        namedArgs: {
          "offset": offset,
          "limit": limit ?? 20,
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
        (Map json) => SpotubeFullArtistObject.fromJson(
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
}
