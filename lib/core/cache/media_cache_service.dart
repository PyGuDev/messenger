import 'package:flutter_cache_manager/flutter_cache_manager.dart' hide FileService;
import '../network/file_service.dart';
import '../security/token_storage.dart';

class MediaCacheService {
  final FileService _fileService;
  final TokenStorage _tokenStorage;
  final CacheManager _cacheManager;

  MediaCacheService(this._fileService, this._tokenStorage)
      : _cacheManager = CacheManager(
          Config(
            'messengerMediaCache',
            stalePeriod: const Duration(days: 14),
            maxNrOfCacheObjects: 1000,
          ),
        );

  Future<FileInfo?> getFileFromCache(String accessKey) async {
    final url = _fileService.getDownloadUrl(accessKey);
    return await _cacheManager.getFileFromCache(url);
  }

  Future<FileInfo> downloadFile(String accessKey) async {
    final url = _fileService.getDownloadUrl(accessKey);
    final token = await _tokenStorage.getAccessToken();
    final headers = token != null ? {'Authorization': 'Bearer $token'} : <String, String>{};
    return await _cacheManager.downloadFile(url, authHeaders: headers);
  }

  Stream<FileResponse> getFileStream(String accessKey) async* {
    final url = _fileService.getDownloadUrl(accessKey);
    final token = await _tokenStorage.getAccessToken();
    final headers = token != null ? {'Authorization': 'Bearer $token'} : <String, String>{};
    yield* _cacheManager.getFileStream(url, headers: headers, withProgress: true);
  }
  
  // Optionally clear cache
  Future<void> clearCache() async {
    await _cacheManager.emptyCache();
  }
}
