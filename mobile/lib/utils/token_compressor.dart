import 'dart:convert';
import 'dart:io';

class TokenCompressor {
  /// Compresses a raw string into a Base64 encoded GZIP string.
  /// Typically achieves 60-70% reduction on text-heavy CBT logs.
  static String compressText(String rawText) {
    try {
      final bytes = utf8.encode(rawText);
      final compressedBytes = gzip.encode(bytes);
      return base64Encode(compressedBytes);
    } catch (e) {
      print('[Compression Error]: Failed to compress token payload - $e');
      return rawText; // Fallback to raw if compression fails
    }
  }

  /// Decompresses a Base64 encoded GZIP string back to raw text.
  static String decompressText(String compressedBase64) {
    try {
      final bytes = base64Decode(compressedBase64);
      final decompressedBytes = gzip.decode(bytes);
      return utf8.decode(decompressedBytes);
    } catch (e) {
      print('[Decompression Error]: Failed to decompress token payload - $e');
      return compressedBase64; // Fallback in case it wasn't compressed
    }
  }
}