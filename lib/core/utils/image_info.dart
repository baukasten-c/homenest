import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

/// 通过 ImageStream 解码图片，返回 width / height。
/// 用于 AspectRatio，保证照片完整显示且点击坐标精准。
Future<double> getImageAspectRatio(String url) async {
  final provider = NetworkImage(url);
  final completer = Completer<ui.Image>();
  final stream = provider.resolve(ImageConfiguration.empty);

  late final ImageStreamListener listener;
  listener = ImageStreamListener(
    (info, _) {
      if (!completer.isCompleted) completer.complete(info.image);
      stream.removeListener(listener);
    },
    onError: (e, s) {
      if (!completer.isCompleted) completer.completeError(e, s);
      stream.removeListener(listener);
    },
  );

  stream.addListener(listener);
  final image = await completer.future;
  return image.width / image.height;
}