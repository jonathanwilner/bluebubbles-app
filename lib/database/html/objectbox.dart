// ignore_for_file: camel_case_types
import 'dart:async';

import 'package:bluebubbles/database/html/handle.dart';

/// READ: Dummy file to allow objectbox related code to compile on Web. We use
/// conditional imports at compile time, so any references to objectbox stuff
/// in [database.dart], [main.dart] and [background_isolate.dart] will error if
/// this file is removed. The below classes and methods are the ones that those
/// files use, in case we need to add more objectbox functionality to those files,
/// the new classes/methods must be added here.

/// Configure transaction mode. Used with [Store.runInTransaction()].
enum TxMode {
  read,
  write,
}

/// Box put (write) mode.
enum PutMode {
  /// Insert (if given object's ID is zero) or update an existing object.
  put,

  /// Insert a new object.
  insert,

  /// Update an existing object, fails if the given ID doesn't exist.
  update,
}

class Order {
  /// Reverts the order from ascending (default) to descending.
  static const descending = 1;

  /// Sorts upper case letters (e.g. 'Z') before lower case letters (e.g. 'a').
  /// If not specified, the default is case insensitive for ASCII characters.
  static const caseSensitive = 2;

  /// For integers only: changes the comparison to unsigned. The default is
  /// signed, unless the property is annotated with [@Property(signed: false)].
  static const unsigned = 4;

  /// null values will be put last.
  /// If not specified, by default null values will be put first.
  static const nullsLast = 8;

  /// null values should be treated equal to zero (scalars only).
  static const nullsAsZero = 16;
}

class _Condition {
  const _Condition();

  _Condition and(_Condition other) => this;

  _Condition or(_Condition other) => this;

  _Condition not() => this;
}

typedef Condition<T> = _Condition;

class QueryBuilder<T> {
  QueryBuilder<T> order(dynamic property, {int flags = 0}) => this;

  QueryBuilder<T> link(dynamic relation, [Condition<dynamic>? condition]) => this;

  Query<T> build() => Query<T>();

  Stream<Query<T>> watch({bool triggerImmediately = false}) => const Stream<Query<T>>.empty();
}

class Box<T> {
  int put(T object, {PutMode mode = PutMode.put}) => throw Exception('Unsupported Platform');

  /// Puts the given [objects] into this Box in a single transaction.
  ///
  /// Returns a list of all IDs of the inserted Objects.
  List<int> putMany(List<T> objects, {PutMode mode = PutMode.put}) => throw Exception('Unsupported Platform');

  /// Retrieves the stored object with the ID [id] from this box's database.
  /// Returns null if an object with the given ID doesn't exist.
  T? get(int id) => throw Exception('Unsupported Platform');

  /// Returns all stored objects in this Box.
  List<T> getAll() => throw Exception('Unsupported Platform');

  /// Returns a list of [ids.length] Objects of type T, each corresponding to
  /// the location of its ID in [ids]. Non-existent IDs become null.
  ///
  /// Pass growableResult: true for the resulting list to be growable.
  List<T?> getMany(List<int> ids, {bool growableResult = false}) => throw Exception('Unsupported Platform');

  /// Removes (deletes) by ID, returning a list of IDs of all removed Objects.
  int removeMany(List<int> ids) => throw Exception('Unsupported Platform');

  /// Removes (deletes) ALL Objects in a single transaction.
  int removeAll() => throw Exception('Unsupported Platform');

  bool isEmpty() => throw Exception('Unsupported Platform');

  QueryBuilder<T> query([Condition<T>? qc]) => QueryBuilder<T>();
}

class ToOne<EntityT> {

  /// Get target object. If it's the first access, this reads from DB.
  EntityT? get target => null;

  /// Set relation target object. Note: this does not store the change yet, use
  /// [Box.put()] on the containing (relation source) object.
  set target(EntityT? object) {}

  int get targetId => 0;
}

class Store {
  Box<T> box<T>() => throw Exception('Unsupported Platform');

  R runInTransaction<R>(TxMode mode, R Function() fn) => throw Exception('Unsupported Platform');

  void close() => throw Exception('Unsupported Platform');

  dynamic get reference => throw Exception('Unsupported Platform');

  Store.fromReference(dynamic _, dynamic __);

  Store.attach(dynamic _, String? directoryPath,
      {bool queriesCaseSensitiveDefault = true});
}

class Query<T> {
  set offset(int offset) {}

  set limit(int limit) {}

  /// Returns the number of matching Objects.
  int count() {
    return 0;
  }

  /// Close the query and free resources.
  void close() {}

  /// Finds the first object matching the query. Returns null if there are no
  /// results. Note: [offset] and [limit] are respected, if set.
  T? findFirst() {
    return null;
  }

