import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class Row extends MapBase<String, dynamic> {
  final Map<String, dynamic> _data;
  Row(this._data);

  @override
  dynamic operator [](Object? key) => _data[key];

  @override
  void operator []=(String key, dynamic value) => _data[key] = value;

  @override
  void clear() => _data.clear();

  @override
  Iterable<String> get keys => _data.keys;

  @override
  dynamic remove(Object? key) => _data.remove(key);
}

class ResultSet extends ListBase<Row> {
  final List<Row> _rows;
  ResultSet(this._rows);

  @override
  int get length => _rows.length;

  @override
  set length(int newLength) => _rows.length = newLength;

  @override
  Row operator [](int index) => _rows[index];

  @override
  void operator []=(int index, Row value) => _rows[index] = value;
}

class PreparedStatement {
  final Database _db;
  final String _sql;
  PreparedStatement(this._db, this._sql);

  void execute([List<Object?> parameters = const []]) {
    _db.execute(_sql, parameters);
  }

  void dispose() {}
}

class Database {
  static const _legacyWebStorageKey = 'MAXGYM_WEB_PERSISTENT_SQLITE_V1';
  static const _tableKeyPrefix = 'MAXGYM_WEB_TBL_V2_';

  static final Map<String, Map<String, Map<String, dynamic>>> _tables = {
    'athletes': {},
    'measurement_logs': {},
    'programs': {},
    'program_drafts': {},
    'chat_messages': {},
    'athlete_workout_logs': {},
    'exercises_catalog': {},
    'custom_foods_catalog': {},
    'custom_supplements_catalog': {},
  };

  static bool _loadedFromDisk = false;
  static final Set<String> _dirtyTables = {};
  static Timer? _flushDebounceTimer;

  Database() {
    _restoreFromBrowserStorage();
  }

  Future<void> _restoreFromBrowserStorage() async {
    if (_loadedFromDisk) return;
    _loadedFromDisk = true;
    try {
      final prefs = await SharedPreferences.getInstance();

      // ۱. مهاجرت خودکار از کلید یکپارچه قدیمی (V1) در صورت وجود
      final legacyRaw = prefs.getString(_legacyWebStorageKey);
      if (legacyRaw != null && legacyRaw.isNotEmpty) {
        final decoded = jsonDecode(legacyRaw) as Map<String, dynamic>;
        decoded.forEach((table, rowsMap) {
          if (rowsMap is Map<String, dynamic>) {
            _tables.putIfAbsent(table, () => {});
            rowsMap.forEach((k, v) {
              _tables[table]![k] = Map<String, dynamic>.from(v as Map);
            });
          }
        });
        await prefs.remove(_legacyWebStorageKey);
        _markAllTablesDirtyAndScheduleFlush();
      }

      // ۲. بارگذاری جداول تفکیک‌شده (V2)
      for (final table in _tables.keys) {
        final rawTable = prefs.getString('$_tableKeyPrefix$table');
        if (rawTable != null && rawTable.isNotEmpty) {
          final decodedTable = jsonDecode(rawTable) as Map<String, dynamic>;
          final target = _tables.putIfAbsent(table, () => {});
          decodedTable.forEach((k, v) {
            target[k] = Map<String, dynamic>.from(v as Map);
          });
        }
      }
    } catch (_) {}
  }

  void _markTableDirty(String table) {
    _dirtyTables.add(table);
    _flushDebounceTimer?.cancel();
    _flushDebounceTimer = Timer(const Duration(milliseconds: 60), () {
      _flushDirtyTablesToStorage();
    });
  }

  void _markAllTablesDirtyAndScheduleFlush() {
    _dirtyTables.addAll(_tables.keys);
    _flushDebounceTimer?.cancel();
    _flushDebounceTimer = Timer(const Duration(milliseconds: 60), () {
      _flushDirtyTablesToStorage();
    });
  }

