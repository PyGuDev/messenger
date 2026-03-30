import 'dart:io';
import 'package:dio/dio.dart';
import 'network_module.dart';

class UploadResponse {
  final String accessKey;
  final String fileId;
  final bool isDuplicate;

  UploadResponse({
    required this.accessKey,
    required this.fileId,
    required this.isDuplicate,
  });

  factory UploadResponse.fromJson(Map<String, dynamic> json) {
    return UploadResponse(
      accessKey: json['accessKey'] ?? '',
      fileId: json['fileId'] ?? '',
      isDuplicate: json['isDuplicate'] ?? false,
    );
  }
}

class FileService {
  final Dio _dio;

  FileService(this._dio);

  Future<UploadResponse> uploadFile(String filePath, String fileName) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('File does not exist: $filePath');
    }

    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: fileName),
    });

    final response = await _dio.post('/files', data: formData);

    if (response.statusCode == 201) {
      return UploadResponse.fromJson(response.data);
    } else {
      throw Exception(response.data['error'] ?? 'Failed to upload file');
    }
  }

  String getDownloadUrl(String accessKey) {
    return '${NetworkModule.fileBaseUrl}/files/$accessKey';
  }
}
