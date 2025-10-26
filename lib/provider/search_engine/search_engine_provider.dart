import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spotube/services/kv_store/kv_store.dart';

enum SearchEngineMode {
  youtube,
  musicbrainz,
}

class SearchEngineModeNotifier extends StateNotifier<SearchEngineMode> {
  SearchEngineModeNotifier()
      : super(
          KVStoreService.searchEngineMode == "musicbrainz"
              ? SearchEngineMode.musicbrainz
              : SearchEngineMode.youtube,
        );

  void setMode(SearchEngineMode mode) {
    state = mode;
    KVStoreService.setSearchEngineMode(mode.name);
  }

  void toggle() {
    setMode(
      state == SearchEngineMode.youtube
          ? SearchEngineMode.musicbrainz
          : SearchEngineMode.youtube,
    );
  }
}

final searchEngineModeProvider =
    StateNotifierProvider<SearchEngineModeNotifier, SearchEngineMode>((ref) {
  return SearchEngineModeNotifier();
});
