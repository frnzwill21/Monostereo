import 'package:flutter_test/flutter_test.dart';
import 'package:hetu_script/hetu_script.dart';
import 'package:spotube/services/metadata/endpoints/user.dart';

void main() {
  group('MetadataPluginUserEndpoint Adversarial Null Safety Tests', () {
    test('handles missing or uninitialized plugin gracefully without uncaught exceptions', () async {
      final hetu = Hetu();
      hetu.init();
      // "metadataPlugin" is not defined in Hetu environment
      final endpoint = MetadataPluginUserEndpoint(hetu);

      expect(await endpoint.me(), isNull);

      final tracks = await endpoint.savedTracks();
      expect(tracks.items, isEmpty);
      expect(tracks.total, 0);

      final playlists = await endpoint.savedPlaylists();
      expect(playlists.items, isEmpty);
      expect(playlists.total, 0);

      final albums = await endpoint.savedAlbums();
      expect(albums.items, isEmpty);
      expect(albums.total, 0);

      final artists = await endpoint.savedArtists();
      expect(artists.items, isEmpty);
      expect(artists.total, 0);

      expect(await endpoint.isSavedPlaylist('pl-1'), isFalse);
      expect(await endpoint.isSavedTracks(['t-1', 't-2']), [false, false]);
      expect(await endpoint.isSavedAlbums(['a-1']), [false]);
      expect(await endpoint.isSavedArtists(['ar-1']), [false]);
    });

    test('handles null or malformed data returned by Hetu script', () async {
      final hetu = Hetu();
      hetu.init();

      hetu.eval('''
        class MockUser {
          fun me() {
            return null
          }
          fun savedTracks({offset, limit}) {
            return null
          }
          fun savedPlaylists({offset, limit}) {
            return "not a map"
          }
          fun savedAlbums({offset, limit}) {
            return 12345
          }
          fun savedArtists({offset, limit}) {
            return [1, 2, 3]
          }
          fun isSavedPlaylist(id) {
            return null
          }
          fun isSavedTracks(ids) {
            return null
          }
          fun isSavedAlbums(ids) {
            return "not a list"
          }
          fun isSavedArtists(ids) {
            return [true, false]
          }
        }

        class MockPlugin {
          var user = MockUser()
        }

        var metadataPlugin = MockPlugin()
      ''');

      final endpoint = MetadataPluginUserEndpoint(hetu);

      expect(await endpoint.me(), isNull);

      final tracks = await endpoint.savedTracks();
      expect(tracks.items, isEmpty);
      expect(tracks.total, 0);

      final playlists = await endpoint.savedPlaylists();
      expect(playlists.items, isEmpty);
      expect(playlists.total, 0);

      final albums = await endpoint.savedAlbums();
      expect(albums.items, isEmpty);
      expect(albums.total, 0);

      final artists = await endpoint.savedArtists();
      expect(artists.items, isEmpty);
      expect(artists.total, 0);

      expect(await endpoint.isSavedPlaylist('p1'), isFalse);
      expect(await endpoint.isSavedTracks(['t1', 't2']), [false, false]);
      expect(await endpoint.isSavedAlbums(['a1']), [false]);
      expect(await endpoint.isSavedArtists(['ar1', 'ar2']), [true, false]);
    });

    test('handles malformed Map data in user objects and pagination responses', () async {
      final hetu = Hetu();
      hetu.init();

      hetu.eval('''
        class MalformedMapUser {
          fun me() {
            return {"completely_invalid_key": 999}
          }
          fun savedTracks({offset, limit}) {
            return {"items": "not a list", "total": "not an int"}
          }
          fun savedPlaylists({offset, limit}) {
            return {"items": [1, 2, 3]}
          }
          fun savedAlbums({offset, limit}) {
            return {"items": null}
          }
          fun savedArtists({offset, limit}) {
            return {"items": 123}
          }
          fun isSavedPlaylist(id) {
            return "not a bool"
          }
          fun isSavedTracks(ids) {
            return ["not", "bools"]
          }
        }

        class MockPlugin {
          var user = MalformedMapUser()
        }

        var metadataPlugin = MockPlugin()
      ''');

      final endpoint = MetadataPluginUserEndpoint(hetu);

      // SpotubeUserObject.fromJson on invalid structure should be caught and return null
      final user = await endpoint.me();
      // Either user returns null (due to exception in fromJson) or handles gracefully
      // Let's verify no uncaught exception occurs:
      expect(user, isNull);

      final tracks = await endpoint.savedTracks();
      expect(tracks.items, isEmpty);

      final playlists = await endpoint.savedPlaylists();
      expect(playlists.items, isEmpty);

      final albums = await endpoint.savedAlbums();
      expect(albums.items, isEmpty);

      final artists = await endpoint.savedArtists();
      expect(artists.items, isEmpty);

      // isSavedPlaylist returns raw == true, so "not a bool" == true is false
      expect(await endpoint.isSavedPlaylist('pl-1'), isFalse);

      // Edge case: if Hetu returns a list of non-bools, does accessing elements throw TypeError?
      final nonBoolList = await endpoint.isSavedTracks(['t1', 't2']);
      expect(() => nonBoolList.first, throwsA(isA<TypeError>()));
    });

    test('handles Hetu exceptions (e.g. unauthenticated network error) gracefully', () async {
      final hetu = Hetu();
      hetu.init();

      hetu.eval('''
        class FailingUser {
          fun me() {
            throw "Unauthorized / Guest user"
          }
          fun savedTracks({offset, limit}) {
            throw "Unauthorized"
          }
          fun savedPlaylists({offset, limit}) {
            throw "Unauthorized"
          }
          fun savedAlbums({offset, limit}) {
            throw "Unauthorized"
          }
          fun savedArtists({offset, limit}) {
            throw "Unauthorized"
          }
          fun isSavedPlaylist(id) {
            throw "Error"
          }
          fun isSavedTracks(ids) {
            throw "Error"
          }
          fun isSavedAlbums(ids) {
            throw "Error"
          }
          fun isSavedArtists(ids) {
            throw "Error"
          }
        }

        class MockPlugin {
          var user = FailingUser()
        }

        var metadataPlugin = MockPlugin()
      ''');

      final endpoint = MetadataPluginUserEndpoint(hetu);

      expect(await endpoint.me(), isNull);
      expect((await endpoint.savedTracks()).items, isEmpty);
      expect((await endpoint.savedPlaylists()).items, isEmpty);
      expect((await endpoint.savedAlbums()).items, isEmpty);
      expect((await endpoint.savedArtists()).items, isEmpty);
      expect(await endpoint.isSavedPlaylist('p1'), isFalse);
      expect(await endpoint.isSavedTracks(['t1', 't2']), [false, false]);
      expect(await endpoint.isSavedAlbums(['a1']), [false]);
      expect(await endpoint.isSavedArtists(['ar1']), [false]);
    });
  });
}
