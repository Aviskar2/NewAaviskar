import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../models/scan_result_model.dart';

/// Service that wraps google_mlkit_text_recognition.
/// Uses Latin script (covers English, romanised Indian languages, printed docs).
/// For best results, use high-quality, well-lit images.
class OcrService {
  // Latin-script recogniser covers English and most printed documents.
  // ML Kit automatically detects Latin text regardless of source language.
  final TextRecognizer _recognizer =
      TextRecognizer(script: TextRecognitionScript.latin);

  /// Recognise text from a file at [path].
  Future<OcrResult> recognizeFromPath(String path) async {
    final inputImage = InputImage.fromFilePath(path);
    return _runRecognition(inputImage, path);
  }

  /// Recognise text from an [InputImage] (e.g. from camera stream).
  Future<OcrResult> recognizeFromInputImage(
    InputImage inputImage,
    String imagePath,
  ) async {
    return _runRecognition(inputImage, imagePath);
  }

  Future<OcrResult> _runRecognition(
    InputImage inputImage,
    String imagePath,
  ) async {
    final recognized = await _recognizer.processImage(inputImage);
    return OcrResult.fromMlKit(recognized, imagePath);
  }

  /// Returns true if the file at [path] exists and is a supported image type.
  bool isSupportedImage(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.bmp') ||
        lower.endsWith('.gif');
  }

  /// Check file exists before passing to ML Kit (avoids cryptic errors).
  Future<void> validateFile(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw Exception('Image file not found: $path');
    }
  }

  /// Release all recognizer resources. Call this in dispose().
  Future<void> close() async {
    await _recognizer.close();
  }
}
