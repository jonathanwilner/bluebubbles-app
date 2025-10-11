
import 'database/hive_compat/adapters.dart';
import 'database/hive_compat/annotations.dart';
import 'database/hive_compat/box.dart';
import 'database/hive_compat/query.dart';
import 'database/hive_compat/relations.dart';
import 'database/hive_compat/store.dart';
import 'database/io/attachment.dart';
import 'database/io/chat.dart';
import 'database/io/contact.dart';
import 'database/io/fcm_data.dart';
import 'database/io/handle.dart';
import 'database/io/message.dart';
import 'database/io/theme.dart';
import 'database/io/theme_entry.dart';
import 'database/io/theme_object.dart';

export 'database/hive_compat/objectbox.dart';

Future<Store> openStore({String? directory}) async {
  if (directory == null) {
    throw ArgumentError('Directory must be provided for Hive-backed store.');
  }
  return Store.open(directory: directory);
}

dynamic getObjectBoxModel() => null;

class Attachment_ {
  static final id = IntQueryProperty<Attachment>((a) => a.id);
  static final guid = StringQueryProperty<Attachment>((a) => a.guid ?? '');
  static final message = RelationQueryProperty<Attachment, Message>((a) => a.message.target);
}

class Chat_ {
  static final id = IntQueryProperty<Chat>((c) => c.id);
  static final guid = StringQueryProperty<Chat>((c) => c.guid ?? '');
  static final chatIdentifier = StringQueryProperty<Chat>((c) => c.chatIdentifier);
  static final hasUnreadMessage = BoolQueryProperty<Chat>((c) => c.hasUnreadMessage);
  static final isPinned = BoolQueryProperty<Chat>((c) => c.isPinned);
  static final dateDeleted = DateQueryProperty<Chat>((c) => c.dateDeleted);
  static final dbOnlyLatestMessageDate = DateQueryProperty<Chat>((c) => c.dbOnlyLatestMessageDate);
}

class Contact_ {
  static final id = IntQueryProperty<Contact>((c) => c.id);
  static final displayName = StringQueryProperty<Contact>((c) => c.displayName);
  static final emails = ListQueryProperty<Contact, String>((c) => c.emails);
}

class FCMData_ {
  static final id = IntQueryProperty<FCMData>((f) => f.id);
}

class Handle_ {
  static final id = IntQueryProperty<Handle>((h) => h.id);
  static final originalROWID = IntQueryProperty<Handle>((h) => h.originalROWID);
  static final address = StringQueryProperty<Handle>((h) => h.address);
  static final service = StringQueryProperty<Handle>((h) => h.service);
  static final uniqueAddressAndService = StringQueryProperty<Handle>((h) => h.uniqueAddressAndService);
}

class Message_ {
  static final id = IntQueryProperty<Message>((m) => m.id);
  static final guid = StringQueryProperty<Message>((m) => m.guid ?? '');
  static final originalROWID = IntQueryProperty<Message>((m) => m.originalROWID ?? 0);
  static final text = StringQueryProperty<Message>((m) => m.text ?? '');
  static final handleId = IntQueryProperty<Message>((m) => m.handleId ?? 0);
  static final isFromMe = BoolQueryProperty<Message>((m) => m.isFromMe ?? false);
  static final dateCreated = DateQueryProperty<Message>((m) => m.dateCreated);
  static final dateDeleted = DateQueryProperty<Message>((m) => m.dateDeleted);
  static final associatedMessageGuid = StringQueryProperty<Message>((m) => m.associatedMessageGuid ?? '');
  static final balloonBundleId = StringQueryProperty<Message>((m) => m.balloonBundleId ?? '');
  static final dbPayloadData = StringQueryProperty<Message>((m) => m.dbPayloadData ?? '');
  static final chat = RelationQueryProperty<Message, Chat>((m) => m.chat.target);
  static final isBookmarked = BoolQueryProperty<Message>((m) => m.isBookmarked ?? false);
}

class ThemeStruct_ {
  static final id = IntQueryProperty<ThemeStruct>((t) => t.id);
  static final name = StringQueryProperty<ThemeStruct>((t) => t.name ?? '');
}

class ThemeEntry_ {
  static final id = IntQueryProperty<ThemeEntry>((t) => t.id);
  static final themeObject = RelationQueryProperty<ThemeEntry, ThemeObject>((t) => t.themeObject.target);
}

class ThemeObject_ {
  static final id = IntQueryProperty<ThemeObject>((t) => t.id);
}
