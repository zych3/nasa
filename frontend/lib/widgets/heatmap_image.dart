import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../models/overlay_heatmap.dart';

/// Image of an [OverlayHeatmap] for the map (`OverlayImageLayer`), made from
/// [heatmapPixels] on the device: no image file, no extra request.
///
/// Equal when it shows the same [heatmap] object, so a new heat map (another
/// overlay or month) is a new image, and the same one is not drawn again on
/// every rebuild.
@immutable
class HeatmapImageProvider extends ImageProvider<HeatmapImageProvider> {
  const HeatmapImageProvider(this.heatmap);

  /// Pixels per cell is enough: the map smooths the image when it scales it.
  static const pixelsPerCell = 24;

  final OverlayHeatmap heatmap;

  int get width => heatmap.cols * pixelsPerCell;
  int get height => heatmap.rows * pixelsPerCell;

  @override
  bool operator ==(Object other) =>
      other is HeatmapImageProvider && identical(other.heatmap, heatmap);

  @override
  int get hashCode => identityHashCode(heatmap);

  @override
  Future<HeatmapImageProvider> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
    HeatmapImageProvider key,
    ImageDecoderCallback decode,
  ) => OneFrameImageStreamCompleter(_decode());

  Future<ImageInfo> _decode() async {
    final Uint8List pixels = heatmapPixels(
      heatmap,
      width: width,
      height: height,
    );
    final buffer = await ui.ImmutableBuffer.fromUint8List(pixels);
    final descriptor = ui.ImageDescriptor.raw(
      buffer,
      width: width,
      height: height,
      pixelFormat: ui.PixelFormat.rgba8888,
    );
    final codec = await descriptor.instantiateCodec();
    final frame = await codec.getNextFrame();
    descriptor.dispose();
    buffer.dispose();
    codec.dispose();
    return ImageInfo(image: frame.image, debugLabel: 'heatmap');
  }
}
