import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:spotube/collections/assets.gen.dart';

class UniversalImage extends HookWidget {
  final String path;
  final double? height;
  final double? width;
  final double scale;
  final String? placeholder;
  final BoxFit? fit;
  const UniversalImage({
    required this.path,
    this.height,
    this.width,
    this.placeholder,
    this.fit,
    this.scale = 1,
    super.key,
  });

  static ImageProvider imageProvider(
    String path, {
    final double? height,
    final double? width,
    final double scale = 1,
    final String? placeholder,
  }) {
    if (path.isEmpty) {
      return AssetImage(placeholder ?? Assets.images.placeholder.path);
    }
    if (path.startsWith("http")) {
      final safeHeight = height != null
          ? (height * 2).toInt()
          : (width != null ? (width * 2).toInt() : 512);
      final safeWidth = width != null
          ? (width * 2).toInt()
          : (height != null ? (height * 2).toInt() : 512);
      return CachedNetworkImageProvider(
        path,
        maxHeight: safeHeight,
        maxWidth: safeWidth,
        cacheKey: path,
        scale: scale,
      );
    } else if (path.startsWith("assets/")) {
      return AssetImage(path);
    } else if (Uri.tryParse(path) != null && File(path).existsSync()) {
      return FileImage(File(path), scale: scale);
    }
    try {
      return MemoryImage(base64Decode(path), scale: scale);
    } catch (_) {
      return AssetImage(placeholder ?? Assets.images.placeholder.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (path.isEmpty) {
      return Image.asset(
        placeholder ?? Assets.images.placeholder.path,
        width: width,
        height: height,
        fit: fit,
      );
    }
    if (path.startsWith("http")) {
      final h = height;
      final w = width;
      final safeHeight = h != null
          ? (h * 2).toInt()
          : (w != null ? (w * 2).toInt() : 512);
      final safeWidth = w != null
          ? (w * 2).toInt()
          : (h != null ? (h * 2).toInt() : 512);
      return FadeInImage(
        image: CachedNetworkImageProvider(
          path,
          maxHeight: safeHeight,
          maxWidth: safeWidth,
          cacheKey: path,
          scale: scale,
        ),
        height: height,
        width: width,
        placeholder: AssetImage(placeholder ?? Assets.images.placeholder.path),
        imageErrorBuilder: (context, error, stackTrace) {
          return Image.asset(
            placeholder ?? Assets.images.placeholder.path,
            width: width,
            height: height,
            cacheHeight: safeHeight,
            cacheWidth: safeWidth,
            scale: scale,
          );
        },
        fit: fit,
      );
    } else if (Uri.tryParse(path) != null && !path.startsWith("assets")) {
      return Image.file(
        File(path),
        width: width,
        height: height,
        cacheHeight: height?.toInt(),
        cacheWidth: width?.toInt(),
        scale: scale,
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
          return Image.asset(
            placeholder ?? Assets.images.placeholder.path,
            width: width,
            height: height,
            cacheHeight: height?.toInt(),
            cacheWidth: width?.toInt(),
            scale: scale,
          );
        },
      );
    } else if (path.startsWith("assets")) {
      return Image.asset(
        path,
        width: width,
        height: height,
        cacheHeight: height?.toInt(),
        cacheWidth: width?.toInt(),
        scale: scale,
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
          return Image.asset(
            placeholder ?? Assets.images.placeholder.path,
            width: width,
            height: height,
            cacheHeight: height?.toInt(),
            cacheWidth: width?.toInt(),
            scale: scale,
          );
        },
      );
    }

    try {
      return Image.memory(
        base64Decode(path),
        width: width,
        height: height,
        cacheHeight: height?.toInt(),
        cacheWidth: width?.toInt(),
        scale: scale,
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
          return Image.asset(
            placeholder ?? Assets.images.placeholder.path,
            width: width,
            height: height,
            cacheHeight: height?.toInt(),
            cacheWidth: width?.toInt(),
            scale: scale,
          );
        },
      );
    } catch (_) {
      return Image.asset(
        placeholder ?? Assets.images.placeholder.path,
        width: width,
        height: height,
        cacheHeight: height?.toInt(),
        cacheWidth: width?.toInt(),
        scale: scale,
        fit: fit,
      );
    }
  }
}
