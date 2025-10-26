import 'dart:typed_data';

import 'package:auto_route/auto_route.dart';
import 'package:hetu_otp_util/hetu_otp_util.dart';
import 'package:hetu_script/hetu_script.dart';
import 'package:hetu_script/values.dart';
import 'package:hetu_script/binding.dart';
import 'package:hetu_spotube_plugin/hetu_spotube_plugin.dart' as spotube_plugin;
import 'package:hetu_spotube_plugin/hetu_spotube_plugin.dart'
    hide YouTubeEngine;
import 'package:hetu_std/hetu_std.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spotube/collections/routes.dart';
import 'package:spotube/collections/routes.gr.dart';
import 'package:spotube/components/titlebar/titlebar.dart';
import 'package:spotube/models/metadata/metadata.dart';
import 'package:spotube/services/metadata/apis/localstorage.dart';
import 'package:spotube/services/metadata/endpoints/album.dart';
import 'package:spotube/services/metadata/endpoints/artist.dart';
import 'package:spotube/services/metadata/endpoints/audio_source.dart';
import 'package:spotube/services/metadata/endpoints/auth.dart';
import 'package:spotube/services/metadata/endpoints/browse.dart';
import 'package:spotube/services/metadata/endpoints/playlist.dart';
import 'package:spotube/services/metadata/endpoints/search.dart';
import 'package:spotube/services/metadata/endpoints/track.dart';
import 'package:spotube/services/metadata/endpoints/core.dart';
import 'package:spotube/services/metadata/endpoints/user.dart';
import 'package:spotube/services/youtube_engine/youtube_engine.dart';

const defaultMetadataLimit = "20";

class MetadataPlugin {
  static final pluginApiVersion = Version.parse("2.0.0");

  static Future<MetadataPlugin> create(
    YouTubeEngine youtubeEngine,
    PluginConfiguration config,
    Uint8List byteCode,
  ) async {
    final sharedPreferences = await SharedPreferences.getInstance();
    BuildContext? pageContext;

    final hetu = Hetu();
    hetu.init();

    hetu.interpreter.bindExternalClass(
      _PatchedFutureClassBinding(),
      override: true,
    );

    HetuStdLoader.loadBindings(hetu);
    HetuSpotubePluginLoader.loadBindings(
      hetu,
      localStorageImpl: SharedPreferencesLocalStorage(
        sharedPreferences,
        config.slug,
      ),
      onNavigatorPush: (route) {
        return rootNavigatorKey.currentContext?.router
            .pushWidget(Builder(builder: (context) {
          pageContext = context;
          return Scaffold(
            headers: const [
              TitleBar(
                automaticallyImplyLeading: true,
              )
            ],
            child: route,
          );
        }));
      },
      onNavigatorPop: () {
        pageContext?.maybePop();
      },
      onShowForm: (title, fields) async {
        if (rootNavigatorKey.currentContext == null) {
          return [];
        }

        return await rootNavigatorKey.currentContext!.router
            .push<List<Map<String, dynamic>>?>(
          SettingsMetadataProviderFormRoute(
            title: title,
            fields:
                fields.map((e) => MetadataFormFieldObject.fromJson(e)).toList(),
          ),
        );
      },
      createYoutubeEngine: () {
        return spotube_plugin.YouTubeEngine(
          search: (query) async {
            final result = await youtubeEngine.searchVideos(query);
            return result
                .map((video) => {
                      'id': video.id.value,
                      'title': video.title,
                      'author': video.author,
                      'duration': video.duration?.inSeconds,
                      'description': video.description,
                      'uploadDate': video.uploadDate?.toIso8601String(),
                      'viewCount': video.engagement.viewCount,
                      'likeCount': video.engagement.likeCount,
                      'isLive': video.isLive,
                    })
                .toList();
          },
          getVideo: (videoId) async {
            final video = await youtubeEngine.getVideo(videoId);
            return {
              'id': video.id.value,
              'title': video.title,
              'author': video.author,
              'duration': video.duration?.inSeconds,
              'description': video.description,
              'uploadDate': video.uploadDate?.toIso8601String(),
              'viewCount': video.engagement.viewCount,
              'likeCount': video.engagement.likeCount,
              'isLive': video.isLive,
            };
          },
          streamManifest: (videoId) {
            return youtubeEngine.getStreamManifest(videoId).then(
              (manifest) {
                final streams = manifest.audioOnly
                    .map(
                      (stream) => {
                        'url': stream.url.toString(),
                        'quality': stream.qualityLabel,
                        'bitrate': stream.bitrate.bitsPerSecond,
                        'container': stream.container.name,
                        'videoId': stream.videoId,
                      },
                    )
                    .toList();
                return streams;
              },
            );
          },
        );
      },
    );

    await HetuStdLoader.loadBytecodeFlutter(hetu);
    await HetuOtpUtilLoader.loadBytecodeFlutter(hetu);
    await HetuSpotubePluginLoader.loadBytecodeFlutter(hetu);

    hetu.interpreter.bindExternalClass(
      _PatchedFutureClassBinding(),
      override: true,
    );
    hetu.eval('''
      external class Future {
        construct (callback: any)
        static fun wait(futures: any)
        static fun value(val: any)
        fun then(callback: any)
        fun catchError(callback: any)
      }
    ''');

    hetu.loadBytecode(bytes: byteCode, moduleName: "plugin");
    hetu.eval("""
      import "module:plugin" as plugin

      var Plugin = plugin.${config.entryPoint}

      var metadataPlugin = Plugin()
      """);

    return MetadataPlugin._(hetu);
  }

