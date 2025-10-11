
import '../io/attachment.dart';
import '../io/chat.dart';
import '../io/contact.dart';
import '../io/fcm_data.dart';
import '../io/handle.dart';
import '../io/message.dart';
import '../io/theme.dart';
import '../io/theme_entry.dart';
import '../io/theme_object.dart';

import 'box.dart';

class AttachmentAdapter extends HiveEntityAdapter<Attachment> {
  const AttachmentAdapter();

  @override
  String get boxName => 'attachments';

  @override
  int? getId(Attachment entity) => entity.id;

  @override
  void setId(Attachment entity, int id) => entity.id = id;

  @override
  Map<String, dynamic> toMap(Attachment entity) {
    final map = entity.toMap();
    map['messageId'] = entity.message.targetId;
    return map;
  }

  @override
  Attachment fromMap(Map<String, dynamic> map) {
    final attachment = Attachment.fromMap(map);
    attachment.message.targetId = map['messageId'] as int?;
    return attachment;
  }

  @override
  String? uniqueKey(Attachment entity) => entity.guid;
}

class ChatAdapter extends HiveEntityAdapter<Chat> {
  const ChatAdapter();

  @override
  String get boxName => 'chats';

  @override
  int? getId(Chat entity) => entity.id;

  @override
  void setId(Chat entity, int id) => entity.id = id;

  @override
  Map<String, dynamic> toMap(Chat entity) {
    final map = entity.toMap();
    map['handles'] = entity.handles.map((handle) => handle.toMap(includeObjects: true)).toList();
    map['messages'] = entity.messages.map((message) => message.toMap(includeObjects: true)).toList();
    return map;
  }

  @override
  Chat fromMap(Map<String, dynamic> map) {
    final chat = Chat.fromMap(map);
    final handles = (map['handles'] as List<dynamic>? ?? <dynamic>[])
        .map((e) => Handle.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
    chat.handles.addAll(handles);
    final messages = (map['messages'] as List<dynamic>? ?? <dynamic>[])
        .map((e) => Message.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
    chat.messages.addAll(messages);
    return chat;
  }

  @override
  String? uniqueKey(Chat entity) => entity.guid;
}

class ContactAdapter extends HiveEntityAdapter<Contact> {
  const ContactAdapter();

  @override
  String get boxName => 'contacts';

  @override
  int? getId(Contact entity) => entity.id;

  @override
  void setId(Contact entity, int id) => entity.id = id;

  @override
  Map<String, dynamic> toMap(Contact entity) => entity.toMap();

  @override
  Contact fromMap(Map<String, dynamic> map) => Contact.fromMap(map);

  @override
  String? uniqueKey(Contact entity) => entity.id?.toString();
}

class FcmDataAdapter extends HiveEntityAdapter<FCMData> {
  const FcmDataAdapter();

  @override
  String get boxName => 'fcmData';

  @override
  int? getId(FCMData entity) => entity.id;

  @override
  void setId(FCMData entity, int id) => entity.id = id;

  @override
  Map<String, dynamic> toMap(FCMData entity) => entity.toMap();

  @override
  FCMData fromMap(Map<String, dynamic> map) => FCMData.fromMap(map);

  @override
  String? uniqueKey(FCMData entity) => 'fcm';
}

class HandleAdapter extends HiveEntityAdapter<Handle> {
  const HandleAdapter();

  @override
  String get boxName => 'handles';

  @override
  int? getId(Handle entity) => entity.id;

  @override
  void setId(Handle entity, int id) => entity.id = id;

  @override
  Map<String, dynamic> toMap(Handle entity) {
    final map = entity.toMap(includeObjects: true);
    map['contactRelationId'] = entity.contactRelation.targetId;
    return map;
  }

  @override
  Handle fromMap(Map<String, dynamic> map) {
    final handle = Handle.fromMap(map);
    handle.contactRelation.targetId = map['contactRelationId'] as int?;
    if (map['contact'] != null) {
      handle.contactRelation.target = Contact.fromMap(Map<String, dynamic>.from(map['contact'] as Map));
    }
    return handle;
  }

  @override
  String? uniqueKey(Handle entity) => entity.uniqueAddressAndService;
}

class MessageAdapter extends HiveEntityAdapter<Message> {
  const MessageAdapter();

  @override
  String get boxName => 'messages';

  @override
  int? getId(Message entity) => entity.id;

  @override
  void setId(Message entity, int id) => entity.id = id;

  @override
  Map<String, dynamic> toMap(Message entity) {
    final map = entity.toMap(includeObjects: true);
    map['chatId'] = entity.chat.targetId;
    map['associatedMessageGuids'] = entity.associatedMessages.map((m) => m.guid).toList();
    return map;
  }

  @override
  Message fromMap(Map<String, dynamic> map) {
    final message = Message.fromMap(map);
    message.chat.targetId = map['chatId'] as int?;
    final attachments = (map['attachments'] as List<dynamic>? ?? <dynamic>[])
        .map((e) => Attachment.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
    message.attachments = attachments;
    message.dbAttachments.addAll(attachments);
    return message;
  }

  @override
  String? uniqueKey(Message entity) => entity.guid;
}

class ThemeAdapter extends HiveEntityAdapter<ThemeStruct> {
  const ThemeAdapter();

  @override
  String get boxName => 'themes';

  @override
  int? getId(ThemeStruct entity) => entity.id;

  @override
  void setId(ThemeStruct entity, int id) => entity.id = id;

  @override
  Map<String, dynamic> toMap(ThemeStruct entity) => entity.toMap();

  @override
  ThemeStruct fromMap(Map<String, dynamic> map) => ThemeStruct.fromMap(map);

  @override
  String? uniqueKey(ThemeStruct entity) => entity.name;
}

class ThemeEntryAdapter extends HiveEntityAdapter<ThemeEntry> {
  const ThemeEntryAdapter();

  @override
  String get boxName => 'themeEntries';

  @override
  int? getId(ThemeEntry entity) => entity.id;

  @override
  void setId(ThemeEntry entity, int id) => entity.id = id;

  @override
  Map<String, dynamic> toMap(ThemeEntry entity) {
    final map = entity.toMap();
    map['themeObjectId'] = entity.themeObject.targetId;
    return map;
  }

  @override
  ThemeEntry fromMap(Map<String, dynamic> map) {
    final entry = ThemeEntry.fromMap(map);
    entry.themeObject.targetId = map['themeObjectId'] as int?;
    return entry;
  }

  @override
  String? uniqueKey(ThemeEntry entity) => entity.id?.toString();
}

class ThemeObjectAdapter extends HiveEntityAdapter<ThemeObject> {
  const ThemeObjectAdapter();

  @override
  String get boxName => 'themeObjects';

  @override
  int? getId(ThemeObject entity) => entity.id;

  @override
  void setId(ThemeObject entity, int id) => entity.id = id;

  @override
  Map<String, dynamic> toMap(ThemeObject entity) {
    final map = entity.toMap();
    map['themeEntries'] = entity.themeEntries.map((entry) => entry.toMap()).toList();
    return map;
  }

  @override
  ThemeObject fromMap(Map<String, dynamic> map) {
    final theme = ThemeObject.fromMap(map);
    final entries = (map['themeEntries'] as List<dynamic>? ?? <dynamic>[])
        .map((e) => ThemeEntry.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
    theme.themeEntries.addAll(entries);
    return theme;
  }

  @override
  String? uniqueKey(ThemeObject entity) => entity.id?.toString();
}
