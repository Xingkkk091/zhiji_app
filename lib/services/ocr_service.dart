import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// 用 Google ML Kit 對截圖做 OCR，自動嘗試中、日、韓、拉丁文，取最長結果。
class OcrService {
  static Future<String> recognize(String imagePath) async {
    final file = File(imagePath);
    if (!await file.exists()) return '';
    final input = InputImage.fromFilePath(imagePath);

    final scripts = [
      TextRecognitionScript.chinese,
      TextRecognitionScript.latin,
      TextRecognitionScript.japanese,
      TextRecognitionScript.korean,
    ];

    String best = '';
    for (final s in scripts) {
      final r = TextRecognizer(script: s);
      try {
        final result = await r.processImage(input);
        final text = result.text.trim();
        if (text.length > best.length) best = text;
      } catch (_) {
        // 該語系不可用就跳過
      } finally {
        await r.close();
      }
    }
    return best;
  }
}
