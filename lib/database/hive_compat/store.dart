
import 'package:hive/hive.dart';

import 'box.dart';

enum TxMode { read, write }

enum PutMode { put, insert, update }

class Order {
  static const descending = 1;
  static const caseSensitive = 2;
  static const unsigned = 4;
  static const nullsLast = 8;
  static const nullsAsZero = 16;
}

class UniqueViolationException implements Exception {
  UniqueViolationException([this.message]);

  final String? message;

  @override
  String toString() => 'UniqueViolationException: ${message ?? ''}';
}

class Store {
  Store._(this._directory);

  final String _directory;
  final Map<Type, dynamic> _boxes = {};

  static final Map<String, Store> _instances = {};

  static bool isOpen(String directory) => _instances.containsKey(directory);

  static Store attach(Object? _, String directory) => _instances[directory] ?? Store._(directory);

  static Future<Store> open({required String directory}) async {
    if (!_instances.containsKey(directory)) {
      Hive.init(directory);
      _instances[directory] = Store._(directory);
    }
    return _instances[directory]!;
  }

  void registerBox<T>(HiveCollectionBox<T> box) {
    _boxes[T] = box;
  }

  HiveCollectionBox<T> box<T>() {
    final box = _boxes[T];
    if (box == null) {
      throw StateError('Box for type $T has not been registered.');
    }
    return box as HiveCollectionBox<T>;
  }

  R runInTransaction<R>(TxMode mode, R Function() fn) => fn();
}