  final Hetu hetu;

  late final MetadataAuthEndpoint auth;

  late final MetadataPluginAudioSourceEndpoint audioSource;
  late final MetadataPluginAlbumEndpoint album;
  late final MetadataPluginArtistEndpoint artist;
  late final MetadataPluginBrowseEndpoint browse;
  late final MetadataPluginSearchEndpoint search;
  late final MetadataPluginPlaylistEndpoint playlist;
  late final MetadataPluginTrackEndpoint track;
  late final MetadataPluginUserEndpoint user;
  late final MetadataPluginCore core;

  MetadataPlugin._(this.hetu) {
    auth = MetadataAuthEndpoint(hetu);

    audioSource = MetadataPluginAudioSourceEndpoint(hetu);
    artist = MetadataPluginArtistEndpoint(hetu);
    album = MetadataPluginAlbumEndpoint(hetu);
    browse = MetadataPluginBrowseEndpoint(hetu);
    search = MetadataPluginSearchEndpoint(hetu);
    playlist = MetadataPluginPlaylistEndpoint(hetu);
    track = MetadataPluginTrackEndpoint(hetu);
    user = MetadataPluginUserEndpoint(hetu);
    core = MetadataPluginCore(hetu);
  }
}

class _PatchedFutureClassBinding extends HTExternalClass {
  _PatchedFutureClassBinding() : super('Future');

  @override
  dynamic memberGet(String varName, {String? from}) {
    switch (varName) {
      case 'Future':
        return (HTEntity entity,
            {List<dynamic> positionalArgs = const [],
            Map<String, dynamic> namedArgs = const {},
            List<HTType> typeArgs = const []}) {
          final HTFunction func = positionalArgs.first;
          return Future(() => func.call());
        };
      case 'Future.wait':
        return (HTEntity entity,
            {List<dynamic> positionalArgs = const [],
            Map<String, dynamic> namedArgs = const {},
            List<HTType> typeArgs = const []}) {
          final futures = List<Future<dynamic>>.from(positionalArgs.first);
          return Future.wait(futures);
        };
      case 'Future.value':
        return (HTEntity entity,
            {List<dynamic> positionalArgs = const [],
            Map<String, dynamic> namedArgs = const {},
            List<HTType> typeArgs = const []}) {
          return Future.value(positionalArgs.first);
        };
      default:
        throw HTError.undefined(varName);
    }
  }

  @override
  dynamic instanceMemberGet(dynamic object, String varName) {
    final future = object as Future;
    switch (varName) {
      case 'then':
        return (HTEntity entity,
            {List<dynamic> positionalArgs = const [],
            Map<String, dynamic> namedArgs = const {},
            List<HTType> typeArgs = const []}) {
          final HTFunction func = positionalArgs.first;
          return future.then((value) => func.call(positionalArgs: [value]));
        };
      case 'catchError':
        return (HTEntity entity,
            {List<dynamic> positionalArgs = const [],
            Map<String, dynamic> namedArgs = const {},
            List<HTType> typeArgs = const []}) {
          final HTFunction func = positionalArgs.first;
          return future.catchError(
              (error, stackTrace) => func.call(positionalArgs: [error]));
        };
      default:
        throw HTError.undefined(varName);
    }
  }
}

