import 'package:flutter/services.dart';

/// Direct Phone Storage File CRUD Service:
/// Create, write, read, edit, list, and delete files on device storage (Downloads, Documents, etc.)
/// without navigating through phone settings or file manager apps.
class PhoneStorageService {
  PhoneStorageService._();
  static final PhoneStorageService instance = PhoneStorageService._();

  static const MethodChannel _channel = MethodChannel('com.privateagent/accessibility');

  Future<Map<String, dynamic>> createFile({
    required String fileName,
    required String content,
    String folder = 'Download',
    bool append = false,
  }) async {
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>('manageStorageFile', {
        'action': append ? 'edit' : 'create',
        'folder': folder,
        'fileName': fileName,
        'content': content,
        'append': append,
      });
      return res ?? {'success': false, 'message': 'Storage invocation returned null.'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> readFile({
    required String fileName,
    String folder = 'Download',
  }) async {
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>('manageStorageFile', {
        'action': 'read',
        'folder': folder,
        'fileName': fileName,
      });
      return res ?? {'success': false, 'message': 'File not accessible.'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> listFiles({String folder = 'Download'}) async {
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>('manageStorageFile', {
        'action': 'list',
        'folder': folder,
      });
      return res ?? {'success': false, 'files': []};
    } catch (e) {
      return {'success': false, 'files': [], 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> deleteFile({
    required String fileName,
    String folder = 'Download',
  }) async {
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>('manageStorageFile', {
        'action': 'delete',
        'folder': folder,
        'fileName': fileName,
      });
      return res ?? {'success': false, 'message': 'Delete failed.'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}

