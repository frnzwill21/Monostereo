import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:spotube/models/metadata/metadata.dart';
import 'package:spotube/provider/metadata_plugin/metadata_plugin_provider.dart';
import 'package:spotube/provider/search_engine/search_engine_provider.dart';
import 'package:spotube/services/metadata/errors/exceptions.dart';
import 'package:spotube/services/youtube_engine/youtube_search_service.dart';

final metadataPluginSearchAllProvider =
    FutureProvider.autoDispose.family<SpotubeSearchResponseObject, String>(
  (ref, query) async {
    final searchEngine = ref.watch(searchEngineModeProvider);
    if (searchEngine == SearchEngineMode.youtube) {
      return await ref.read(youtubeSearchServiceProvider).searchAll(query);
    }

    final metadataPlugin = await ref.watch(metadataPluginProvider.future);

    if (metadataPlugin == null) {
      throw MetadataPluginException.noDefaultMetadataPlugin();
    }

    return metadataPlugin.search.all(query);
  },
);

final metadataPluginSearchChipsProvider = FutureProvider((ref) async {
  final metadataPlugin = await ref.watch(metadataPluginProvider.future);

  if (metadataPlugin == null) {
    throw MetadataPluginException.noDefaultMetadataPlugin();
  }
  return metadataPlugin.search.chips;
});