  /// ذخیره‌سازی بهینه و کم‌حجم جداول روی دیسک مرورگر (حذف کاتالوگ‌های ثابت پیش‌فرض برای جلوگیری از پر شدن ۵ مگابایت)
  Future<void> _flushDirtyTablesToStorage() async {
    if (_dirtyTables.isEmpty) return;
    final tablesToSave = List<String>.from(_dirtyTables);
    _dirtyTables.clear();

    try {
      final prefs = await SharedPreferences.getInstance();
      for (final table in tablesToSave) {
        final sourceMap = _tables[table];
        if (sourceMap == null) continue;

        Map<String, Map<String, dynamic>> filteredToPersist = sourceMap;

        // در جداول کاتالوگ، فقط آیتم‌های سفارشی مربی ذخیره می‌شوند (آیتم‌های پیش‌فرض در زمان بوت Seed می‌شوند)
        if (table == 'exercises_catalog') {
          filteredToPersist = Map.fromEntries(
            sourceMap.entries.where((e) =>
                e.key.startsWith('custom_') ||
                (e.value['equipment']?.toString() == 'custom')),
          );
        } else if (table == 'custom_foods_catalog') {
          filteredToPersist = Map.fromEntries(
            sourceMap.entries.where((e) => !e.key.startsWith('food_')),
          );
        } else if (table == 'custom_supplements_catalog') {
          filteredToPersist = Map.fromEntries(
            sourceMap.entries.where((e) =>
                e.value['id']?.toString().startsWith('custom_') == true ||
                e.key.length > 25),
          );
        }

        await prefs.setString(
          '$_tableKeyPrefix$table',
          jsonEncode(filteredToPersist),
        );
      }
    } catch (_) {}
  }

