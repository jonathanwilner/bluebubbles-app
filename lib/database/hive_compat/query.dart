import 'dart:async';

import 'box.dart';

class QueryCondition<T> {
  const QueryCondition(this._tester);

  final bool Function(T) _tester;

  bool test(T value) => _tester(value);

  QueryCondition<T> and(QueryCondition<T> other) => QueryCondition<T>((value) => test(value) && other.test(value));

  QueryCondition<T> or(QueryCondition<T> other) => QueryCondition<T>((value) => test(value) || other.test(value));

  QueryCondition<T> not() => QueryCondition<T>((value) => !test(value));
}

typedef Condition<T> = QueryCondition<T>;

class Query<T> {
  Query(this._box, this._condition, this._sorts);

  final HiveCollectionBox<T> _box;
  final QueryCondition<T>? _condition;
  final List<Comparator<T>> _sorts;

  int offset = 0;
  int? limit;

  List<T> _apply(List<T> items) {
    var results = items;
    if (_condition != null) {
      results = results.where(_condition!.test).toList();
    } else {
      results = List<T>.from(results);
    }
    for (final comparator in _sorts.reversed) {
      results.sort(comparator);
    }
    if (offset > 0 || limit != null) {
      final start = offset.clamp(0, results.length);
      final end = limit == null ? results.length : (start + limit!).clamp(0, results.length);
      results = results.sublist(start, end);
    }
    return results;
  }

  List<T> find() => _apply(_box.getAll());

  List<int> findIds() => find().map((e) => _box.adapter.getId(e) ?? 0).toList();

  T? findFirst() {
    final results = find();
    return results.isEmpty ? null : results.first;
  }

  int count() => find().length;

  void close() {}
}

class QueryBuilder<T> {
  QueryBuilder(this._box, [QueryCondition<T>? condition]) {
    if (condition != null) {
      _conditions.add(condition);
    }
  }

  final HiveCollectionBox<T> _box;
  final List<QueryCondition<T>> _conditions = <QueryCondition<T>>[];
  final List<Comparator<T>> _sorts = <Comparator<T>>[];

  QueryBuilder<T> where(QueryCondition<T> condition) {
    _conditions.add(condition);
    return this;
  }

  QueryBuilder<T> order(QuerySortProperty<T> property, {int flags = 0}) {
    final comparator = property.comparator(descending: (flags & 1) != 0, caseSensitive: (flags & 2) != 0);
    _sorts.add(comparator);
    return this;
  }

  QueryBuilder<T> link<R>(RelationQueryProperty<T, R> relation, QueryCondition<R>? condition) {
    if (condition == null) {
      return this;
    }
    _conditions.add(QueryCondition<T>((entity) {
      final related = relation.resolve(entity);
      if (related == null) {
        return false;
      }
      return condition.test(related);
    }));
    return this;
  }

  Query<T> build() => Query<T>(_box, _combinedCondition(), List<Comparator<T>>.from(_sorts));

  QueryCondition<T>? _combinedCondition() {
    if (_conditions.isEmpty) {
      return null;
    }
    return _conditions.reduce((value, element) => value.and(element));
  }

  Stream<Query<T>> watch({bool triggerImmediately = false}) {
    final controller = StreamController<Query<T>>.broadcast();
    StreamSubscription<void>? sub;

    void emit() {
      controller.add(build());
    }

    if (triggerImmediately) {
      emit();
    }

    sub = _box.watch().listen((_) => emit());

    controller.onCancel = () {
      sub?.cancel();
    };

    return controller.stream;
  }
}

abstract class QueryProperty<T, V> {
  const QueryProperty(this._accessor);

  final V? Function(T) _accessor;

  V? value(T entity) => _accessor(entity);

  QueryCondition<T> equals(V? other) => QueryCondition<T>((entity) => value(entity) == other);

  QueryCondition<T> oneOf(Iterable<V?> values) => QueryCondition<T>((entity) => values.contains(value(entity)));

  QueryCondition<T> isNull() => QueryCondition<T>((entity) => value(entity) == null);

  QueryCondition<T> notNull() => QueryCondition<T>((entity) => value(entity) != null);
}

class StringQueryProperty<T> extends QueryProperty<T, String> implements QuerySortProperty<T> {
  const StringQueryProperty(String? Function(T) accessor) : super(accessor);

  QueryCondition<T> contains(String pattern, {bool caseSensitive = true}) => QueryCondition<T>((entity) {
    final val = value(entity);
    if (val == null) {
      return false;
    }
    return caseSensitive ? val.contains(pattern) : val.toLowerCase().contains(pattern.toLowerCase());
  });

  @override
  Comparator<T> comparator({required bool descending, required bool caseSensitive}) {
    return (a, b) {
      final av = value(a);
      final bv = value(b);
      int result;
      if (av == null && bv == null) {
        result = 0;
      } else if (av == null) {
        result = -1;
      } else if (bv == null) {
        result = 1;
      } else {
        final left = caseSensitive ? av : av.toLowerCase();
        final right = caseSensitive ? bv : bv.toLowerCase();
        result = left.compareTo(right);
      }
      return descending ? -result : result;
    };
  }
}

