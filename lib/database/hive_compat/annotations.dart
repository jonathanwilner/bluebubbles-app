class Entity {
  const Entity();
}

class Index {
  final IndexType? type;
  const Index({this.type});
}

enum IndexType {
  value,
}

class Unique {
  const Unique();
}

class Backlink {
  final String field;
  const Backlink(this.field);
}

class Transient {
  const Transient();
}