  /// Finds the only object matching the query. Returns null if there are no
  /// results or throws if there are multiple objects matching.
  ///
  /// Note: [offset] and [limit] are respected, if set. Because [limit] affects
  /// the number of matched objects, make sure you leave it at zero or set it
  /// higher than one, otherwise the check for non-unique result won't work.
  T? findUnique() {
    return null;
  }

  /// Finds Objects matching the query.
  List<T> find() {
    return [];
  }
}

class Temp extends _Condition {
  dynamic add(dynamic thing) {
    return this;
  }

  Condition<dynamic> equals(dynamic thing) {
    return const _Condition();
  }

  Condition<dynamic> oneOf(dynamic thing) {
    return const _Condition();
  }

  Condition<dynamic> contains(dynamic thing, {bool caseSensitive = true}) {
    return const _Condition();
  }

  Condition<dynamic> isNull() {
    return const _Condition();
  }

  Condition<dynamic> notNull() {
    return const _Condition();
  }

  Condition<dynamic> greaterOrEqual(dynamic thing) {
    return const _Condition();
  }

  Condition<dynamic> greaterThan(dynamic thing) {
    return const _Condition();
  }

  Condition<dynamic> lessOrEqual(dynamic thing) {
    return const _Condition();
  }

  Condition<dynamic> lessThan(dynamic thing) {
    return const _Condition();
  }
}

class Attachment_ {
  static final guid = Temp();
}

/// [Chat] entity fields to define ObjectBox queries.
class Chat_ {
  static final id = Temp();

  static final guid = Temp();

  static final dateDeleted = Temp();

  static final hasUnreadMessage = Temp();

  static final muteType = Temp();
}

class Contact_ {
  static final displayName = Temp();
}

class Handle_ {
  static final address = Temp();

  static final uniqueAddressAndService = Temp();
}

class Message_ {
  /// see [Message.id]
  static final id = Temp();

  /// see [Message.originalROWID]
  static final originalROWID = Temp();

  /// see [Message.guid]
  static final guid = Temp();

  /// see [Message.handleId]
  static final handleId = Temp();

  /// see [Message.otherHandle]
  static final otherHandle = Temp();

  /// see [Message.text]
  static final text = Temp();

  /// see [Message.subject]
  static final subject = Temp();

  /// see [Message.country]
  static final country = Temp();

  /// see [Message.dateCreated]
  static final dateCreated = Temp();

  /// see [Message.dateRead]
  static final dateRead = Temp();

  /// see [Message.dateDelivered]
  static final dateDelivered = Temp();

  /// see [Message.isFromMe]
  static final isFromMe = Temp();

  /// see [Message.hasDdResults]
  static final hasDdResults = Temp();

  /// see [Message.datePlayed]
  static final datePlayed = Temp();

  /// see [Message.itemType]
  static final itemType = Temp();

  /// see [Message.groupTitle]
  static final groupTitle = Temp();

  /// see [Message.groupActionType]
  static final groupActionType = Temp();

  /// see [Message.balloonBundleId]
  static final balloonBundleId = Temp();

  /// see [Message.associatedMessageGuid]
  static final associatedMessageGuid = Temp();

  /// see [Message.associatedMessageType]
  static final associatedMessageType = Temp();

  /// see [Message.expressiveSendStyleId]
  static final expressiveSendStyleId = Temp();

  /// see [Message.hasAttachments]
  static final hasAttachments = Temp();

  /// see [Message.hasReactions]
  static final hasReactions = Temp();

  /// see [Message.dateDeleted]
  static final dateDeleted = Temp();

  /// see [Message.threadOriginatorGuid]
  static final threadOriginatorGuid = Temp();

  /// see [Message.threadOriginatorPart]
  static final threadOriginatorPart = Temp();

  /// see [Message.bigEmoji]
  static final bigEmoji = Temp();

  /// see [Message.error]
  static final error = Temp();

  /// see [Message.chat]
  static final chat = Temp();

  /// see [Message.dbAttributedBody]
  static final dbAttributedBody = Temp();

  /// see [Message.associatedMessagePart]
  static final associatedMessagePart = Temp();

  /// see [Message.hasApplePayloadData]
  static final hasApplePayloadData = Temp();

  /// see [Message.dateEdited]
  static final dateEdited = Temp();

  /// see [Message.dbMessageSummaryInfo]
  static final dbMessageSummaryInfo = Temp();

  /// see [Message.dbPayloadData]
  static final dbPayloadData = Temp();

  /// see [Message.dbMetadata]
  static final dbMetadata = Temp();

  /// see [Message.isBookmarked]
  static final isBookmarked = Temp();
}

Future<Store> openStore(
        {String? directory,
        int? maxDBSizeInKB,
        int? fileMode,
        int? maxReaders,
        bool queriesCaseSensitiveDefault = true,
        String? macosApplicationGroup}) async =>
    throw Exception('Unsupported Platform');

dynamic getObjectBoxModel() => throw Exception('Unsupported Platform');

extension ObjectboxShims on List<Handle> {
  void applyToDb() {}
}
