/// MessageModel corresponds to TransientMessageDto in the backend.
/// Represents a single text or action message in a conversation.
class MessageModel {
  final String? msgId;
  final String
      type; // CHAT, IMAGE, READ, EDIT, DELETE_FOR_ME, DELETE_EVERYONE, PING
  final String sender;
  final String receiver;
  final String message;
  final String status; // SENT, DELIVERED, READ
  final int timeStamp;
  final bool isEdited;
  final bool isDeletedForEveryone;
  final bool isForwarded;
  final String? replyToMsgId;
  final String? replyToSender;
  final String? replyToText;
  final String? localImageUrl;
  final String? cloudImageUrl;

  MessageModel({
    this.msgId,
    required this.type,
    required this.sender,
    required this.receiver,
    required this.message,
    required this.status,
    required this.timeStamp,
    this.isEdited = false,
    this.isDeletedForEveryone = false,
    this.isForwarded = false,
    this.replyToMsgId,
    this.replyToSender,
    this.replyToText,
    this.localImageUrl,
    this.cloudImageUrl,
  });

  MessageModel copyWith({
    String? msgId,
    String? type,
    String? sender,
    String? receiver,
    String? message,
    String? status,
    int? timeStamp,
    bool? isEdited,
    bool? isDeletedForEveryone,
    bool? isForwarded,
    String? replyToMsgId,
    String? replyToSender,
    String? replyToText,
    String? localImageUrl,
    String? cloudImageUrl,
  }) {
    return MessageModel(
      msgId: msgId ?? this.msgId,
      type: type ?? this.type,
      sender: sender ?? this.sender,
      receiver: receiver ?? this.receiver,
      message: message ?? this.message,
      status: status ?? this.status,
      timeStamp: timeStamp ?? this.timeStamp,
      isEdited: isEdited ?? this.isEdited,
      isDeletedForEveryone: isDeletedForEveryone ?? this.isDeletedForEveryone,
      isForwarded: isForwarded ?? this.isForwarded,
      replyToMsgId: replyToMsgId ?? this.replyToMsgId,
      replyToSender: replyToSender ?? this.replyToSender,
      replyToText: replyToText ?? this.replyToText,
      localImageUrl: localImageUrl ?? this.localImageUrl,
      cloudImageUrl: cloudImageUrl ?? this.cloudImageUrl,
    );
  }

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      msgId: json['msgId']?.toString(),
      type: json['type'] ?? 'CHAT',
      sender: json['sender'] ?? '',
      receiver: json['receiver'] ?? '',
      message: json['message'] ?? json['msg'] ?? '',
      status: json['status']?.toString() ?? 'SENT',
      timeStamp: json['timeStamp'] is int
          ? json['timeStamp']
          : (json['timeStamp'] != null
              ? DateTime.parse(json['timeStamp'].toString())
                  .millisecondsSinceEpoch
              : DateTime.now().millisecondsSinceEpoch),
      isEdited: json['isEdited'] == true,
      isDeletedForEveryone: json['isDeletedForEveryone'] == true,
      isForwarded: json['isForwarded'] == true,
      replyToMsgId: json['replyToMsgId']?.toString(),
      replyToSender: json['replyToSender']?.toString(),
      replyToText: json['replyToText']?.toString(),
      localImageUrl: json['localImageUrl']?.toString(),
      cloudImageUrl:
          json['cloudImageUrl']?.toString() ?? json['message']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'msgId': msgId,
      'type': type,
      'sender': sender,
      'receiver': receiver,
      'message': message,
      'status': status,
      'timeStamp': timeStamp,
      'isEdited': isEdited,
      'isDeletedForEveryone': isDeletedForEveryone,
      'isForwarded': isForwarded,
      'replyToMsgId': replyToMsgId,
      'replyToSender': replyToSender,
      'replyToText': replyToText,
      'localImageUrl': localImageUrl,
      'cloudImageUrl': cloudImageUrl ?? message,
    };
  }

  Map<String, dynamic> toDbMap() {
    return {
      'msgId': msgId ?? '${sender}_${receiver}_$timeStamp',
      'type': type,
      'sender': sender,
      'receiver': receiver,
      'message': message,
      'status': status,
      'timeStamp': timeStamp,
      'isEdited': isEdited ? 1 : 0,
      'isDeletedForEveryone': isDeletedForEveryone ? 1 : 0,
      'isForwarded': isForwarded ? 1 : 0,
      'replyToMsgId': replyToMsgId,
      'replyToSender': replyToSender,
      'replyToText': replyToText,
      'localImageUrl': localImageUrl,
      'cloudImageUrl': cloudImageUrl ?? message,
    };
  }

  factory MessageModel.fromDbMap(Map<String, dynamic> map) {
    return MessageModel(
      msgId: map['msgId'],
      type: map['type'],
      sender: map['sender'],
      receiver: map['receiver'],
      message: map['message'],
      status: map['status'],
      timeStamp: map['timeStamp'],
      isEdited: map['isEdited'] == 1,
      isDeletedForEveryone: map['isDeletedForEveryone'] == 1,
      isForwarded: map['isForwarded'] == 1,
      replyToMsgId: map['replyToMsgId']?.toString(),
      replyToSender: map['replyToSender']?.toString(),
      replyToText: map['replyToText']?.toString(),
      localImageUrl: map['localImageUrl']?.toString(),
      cloudImageUrl:
          map['cloudImageUrl']?.toString() ?? map['message']?.toString(),
    );
  }
}
