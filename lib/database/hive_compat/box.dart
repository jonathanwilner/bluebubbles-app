import 'dart:async';

import 'package:collection/collection.dart';
import 'package:hive/hive.dart';

import 'query.dart';
import 'store.dart';

const _metaLastIdKey = '__lastId__';

abstract class HiveEntityAdapter<T> {
  const HiveEntityAdapter();

  String get boxName;

  int? getId(T entity);

  void setId(T entity, int id);

  Map<String, dynamic> toMap(T entity);

  T fromMap(Map<String, dynamic> map);

  String? uniqueKey(T entity);

  bool matchesUniqueKey(T entity, String uniqueValue) => uniqueKey(entity) == uniqueValue;
}

class HiveCollectionBox<T> {
  HiveCollectionBox._(this.adapter, this._box);

  final HiveEntityAdapter<T> adapter;
  final Box _box;
  final StreamController<void> _changeController = StreamController<void>.broadcast();

  static Future<HiveCollectionBox<T>> open(HiveEntityAdapter<T> adapter) async {
    final box = await Hive.openBox(adapter.boxName);
    return HiveCollectionBox<T>._(adapter, box);
  }

  Stream<void> watch() => _changeController.stream;

  void _notify() {
    if (!_changeController.isClosed) {
      _changeController.add(null);
    }
  }

  List<T> getAll() {
    final entries = _box.keys.whereType<int>().toList()..sort();
    return entries
        .map((id) => _box.get(id))
        .whereNotNull()
        .map((dynamic value) => adapter.fromMap(Map<String, dynamic>.from(value as Map)))
        .toList();
  }

  T? get(int id) {
    final value = _box.get(id);
    if (value == null) {
      return null;
    }
    return adapter.fromMap(Map<String, dynamic>.from(value as Map));
  }

  List<T?> getMany(List<int> ids, {bool growableResult = false}) {
    final results = ids
        .map((id) => _box.get(id))
        .map((value) => value == null ? null : adapter.fromMap(Map<String, dynamic>.from(value as Map)))
        .toList(growable: growableResult);
    return results;
  }

  int put(T entity, {PutMode mode = PutMode.put}) {
    var id = adapter.getId(entity);
    if (id == null || id == 0) {
      id = _nextId();
      adapter.setId(entity, id);
    }

    final unique = adapter.uniqueKey(entity);
    if (unique != null) {
      final existingId = _findIdByUnique(unique);
      if (existingId != null && existingId != id) {
        throw UniqueViolationException('Duplicate value for unique field');
      }
    }

    _box.put(id, adapter.toMap(entity));
    _notify();
    return id;
  }

  List<int> putMany(List<T> entities, {PutMode mode = PutMode.put}) {
    final ids = <int>[];
    for (final entity in entities) {
      ids.add(put(entity, mode: mode));
    }
    return ids;
  }

  int removeMany(List<int> ids) {
    for (final id in ids) {
      _box.delete(id);
    }
    _notify();
    return ids.length;
  }

  int removeAll() {
    final count = _box.keys.whereType<int>().length;
    for (final key in _box.keys.toList()) {
      if (key is int) {
        _box.delete(key);
      }
    }
    _notify();
    return count;
  }

  bool isEmpty() => _box.keys.whereType<int>().isEmpty;

  QueryBuilder<T> query([Condition<T>? condition]) => QueryBuilder<T>(this, condition);

  int? _findIdByUnique(String uniqueValue) {
    for (final key in _box.keys.whereType<int>()) {
      final value = _box.get(key);
      if (value == null) continue;
      final entity = adapter.fromMap(Map<String, dynamic>.from(value as Map));
      if (adapter.uniqueKey(entity) == uniqueValue) {
        return key;
      }
    }
    return null;
  }

  int _nextId() {
    final last = (_box.get(_metaLastIdKey) as int?) ?? 0;
    final next = last + 1;
    _box.put(_metaLastIdKey, next);
    return next;
  }
}