  void execute(String sql, [List<Object?> parameters = const []]) {
    final s = sql.trim();
    final upper = s.toUpperCase();

    if (upper.startsWith('BEGIN') ||
        upper.startsWith('COMMIT') ||
        upper.startsWith('ROLLBACK') ||
        upper.startsWith('CREATE ') ||
        upper.startsWith('ALTER ')) {
      return;
    }

    // ۱. اجرای دستورات چندگانه جداشده با سمیکالن (مثل clearAllUserDataOnLogout)
    if (s.contains(';') &&
        s.split(';').where((p) => p.trim().isNotEmpty).length > 1) {
      for (final stmt in s.split(';')) {
        if (stmt.trim().isNotEmpty) {
          execute(stmt, parameters);
        }
      }
      return;
    }

    // ۲. مدیریت کامل DELETE (رفع باگ رکوردهای یتیم و پشتیبانی از شروط مختلف)
    if (upper.startsWith('DELETE FROM ')) {
      final match =
          RegExp(r'DELETE\s+FROM\s+(\w+)', caseSensitive: false).firstMatch(s);
      if (match != null) {
        final table = match.group(1)!;
        final tableMap = _tables[table];
        if (tableMap == null) return;

        if (parameters.isNotEmpty && upper.contains('WHERE ID = ?')) {
          final targetId = parameters.first.toString();
          tableMap.removeWhere(
              (k, r) => k == targetId || r['id']?.toString() == targetId);
        } else if (parameters.isNotEmpty &&
            upper.contains('WHERE ATHLETE_ID = ?')) {
          final targetAthId = parameters.first.toString();
          tableMap.removeWhere((k, r) =>
              k == targetAthId || r['athlete_id']?.toString() == targetAthId);
        } else if (upper.contains("WHERE SYNC_STATUS = 'SYNCED'")) {
          tableMap.removeWhere((_, r) => r['sync_status'] == 'synced');
        } else if (upper.contains("WHERE ID LIKE 'CUSTOM_%'")) {
          tableMap.removeWhere((k, r) =>
              k.startsWith('custom_') ||
              (r['id']?.toString().startsWith('custom_') ?? false));
        } else if (upper.contains("WHERE ID NOT LIKE 'FOOD_%'")) {
          tableMap.removeWhere((k, _) => !k.startsWith('food_'));
        } else if (upper.contains("WHERE ID NOT LIKE 'SUPP_%'")) {
          tableMap.removeWhere((k, _) => k.length > 25);
        } else if (!upper.contains('WHERE')) {
          tableMap.clear();
        }
        _markTableDirty(table);
      }
      return;
    }

    // ۳. مدیریت کامل INSERT (شامل INSERT OR REPLACE، INSERT OR IGNORE و ON CONFLICT)
    if (upper.startsWith('INSERT')) {
      final match = RegExp(
        r'INTO\s+(\w+)\s*\(([^)]+)\)',
        caseSensitive: false,
      ).firstMatch(s);
      if (match != null) {
        final table = match.group(1)!;
        final cols =
            match.group(2)!.split(',').map((e) => e.trim()).toList();
        final rowMap = <String, dynamic>{};
        for (int i = 0; i < cols.length && i < parameters.length; i++) {
          rowMap[cols[i]] = parameters[i];
        }
        final pk = (rowMap['id'] ?? rowMap['athlete_id'] ?? '').toString();
        if (pk.isNotEmpty) {
          _tables.putIfAbsent(table, () => {});
          if (upper.contains('IGNORE') && _tables[table]!.containsKey(pk)) {
            return;
          }
          _tables[table]![pk] = rowMap;
          _markTableDirty(table);
        }
      }
      return;
    }

    // ۴. مدیریت کامل UPDATE برای تمامی سناریوهای اپلیکیشن
    if (upper.startsWith('UPDATE ')) {
      final match =
          RegExp(r'UPDATE\s+(\w+)', caseSensitive: false).firstMatch(s);
      if (match != null && parameters.isNotEmpty) {
        final table = match.group(1)!;
        final pk = parameters.last.toString();
        final existing = _tables[table]?[pk];
        if (existing != null) {
          if (upper.contains("SYNC_STATUS = 'SYNCED'")) {
            existing['sync_status'] = 'synced';
          }
          if (upper.contains('IS_DELETED = 1')) {
            existing['is_deleted'] = 1;
            existing['updated_at'] = parameters[0];
            existing['sync_status'] = 'pending_delete';
          }
          if (upper.contains("PAYMENT_STATUS = 'PAID'")) {
            existing['paid_amount'] = existing['total_fee'];
            existing['payment_status'] = 'paid';
            existing['updated_at'] = parameters[0];
            existing['sync_status'] = 'pending_update';
          }
          if (upper.contains('STREAK_DAYS = STREAK_DAYS + 1')) {
            final currentStreak = (existing['streak_days'] as int?) ?? 1;
            existing['streak_days'] = currentStreak + 1;
            existing['updated_at'] = parameters[0];
            existing['sync_status'] = 'pending_update';
          }
          if (upper.contains('SET WEIGHT_KG = ?')) {
            existing['weight_kg'] = parameters[0];
            if (parameters.length >= 3) {
              existing['updated_at'] = parameters[1];
            }
            existing['sync_status'] = 'pending_update';
          }
          if (upper.contains('SET ACCESS_CODE = ?')) {
            existing['access_code'] = parameters[0];
          }
          _markTableDirty(table);
        }
      }
    }
  }

