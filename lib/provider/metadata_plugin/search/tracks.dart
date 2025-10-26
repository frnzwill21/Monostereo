import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:spotube/models/metadata/metadata.dart';
import 'package:spotube/provider/metadata_plugin/metadata_plugin_provider.dart';
import 'package:spotube/provider/metadata_plugin/utils/common.dart';
import 'package:spotube/provider/metadata_plugin/utils/family_paginated.dart';
import 'package:spotube/provider/search_engine/search_engine_provider.dart';
import 'package:spotube/services/youtube_engine/youtube_search_service.dart';

class MetadataPluginSearchTracksNotifier
    extends AutoDisposeFamilyPaginatedAsyncNotifier<SpotubeFullTrackObject,
        String> {
  MetadataPluginSearchTracksNotifier() : super();

  @override
  fetch(offset, limit) async {
    if (arg.isEmpty) {
      return SpotubePaginationResponseObject<SpotubeFullTrackObject>(
        limit: limit,
        nextOffset: null,
        total: 0,
        items: [],
        hasMore: false,
      );
    }

    final searchEngine = ref.read(searchEngineModeProvider);
    if (searchEngine == SearchEngineMode.youtube) {
      return await ref
          .read(youtubeSearchServiceProvider)
          .searchTracks(arg, offset: offset, limit: limit);
    }

    final tracks = await (await metadataPlugin).search.tracks(
          arg,
          offset: offset,
          limit: limit,
        );

    return tracks;
  }

  @override
  build(arg) async {
    ref.cacheFor();

    ref.watch(searchEngineModeProvider);
    ref.watch(metadataPluginProvider);
    return await fetch(0, 20);
  }
}

final metadataPluginSearchTracksProvider =
    AutoDisposeAsyncNotifierProviderFamily<MetadataPluginSearchTracksNotifier,
        SpotubePaginationResponseObject<SpotubeFullTrackObject>, String>(
  () => MetadataPluginSearchTracksNotifier(),
);
