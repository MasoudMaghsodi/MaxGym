import 'dart:collection';

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
  final Map<String, Map<String, Map<String, dynamic>>> _tables = {
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

  void execute(String sql, [List<Object?> parameters = const []]) {
    final s = sql.trim();
    final upper = s.toUpperCase();

    if (upper.startsWith('DELETE FROM ')) {
      final match = RegExp(r'DELETE\s+FROM\s+(\w+)', caseSensitive: false).firstMatch(s);
      if (match != null) {
        final table = match.group(1)!;
        if (parameters.isNotEmpty && upper.contains('WHERE ID = ?')) {
          _tables[table]?.remove(parameters.first.toString());
        } else if (!upper.contains('WHERE')) {
          _tables[table]?.clear();
        }
      }
      return;
    }

    if (upper.startsWith('INSERT')) {
      final match = RegExp(
        r'INTO\s+(\w+)\s*\(([^)]+)\)',
        caseSensitive: false,
      ).firstMatch(s);
      if (match != null) {
        final table = match.group(1)!;
        final cols = match
            .group(2)!
            .split(',')
            .map((e) => e.trim())
            .toList();
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
        }
      }
      return;
    }

    if (upper.startsWith('UPDATE ')) {
      final match = RegExp(r'UPDATE\s+(\w+)', caseSensitive: false).firstMatch(s);
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
            existing['sync_status'] = 'pending_delete';
          }
          if (upper.contains("PAYMENT_STATUS = 'PAID'")) {
            existing['paid_amount'] = existing['total_fee'];
            existing['payment_status'] = 'paid';
          }
          if (upper.contains('SET WEIGHT_KG = ?')) {
            existing['weight_kg'] = parameters[0];
          }
          if (upper.contains('SET ACCESS_CODE = ?')) {
            existing['access_code'] = parameters[0];
          }
        }
      }
    }
  }

  ResultSet select(String sql, [List<Object?> parameters = const []]) {
    final s = sql.trim();
    final upper = s.toUpperCase();

    if (upper.contains('COUNT(*)')) {
      final match = RegExp(r'FROM\s+(\w+)', caseSensitive: false).firstMatch(s);
      final table = match?.group(1) ?? '';
      final cnt = _tables[table]?.length ?? 0;
      return ResultSet([Row({'cnt': cnt})]);
    }

    final match = RegExp(r'FROM\s+(\w+)', caseSensitive: false).firstMatch(s);
    if (match == null) return ResultSet([]);
    final table = match.group(1)!;
    var rows = (_tables[table]?.values ?? const []).map((m) => Map<String, dynamic>.from(m)).toList();

    if (upper.contains('IS_DELETED = 0')) {
      rows = rows.where((r) => (r['is_deleted'] ?? 0) == 0).toList();
    }
    if (upper.contains('IS_TEMPLATE = 0')) {
      rows = rows.where((r) => (r['is_template'] ?? 0) == 0).toList();
    }
    if (upper.contains('IS_TEMPLATE = 1')) {
      rows = rows.where((r) => (r['is_template'] ?? 0) == 1).toList();
    }
    if (upper.contains("SYNC_STATUS != 'SYNCED'")) {
      rows = rows.where((r) => r['sync_status'] != 'synced').toList();
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
    if (upper.contains('UPPER(ACCESS_CODE) = UPPER(?)') && parameters.isNotEmpty) {
      final code = parameters.first.toString().toUpperCase().trim();
      rows = rows.where((r) => (r['access_code'] ?? '').toString().toUpperCase().trim() == code).toList();
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
