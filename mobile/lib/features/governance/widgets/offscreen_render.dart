import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Lay out and paint [child] outside the visible tree and return it as an image.
/// Used for PDFs that need Flutter's text shaping (Devanagari conjuncts / matras),
/// the same reason the web renders the charter with html2canvas.
/// Images inside [child] must already be decoded (use [RawImage]).
Future<ui.Image> renderWidgetToImage(
  BuildContext context,
  Widget child, {
  required double width,
  double pixelRatio = 2,
}) async {
  final boundary = RenderRepaintBoundary();
  final view = View.of(context);
  final renderView = RenderView(
    view: view,
    child: RenderPositionedBox(alignment: Alignment.topLeft, child: boundary),
    configuration: ViewConfiguration(
      logicalConstraints: BoxConstraints(minWidth: width, maxWidth: width, maxHeight: 200000),
      physicalConstraints: BoxConstraints(minWidth: width, maxWidth: width, maxHeight: 200000),
    ),
  );
  final pipelineOwner = PipelineOwner()..rootNode = renderView;
  renderView.prepareInitialFrame();
  final buildOwner = BuildOwner(focusManager: FocusManager());
  final root = RenderObjectToWidgetAdapter<RenderBox>(
    container: boundary,
    child: MediaQuery(
      data: MediaQueryData(size: Size(width, 2000), textScaler: TextScaler.noScaling),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(width: width, child: child),
      ),
    ),
  ).attachToRenderTree(buildOwner);
  buildOwner.buildScope(root);
  buildOwner.finalizeTree();
  pipelineOwner.flushLayout();
  pipelineOwner.flushCompositingBits();
  pipelineOwner.flushPaint();
  final image = await boundary.toImage(pixelRatio: pixelRatio);
  // Tear the temporary tree down.
  RenderObjectToWidgetAdapter<RenderBox>(container: boundary).attachToRenderTree(buildOwner, root);
  buildOwner.buildScope(root);
  buildOwner.finalizeTree();
  return image;
}

/// Decode encoded image bytes (PNG/JPEG) synchronously usable by [RawImage].
Future<ui.Image?> decodeImageBytes(Uint8List? bytes) async {
  if (bytes == null || bytes.isEmpty) return null;
  try {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  } catch (_) {
    return null;
  }
}

/// Crop rows [top, top+height) of [src] into PNG bytes.
Future<Uint8List> cropToPng(ui.Image src, int top, int height) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final w = src.width.toDouble();
  canvas.drawRect(Rect.fromLTWH(0, 0, w, height.toDouble()), Paint()..color = const Color(0xFFFFFFFF));
  canvas.drawImageRect(
    src,
    Rect.fromLTWH(0, top.toDouble(), w, height.toDouble()),
    Rect.fromLTWH(0, 0, w, height.toDouble()),
    Paint(),
  );
  final img = await recorder.endRecording().toImage(src.width, height);
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  img.dispose();
  return data!.buffer.asUint8List();
}

Future<Uint8List> imageToPng(ui.Image image) async {
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

/// Page break rows for a tall white-background image: prefers a fully white row
/// within [lookBack] px above each ideal cut so text lines are not split.
Future<List<(int top, int height)>> pageSlices(ui.Image image, int sliceHeight, {int lookBack = 140}) async {
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final w = image.width;
  final h = image.height;
  bool whiteRow(int y) {
    if (data == null) return true;
    final rowStart = y * w * 4;
    for (var x = 0; x < w; x += 2) {
      final i = rowStart + x * 4;
      if (data.getUint8(i) < 245 || data.getUint8(i + 1) < 245 || data.getUint8(i + 2) < 245) return false;
    }
    return true;
  }

  final out = <(int, int)>[];
  var y = 0;
  while (y < h) {
    var end = y + sliceHeight;
    if (end >= h) {
      out.add((y, h - y));
      break;
    }
    for (var k = 0; k < lookBack && end - k > y + sliceHeight ~/ 2; k++) {
      if (whiteRow(end - k)) {
        end = end - k;
        break;
      }
    }
    out.add((y, end - y));
    y = end;
  }
  return out;
}
