import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:spotube/components/fallbacks/error_box.dart';
import 'package:spotube/components/inter_scrollbar/inter_scrollbar.dart';
import 'package:spotube/extensions/context.dart';
import 'package:spotube/modules/search/loading.dart';
import 'package:spotube/pages/search/search.dart';
import 'package:spotube/modules/search/sections/albums.dart';
import 'package:spotube/modules/search/sections/artists.dart';
import 'package:spotube/modules/search/sections/playlists.dart';
import 'package:spotube/modules/search/sections/tracks.dart';
import 'package:spotube/provider/metadata_plugin/search/all.dart';

class SearchPageAllTab extends HookConsumerWidget {
  const SearchPageAllTab({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final scrollController = ScrollController();
    final searchTerm = ref.watch(searchTermStateProvider);
    final searchSnapshot =
        ref.watch(metadataPluginSearchAllProvider(searchTerm));

    if (searchSnapshot.hasError) {
      return ErrorBox(
        error: searchSnapshot.error!,
        onRetry: () {
          ref.invalidate(metadataPluginSearchAllProvider(searchTerm));
        },
      );
    }

    final results = searchSnapshot.asData?.value;
    final isEmpty = results != null &&
        results.tracks.isEmpty &&
        results.playlists.isEmpty &&
        results.artists.isEmpty &&
        results.albums.isEmpty;

    return SearchPlaceholder(
      snapshot: searchSnapshot,
      child: isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Text(
                  context.l10n.nothing_found,
                  style: TextStyle(
                    fontSize: 16,
                    color: Theme.of(context)
                        .colorScheme
                        .foreground
                        .withValues(alpha: 0.6),
                  ),
                ),
              ),
            )
          : InterScrollbar(
        controller: scrollController,
        child: SingleChildScrollView(
          controller: scrollController,
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SearchTracksSection(),
                  SearchPlaylistsSection(),
                  Gap(20),
                  SearchArtistsSection(),
                  Gap(20),
                  SearchAlbumsSection(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
