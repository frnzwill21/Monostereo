import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzywuzzy/fuzzywuzzy.dart';

void main() {
  group('Search Indexing and Suggestion Filtering', () {
    final recentSearches = [
      'Linkin Park',
      'Twenty One Pilots',
      'Coldplay - Viva La Vida',
      'Radiohead - Creep',
      'Kendrick Lamar',
      'Taylor Swift',
    ];

    List<String> getFilteredSuggestions(String query) {
      final text = query.trim().toLowerCase();
      if (text.isEmpty) return recentSearches;

      return recentSearches.where((s) {
        final sLower = s.toLowerCase();
        return sLower.contains(text) ||
            weightedRatio(sLower, text) > 50 ||
            partialRatio(sLower, text) > 65;
      }).toList();
    }

    test('exact substring match works', () {
      final results = getFilteredSuggestions('cold');
      expect(results, contains('Coldplay - Viva La Vida'));
    });

    test('fuzzy query matches correctly even with slight typos', () {
      final results = getFilteredSuggestions('Linken Prk');
      expect(results, contains('Linkin Park'));
    });

    test('partial ratio matches inner words', () {
      final results = getFilteredSuggestions('Vida');
      expect(results, contains('Coldplay - Viva La Vida'));
    });

    test('empty query returns all recent searches', () {
      final results = getFilteredSuggestions('   ');
      expect(results.length, equals(recentSearches.length));
    });
  });
}
