import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum DataType {
  attendance,
  absoluteAttendance,
  profile,
}

class Functions {
  static Future<String> getImageFileFromAssets(
    String path,
  ) async {
    final byteData = await rootBundle.load(
      'assets/$path',
    );

    final file = File(
      '${(await getTemporaryDirectory()).path}/$path',
    );

    await file.create(recursive: true);

    await file.writeAsBytes(
      byteData.buffer.asUint8List(
        byteData.offsetInBytes,
        byteData.lengthInBytes,
      ),
    );

    return file.path;
  }

  static Future<String> downloadFile(
    String imageUrl, {
    String? referrer,
  }) async {
    final headers = {
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
          'AppleWebKit/537.36 Chrome/120.0.6099.119 '
          'Safari/537.36',
    };

    if (referrer != null) {
      headers['Referer'] = referrer;
    }

    final fileInfo =
        await DefaultCacheManager().downloadFile(
      imageUrl,
      authHeaders: headers,
    );

    return fileInfo.file.path;
  }

  static Future<String> performOcr(
    String imagePath,
  ) async {
    return FlutterTesseractOcr.extractText(
      imagePath,
      language: 'mydigits',
      args: {
        'psm': '11',
      },
    );
  }

  static Future<void> saveJsonToFile(
    String jsonData,
    DataType dataType,
  ) async {
    final appDir =
        await getApplicationDocumentsDirectory();

    late final String filePath;
    late final String prefKey;

    switch (dataType) {
      case DataType.attendance:
        filePath = appDir.absolute.uri
            .resolve('attendance.json')
            .toFilePath();
        prefKey = 'attendanceDataLastUpdated';
        break;

      case DataType.absoluteAttendance:
        filePath = appDir.absolute.uri
            .resolve('subjectWiseAttendance.json')
            .toFilePath();
        prefKey =
            'subjectWiseAttendanceDataLastUpdated';
        break;

      case DataType.profile:
        filePath = appDir.absolute.uri
            .resolve('profile.json')
            .toFilePath();
        prefKey = 'profileDataLastUpdated';
        break;
    }

    final file = File(filePath);

    await file.writeAsString(jsonData);

    final prefs =
        await SharedPreferences.getInstance();

    final date =
        DateFormat('dd MMM, yyyy HH:mm')
            .format(DateTime.now());

    await prefs.setString(prefKey, date);
  }

  static Future<dynamic> getJsonFromFile(
    DataType dataType,
  ) async {
    final appDir =
        await getApplicationDocumentsDirectory();

    late final String filePath;

    switch (dataType) {
      case DataType.attendance:
        filePath = appDir.absolute.uri
            .resolve('attendance.json')
            .toFilePath();
        break;

      case DataType.absoluteAttendance:
        filePath = appDir.absolute.uri
            .resolve('subjectWiseAttendance.json')
            .toFilePath();
        break;

      case DataType.profile:
        filePath = appDir.absolute.uri
            .resolve('profile.json')
            .toFilePath();
        break;
    }

    final file = File(filePath);

    final jsonData =
        await file.readAsString();

    final data = jsonDecode(jsonData);

    switch (dataType) {
      case DataType.attendance:
        return data as Map<String, dynamic>;

      case DataType.absoluteAttendance:
        return data as Map<String, dynamic>;

      case DataType.profile:
        return (data as Map<String, dynamic>).map(
          (key, value) =>
              MapEntry(key, value.toString()),
        );
    }
  }
}

String cleanUrlKey(String input) {
  final words = input
      .replaceAll(
        RegExp(r'[^a-zA-Z0-9\s]'),
        '',
      )
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .toList();

  if (words.isEmpty) {
    return '';
  }

  return words.join('').toLowerCase();
}
