import 'package:hetu_script/hetu_script.dart';
import 'package:hetu_script/values.dart';
import 'package:spotube/models/metadata/metadata.dart';

class MetadataPluginAlbumEndpoint {
  final Hetu hetu;
  MetadataPluginAlbumEndpoint(this.hetu);

  HTInstance get hetuMetadataAlbum =>
      (hetu.fetch("metadataPlugin") as HTInstance).memberGet("album")
          as HTInstance;

  Future<SpotubeFullAlbumObject> getAlbum(String id) async {
    final raw =
        await hetuMetadataAlbum.invoke("getAlbum", positionalArgs: [id]);
    if (raw is! Map) {
      throw Exception("Failed to get album: empty or invalid response");
    }

    return SpotubeFullAlbumObject.fromJson(
      raw.cast<String, dynamic>(),
    );
  }

  Future<SpotubePaginationResponseObject<SpotubeFullTrackObject>> tracks(
    String id, {
    int? offset,
    int? limit,
  }) async {
    try {
      final raw = await hetuMetadataAlbum.invoke(
        "tracks",
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

  Future<SpotubePaginationResponseObject<SpotubeSimpleAlbumObject>> releases({
    int? offset,
    int? limit,
  }) async {
    try {
      final raw = await hetuMetadataAlbum.invoke(
        "releases",
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

  Future<void> save(List<String> ids) async {
    await hetuMetadataAlbum.invoke(
      "save",
      positionalArgs: [ids],
    );
  }

  Future<void> unsave(List<String> ids) async {
    await hetuMetadataAlbum.invoke(
      "unsave",
      positionalArgs: [ids],
    );
  }
}
