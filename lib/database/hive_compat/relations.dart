
import 'dart:collection';

class ToOne<T> {
  T? target;
  int? targetId;

  bool get hasValue => target != null || targetId != null;
}

class ToMany<T> extends ListBase<T> {
  ToMany();

  final List<T> _items = <T>[];

  @override
  int get length => _items.length;

  @override
  set length(int newLength) {
    _items.length = newLength;
  }

  @override
  T operator [](int index) => _items[index];

  @override
  void operator []=(int index, T value) {
    if (index >= _items.length) {
      _items.add(value);
    } else {
      _items[index] = value;
    }
  }

  @override
  void add(T value) => _items.add(value);

  @override
  void addAll(Iterable<T> iterable) => _items.addAll(iterable);

  List<T> toList({bool growable = true}) => List<T>.from(_items, growable: growable);
}
