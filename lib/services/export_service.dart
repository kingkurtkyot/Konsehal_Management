import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ExportService {
  /// Capture a widget from a RepaintBoundary key as PNG bytes
  static Future<List<int>?> captureWidget(GlobalKey key, {double pixelRatio = 3.0}) async {
    try {
      final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;

      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;
      return byteData.buffer.asUint8List();
    } catch (e) {
      debugPrint('Capture error: $e');
      return null;
    }
  }

  /// Save image bytes to gallery
  static Future<void> saveToGallery(List<int> bytes, String prefix) async {
    final tempDir = await getTemporaryDirectory();
    final fileName = '${prefix}_${DateTime.now().millisecondsSinceEpoch}.png';
    final file = File('${tempDir.path}/$fileName');
    await file.writeAsBytes(bytes);
    await Gal.putImage(file.path);
  }

  /// Share image bytes
  static Future<void> shareImage(List<int> bytes, String prefix, {String? text}) async {
    final tempDir = await getTemporaryDirectory();
    final fileName = '${prefix}_${DateTime.now().millisecondsSinceEpoch}.png';
    final file = File('${tempDir.path}/$fileName');
    await file.writeAsBytes(bytes);
    await Share.shareXFiles(
      [XFile(file.path)],
      text: text,
    );
  }

  /// Save image to app documents directory (persistent) and return the path
  static Future<String> saveToAppDocuments(List<int> bytes, String prefix) async {
    final appDir = await getApplicationDocumentsDirectory();
    final galleryDir = Directory('${appDir.path}/konsi_gallery');
    if (!await galleryDir.exists()) {
      await galleryDir.create(recursive: true);
    }
    final fileName = '${prefix}_${DateTime.now().millisecondsSinceEpoch}.png';
    final file = File('${galleryDir.path}/$fileName');
    await file.writeAsBytes(bytes);
    return file.path;
  }
}
