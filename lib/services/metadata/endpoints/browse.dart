import 'package:hetu_script/hetu_script.dart';
import 'package:hetu_script/values.dart';
import 'package:spotube/models/metadata/metadata.dart';

class MetadataPluginBrowseEndpoint {
  final Hetu hetu;
  MetadataPluginBrowseEndpoint(this.hetu);

  HTInstance get hetuMetadataBrowse =>
      (hetu.fetch("metadataPlugin") as HTInstance).memberGet("browse")
          as HTInstance;

  Future<SpotubePaginationResponseObject<SpotubeBrowseSectionObject<Object>>>
      sections({
    int? offset,
    int? limit,
  }) async {
    try {
      final raw = await hetuMetadataBrowse.invoke(
        "sections",
        namedArgs: {
          "offset": offset,
          "limit": limit,
        }..removeWhere((key, value) => value == null),
      );

      if (raw is! Map) {
        return SpotubePaginationResponseObject<
            SpotubeBrowseSectionObject<Object>>(
          items: [],
          total: 0,
          nextOffset: null,
          limit: limit ?? 20,
          hasMore: false,
        );
      }

      return SpotubePaginationResponseObject<
          SpotubeBrowseSectionObject<Object>>.fromJson(
        raw.cast<String, dynamic>(),
        (Map json) => SpotubeBrowseSectionObject<Object>.fromJson(
          json.cast<String, dynamic>(),
          (json) {
            final isPlaylist = json["owner"] != null;
            final isAlbum = json["artists"] != null;
            if (isPlaylist) {
              return SpotubeSimplePlaylistObject.fromJson(
                json.cast<String, dynamic>(),
              );
            } else if (isAlbum) {
              return SpotubeSimpleAlbumObject.fromJson(
                json.cast<String, dynamic>(),
              );
            } else {
              return SpotubeFullArtistObject.fromJson(
                json.cast<String, dynamic>(),
              );
            }
          },
        ),
      );
    } catch (e) {
      return SpotubePaginationResponseObject<
          SpotubeBrowseSectionObject<Object>>(
        items: [],
        total: 0,
        nextOffset: null,
        limit: limit ?? 20,
        hasMore: false,
      );
    }
  }

  Future<SpotubePaginationResponseObject<Object>> sectionItems(
    String id, {
    int? offset,
    int? limit,
  }) async {
    try {
      final raw = await hetuMetadataBrowse.invoke(
        "sectionItems",
        positionalArgs: [id],
        namedArgs: {
          "offset": offset,
          "limit": limit,
        }..removeWhere((key, value) => value == null),
      );

      if (raw is! Map) {
        return SpotubePaginationResponseObject<Object>(
          items: [],
          total: 0,
          limit: limit ?? 20,
          hasMore: false,
          nextOffset: null,
        );
      }

      return SpotubePaginationResponseObject<Object>.fromJson(
        raw.cast<String, dynamic>(),
        (json) {
          final isPlaylist = json["owner"] != null;
          final isAlbum = json["artists"] != null;
          if (isPlaylist) {
            return SpotubeSimplePlaylistObject.fromJson(
              json.cast<String, dynamic>(),
            );
          } else if (isAlbum) {
            return SpotubeSimpleAlbumObject.fromJson(
              json.cast<String, dynamic>(),
            );
          } else {
            return SpotubeFullArtistObject.fromJson(
              json.cast<String, dynamic>(),
            );
          }
        },
      );
    } catch (e) {
      return SpotubePaginationResponseObject<Object>(
        items: [],
        total: 0,
        limit: limit ?? 20,
        hasMore: false,
        nextOffset: null,
      );
    }
  }
}