  ResultSet select(String sql, [List<Object?> parameters = const []]) {
    final s = sql.trim();
    final upper = s.toUpperCase();

    if (upper.contains('COUNT(*)')) {
      final match =
          RegExp(r'FROM\s+(\w+)', caseSensitive: false).firstMatch(s);
      final table = match?.group(1) ?? '';
      final cnt = _tables[table]?.length ?? 0;
      return ResultSet([Row({'cnt': cnt})]);
    }

    final match = RegExp(r'FROM\s+(\w+)', caseSensitive: false).firstMatch(s);
    if (match == null) return ResultSet([]);
    final table = match.group(1)!;
    var rows = (_tables[table]?.values ?? const [])
        .map((m) => Map<String, dynamic>.from(m))
        .toList();

    if (upper.contains('IS_DELETED = 0')) {
      rows = rows
          .where((r) => (r['is_deleted'] ?? 0) == 0 || r['is_deleted'] == false)
          .toList();
    }
    if (upper.contains('IS_TEMPLATE = 0')) {
      rows = rows
          .where(
              (r) => (r['is_template'] ?? 0) == 0 || r['is_template'] == false)
          .toList();
    }
    if (upper.contains('IS_TEMPLATE = 1')) {
      rows = rows
          .where(
              (r) => (r['is_template'] ?? 0) == 1 || r['is_template'] == true)
          .toList();
    }
    if (upper.contains("SYNC_STATUS != 'SYNCED'")) {
      rows = rows.where((r) => r['sync_status'] != 'synced').toList();
    }
    if (upper.contains("WHERE ID LIKE 'CUSTOM_%'")) {
      rows = rows
          .where((r) =>
              (r['id']?.toString().startsWith('custom_') ?? false) ||
              r['equipment'] == 'custom')
          .toList();
    }
    if (upper.contains('WHERE ID = ?') && parameters.isNotEmpty) {
      rows = rows.where((r) => r['id'] == parameters.first).toList();
    }
    if (upper.contains('WHERE ATHLETE_ID = ?') && parameters.isNotEmpty) {
      rows = rows.where((r) => r['athlete_id'] == parameters.first).toList();
    }
    if (upper.contains('WHERE TARGET_MUSCLE = ?') && parameters.isNotEmpty) {
      rows = rows.where((r) => r['target_muscle'] == parameters.first).toList();
    }
    if (upper.contains('UPPER(ACCESS_CODE) = ?') && parameters.length >= 4) {
      final norm = parameters[0].toString().toUpperCase().trim();
      final pcNorm = parameters[1].toString().toUpperCase().trim();
      final rawPhone = parameters[2].toString().trim();
      final lowerEmail = parameters[3].toString().toLowerCase().trim();
      rows = rows.where((r) {
        final code = (r['access_code'] ?? '').toString().toUpperCase().trim();
        final phone = (r['phone'] ?? '').toString().trim();
        final email = (r['email'] ?? '').toString().toLowerCase().trim();
        return code == norm ||
            code == pcNorm ||
            (rawPhone.isNotEmpty && phone == rawPhone) ||
            (lowerEmail.isNotEmpty && email == lowerEmail);
      }).toList();
    } else if (upper.contains('UPPER(ACCESS_CODE) = UPPER(?)') &&
        parameters.isNotEmpty) {
      final code = parameters.first.toString().toUpperCase().trim();
      rows = rows
          .where((r) =>
              (r['access_code'] ?? '').toString().toUpperCase().trim() == code)
          .toList();
    }

    // پشتیبانی از مرتب‌سازی ORDER BY برای نمایش صحیح نمودارها و چت‌ها در وب
    final orderMatch = RegExp(
      r'ORDER\s+BY\s+(\w+)\s+(ASC|DESC)',
      caseSensitive: false,
    ).firstMatch(s);
    if (orderMatch != null) {
      final col = orderMatch.group(1)!.toLowerCase();
      final isDesc = orderMatch.group(2)!.toUpperCase() == 'DESC';
      if (col != 'rowid') {
        rows.sort((a, b) {
          final va = (a[col] ?? '').toString();
          final vb = (b[col] ?? '').toString();
          return isDesc ? vb.compareTo(va) : va.compareTo(vb);
        });
      } else if (isDesc) {
        rows = rows.reversed.toList();
      }
    }

    if (upper.contains('LIMIT 1') && rows.length > 1) {
      rows = [rows.first];
    }

    return ResultSet(rows.map((e) => Row(e)).toList());
  }

  PreparedStatement prepare(String sql) => PreparedStatement(this, sql);
}

class _Sqlite3Web {
  Database open(String path) => Database();
  Database openInMemory() => Database();
}

final sqlite3 = _Sqlite3Web();