class BoolQueryProperty<T> extends QueryProperty<T, bool> implements QuerySortProperty<T> {
  const BoolQueryProperty(bool? Function(T) accessor) : super(accessor);

  @override
  Comparator<T> comparator({required bool descending, required bool caseSensitive}) {
    return (a, b) {
      final av = value(a);
      final bv = value(b);
      int result;
      if (av == null && bv == null) {
        result = 0;
      } else if (av == null) {
        result = -1;
      } else if (bv == null) {
        result = 1;
      } else {
        result = av == bv ? 0 : (av ? 1 : -1);
      }
      return descending ? -result : result;
    };
  }
}

class IntQueryProperty<T> extends QueryProperty<T, int> implements QuerySortProperty<T> {
  const IntQueryProperty(int? Function(T) accessor) : super(accessor);

  QueryCondition<T> lessThan(int value, {bool include = false}) => QueryCondition<T>((entity) {
    final val = this.value(entity);
    if (val == null) {
      return false;
    }
    return include ? val <= value : val < value;
  });

  QueryCondition<T> greaterThan(int value, {bool include = false}) => QueryCondition<T>((entity) {
    final val = this.value(entity);
    if (val == null) {
      return false;
    }
    return include ? val >= value : val > value;
  });

  QueryCondition<T> greaterOrEqual(int value) => greaterThan(value, include: true);

  @override
  Comparator<T> comparator({required bool descending, required bool caseSensitive}) {
    return (a, b) {
      final av = value(a);
      final bv = value(b);
      int result;
      if (av == null && bv == null) {
        result = 0;
      } else if (av == null) {
        result = -1;
      } else if (bv == null) {
        result = 1;
      } else {
        result = av.compareTo(bv);
      }
      return descending ? -result : result;
    };
  }
}

class DateQueryProperty<T> extends QueryProperty<T, DateTime> implements QuerySortProperty<T> {
  const DateQueryProperty(DateTime? Function(T) accessor) : super(accessor);

  QueryCondition<T> lessThan(DateTime value, {bool include = false}) => QueryCondition<T>((entity) {
    final val = this.value(entity);
    if (val == null) {
      return false;
    }
    return include ? val.isBefore(value) || val.isAtSameMomentAs(value) : val.isBefore(value);
  });

  QueryCondition<T> greaterThan(DateTime value, {bool include = false}) => QueryCondition<T>((entity) {
    final val = this.value(entity);
    if (val == null) {
      return false;
    }
    return include ? val.isAfter(value) || val.isAtSameMomentAs(value) : val.isAfter(value);
  });

  QueryCondition<T> greaterOrEqual(int millis) => QueryCondition<T>((entity) {
    final val = value(entity);
    if (val == null) {
      return false;
    }
    return val.millisecondsSinceEpoch >= millis;
  });

  QueryCondition<T> lessOrEqual(int millis) => QueryCondition<T>((entity) {
    final val = value(entity);
    if (val == null) {
      return false;
    }
    return val.millisecondsSinceEpoch <= millis;
  });

  @override
  Comparator<T> comparator({required bool descending, required bool caseSensitive}) {
    return (a, b) {
      final av = value(a);
      final bv = value(b);
      int result;
      if (av == null && bv == null) {
        result = 0;
      } else if (av == null) {
        result = -1;
      } else if (bv == null) {
        result = 1;
      } else {
        result = av.compareTo(bv);
      }
      return descending ? -result : result;
    };
  }
}

class ListQueryProperty<T, V> extends QueryProperty<T, List<V>> {
  const ListQueryProperty(List<V>? Function(T) accessor) : super(accessor);

  QueryCondition<T> containsElement(V value) => QueryCondition<T>((entity) => (this.value(entity) ?? const <V>[]).contains(value));
}

class RelationQueryProperty<T, R> {
  const RelationQueryProperty(this._resolver);

  final R? Function(T) _resolver;

  R? resolve(T entity) => _resolver(entity);
}

abstract class QuerySortProperty<T> {
  Comparator<T> comparator({required bool descending, required bool caseSensitive});
}

class ValueSortProperty<T, V extends Comparable> extends QuerySortProperty<T> {
  ValueSortProperty(this._accessor);

  final V? Function(T) _accessor;

  @override
  Comparator<T> comparator({required bool descending, required bool caseSensitive}) {
    return (a, b) {
      final av = _accessor(a);
      final bv = _accessor(b);
      int result;
      if (av == null && bv == null) {
        result = 0;
      } else if (av == null) {
        result = -1;
      } else if (bv == null) {
        result = 1;
      } else if (av is String && bv is String && !caseSensitive) {
        result = av.toLowerCase().compareTo(bv.toLowerCase());
      } else {
        result = av.compareTo(bv);
      }
      return descending ? -result : result;
    };
  }
}
