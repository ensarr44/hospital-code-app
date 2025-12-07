// lib/csv_importer.dart
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:csv/csv.dart';

/// Basit yardımcı: Timestamp/DateTime -> ISO
String _toIso(dynamic v) {
  if (v == null) return '';
  if (v is Timestamp) return v.toDate().toIso8601String();
  if (v is DateTime) return v.toIso8601String();
  if (v is String) return v;
  return v.toString();
}

class CsvImporter {
  /// Dosya seç, parse et, Firestore’a yaz.
  /// Başarılıysa true döner; UI SnackBar için kullanacağız.
  static Future<bool> pickAndImport(BuildContext context) async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );
      if (res == null || res.files.isEmpty) return false;

      final f = res.files.first;
      final fileName = (f.name ?? '').toLowerCase();

      final bytes = f.bytes ??
          await File(f.path!).readAsBytes(); // web/desktop/android farkı için
      final csvStr = utf8.decode(bytes);
      final rows = const CsvToListConverter(
        shouldParseNumbers: false,
      ).convert(csvStr);

      if (rows.isEmpty) return false;

      // İlk satır başlık kabul
      final header = rows.first.map((e) => e.toString().trim()).toList();
      final dataRows = rows.skip(1);

      // Hangi koleksiyon?
      if (fileName.contains('codes')) {
        await _importCodes(header, dataRows);
      } else if (fileName.contains('shifts')) {
        await _importShifts(header, dataRows);
      } else if (fileName.contains('nobet')) {
        await _importNobet(header, dataRows);
      } else if (fileName.contains('yayin')) {
        await _importYayin(header, dataRows);
      } else {
        // dosya adı tanınmadı
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Dosya adı codes/shifts/nobet/yayin içermiyor.')),
          );
        }
        return false;
      }

      return true;
    } catch (e, st) {
      debugPrint('CSV import hata: $e\n$st');
      return false;
    }
  }

  // --------- İÇE AKTARMA UYGULAMALARI ---------

  /// codes.csv:   color,message,createdAtISO,by
  static Future<void> _importCodes(List<String> h, Iterable<List> rows) async {
    final cRef = FirebaseFirestore.instance.collection('codes');
    final idx = {
      'color': h.indexOf('color'),
      'message': h.indexOf('message'),
      'createdAtISO': h.indexOf('createdAtISO'),
      'by': h.indexOf('by'),
    };
    for (final r in rows) {
      String color = _get(r, idx['color']);
      String message = _get(r, idx['message']);
      String createdAtISO = _get(r, idx['createdAtISO']);
      String by = _get(r, idx['by']);

      await cRef.add({
        'color': color,
        'message': message,
        'createdAt': createdAtISO.isEmpty
            ? FieldValue.serverTimestamp()
            : DateTime.tryParse(createdAtISO),
        'by': by,
      });
    }
  }

  /// shifts.csv:  date,staff  (staff virgülle ayrılmış id listesi, örn: "p1,p2,p3")
  static Future<void> _importShifts(List<String> h, Iterable<List> rows) async {
    final col = FirebaseFirestore.instance.collection('vardiya'); // ad: vardiya
    final idx = {
      'date': h.indexOf('date'),
      'staff': h.indexOf('staff'),
    };
    for (final r in rows) {
      final dateStr = _get(r, idx['date']);
      final staffStr = _get(r, idx['staff']);
      final staff = staffStr.isEmpty
          ? <String>[]
          : staffStr.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

      await col.add({
        'date': DateTime.tryParse(dateStr),
        'staff': staff,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// nobet.csv:   date,team  (ör: "2025-11-02, Gece")
  static Future<void> _importNobet(List<String> h, Iterable<List> rows) async {
    final col = FirebaseFirestore.instance.collection('nobet');
    final idx = {
      'date': h.indexOf('date'),
      'team': h.indexOf('team'),
    };
    for (final r in rows) {
      final dateStr = _get(r, idx['date']);
      final team = _get(r, idx['team']);
      await col.add({
        'date': DateTime.tryParse(dateStr),
        'team': team,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// yayin.csv:   title,body,createdAtISO
  static Future<void> _importYayin(List<String> h, Iterable<List> rows) async {
    final col = FirebaseFirestore.instance.collection('yayin');
    final idx = {
      'title': h.indexOf('title'),
      'body': h.indexOf('body'),
      'createdAtISO': h.indexOf('createdAtISO'),
    };
    for (final r in rows) {
      final title = _get(r, idx['title']);
      final body = _get(r, idx['body']);
      final createdAtISO = _get(r, idx['createdAtISO']);
      await col.add({
        'title': title,
        'body': body,
        'createdAt': createdAtISO.isEmpty
            ? FieldValue.serverTimestamp()
            : DateTime.tryParse(createdAtISO),
      });
    }
  }

  static String _get(List row, int? i) {
    if (i == null || i < 0 || i >= row.length) return '';
    final v = row[i];
    return v == null ? '' : v.toString();
  }

  // --------- DIŞA AKTAR (BACKUP) ---------

  /// Android’de CSV’leri `/sdcard/Download` altına yazar.
  /// Web/iOS için burada işlem yapılmıyor (gerekirse Share/Picker ile genişletilir).
  static Future<bool> exportAllToDownloads(BuildContext context) async {
    try {
      if (!Platform.isAndroid) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Dışa aktarma şu anda sadece Android için hazır.')),
          );
        }
        return false;
      }

      final downloadDir = Directory('/sdcard/Download');
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }

      // 1) codes
      {
        final q = await FirebaseFirestore.instance
            .collection('codes')
            .orderBy('createdAt', descending: false)
            .limit(1000)
            .get();
        final rows = <List<dynamic>>[
          ['color', 'message', 'createdAtISO', 'by']
        ];
        for (final d in q.docs) {
          final m = d.data();
          rows.add([
            m['color'] ?? '',
            m['message'] ?? '',
            _toIso(m['createdAt']),
            m['by'] ?? '',
          ]);
        }
        final csv = const ListToCsvConverter().convert(rows);
        await File('${downloadDir.path}/codes_export.csv').writeAsString(csv, encoding: utf8);
      }

      // 2) vardiya (shifts)
      {
        final q = await FirebaseFirestore.instance
            .collection('vardiya')
            .orderBy('date', descending: false)
            .limit(1000)
            .get();
        final rows = <List<dynamic>>[
          ['date', 'staff']
        ];
        for (final d in q.docs) {
          final m = d.data();
          final staff = (m['staff'] as List?)?.map((e) => e.toString()).join(',') ?? '';
          rows.add([
            _toIso(m['date']),
            staff,
          ]);
        }
        final csv = const ListToCsvConverter().convert(rows);
        await File('${downloadDir.path}/shifts_export.csv').writeAsString(csv, encoding: utf8);
      }

      // 3) nöbet
      {
        final q = await FirebaseFirestore.instance
            .collection('nobet')
            .orderBy('date', descending: false)
            .limit(1000)
            .get();
        final rows = <List<dynamic>>[
          ['date', 'team']
        ];
        for (final d in q.docs) {
          final m = d.data();
          rows.add([
            _toIso(m['date']),
            m['team'] ?? '',
          ]);
        }
        final csv = const ListToCsvConverter().convert(rows);
        await File('${downloadDir.path}/nobet_export.csv').writeAsString(csv, encoding: utf8);
      }

      // 4) yayın
      {
        final q = await FirebaseFirestore.instance
            .collection('yayin')
            .orderBy('createdAt', descending: false)
            .limit(1000)
            .get();
        final rows = <List<dynamic>>[
          ['title', 'body', 'createdAtISO']
        ];
        for (final d in q.docs) {
          final m = d.data();
          rows.add([
            m['title'] ?? '',
            m['body'] ?? '',
            _toIso(m['createdAt']),
          ]);
        }
        final csv = const ListToCsvConverter().convert(rows);
        await File('${downloadDir.path}/yayin_export.csv').writeAsString(csv, encoding: utf8);
      }

      return true;
    } catch (e, st) {
      debugPrint('CSV export hata: $e\n$st');
      return false;
    }
  }
}
