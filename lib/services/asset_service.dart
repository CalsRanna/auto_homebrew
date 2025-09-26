import 'dart:io';
import 'package:crypto/crypto.dart';

class AssetService {
  Future<AssetInfo> getAssetInfo(String path) async {
    final file = File(path);

    if (!await file.exists()) {
      throw AssetException('Asset file not found: $path');
    }

    final stat = await file.stat();
    final size = stat.size;
    final checksum = await _calculateSHA256(file);

    return AssetInfo(
      path: path,
      size: size,
      checksum: checksum,
      exists: true,
    );
  }

  
  Future<bool> createChecksumFile(String assetPath, String checksumPath) async {
    try {
      final assetFile = File(assetPath);
      final checksumFile = File(checksumPath);

      if (!await assetFile.exists()) {
        throw AssetException('Asset file not found: $assetPath');
      }

      final checksum = await _calculateSHA256(assetFile);
      final content = '$checksum  ${assetFile.uri.pathSegments.last}\n';

      await checksumFile.writeAsString(content);
      return true;
    } catch (e) {
      throw AssetException('Failed to create checksum file: $e');
    }
  }

  Future<String> _calculateSHA256(File file) async {
    final bytes = await file.readAsBytes();
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<bool> validateChecksum(String assetPath, String checksumPath) async {
    try {
      final assetFile = File(assetPath);
      final checksumFile = File(checksumPath);

      if (!await assetFile.exists()) {
        throw AssetException('Asset file not found: $assetPath');
      }

      if (!await checksumFile.exists()) {
        throw AssetException('Checksum file not found: $checksumPath');
      }

      final expectedChecksum = await _calculateSHA256(assetFile);
      final checksumContent = await checksumFile.readAsString();
      final actualChecksum = checksumContent.split(' ').first;

      return expectedChecksum == actualChecksum;
    } catch (e) {
      throw AssetException('Failed to validate checksum: $e');
    }
  }
}

class AssetInfo {
  final String path;
  final int size;
  final String checksum;
  final bool exists;

  AssetInfo({
    required this.path,
    this.size = 0,
    this.checksum = '',
    required this.exists,
  });

  @override
  String toString() {
    return 'AssetInfo(path: $path, size: $size, checksum: $checksum, exists: $exists)';
  }
}

class AssetException implements Exception {
  final String message;

  AssetException(this.message);

  @override
  String toString() => 'AssetException: $message';
}