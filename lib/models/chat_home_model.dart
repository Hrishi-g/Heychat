/// ChatHomeModel corresponds to LastMsgChatDTo in the Spring Boot backend.
/// Displays active conversations in the main WhatsApp Home Screen list.
class ChatHomeModel {
  final String chatUser;
  final String? chatUserName;
  final String lastMsg;
  final String status;
  final String? lastMessageTime;
  final String? imgUrl;

  ChatHomeModel({
    required this.chatUser,
    this.chatUserName,
    required this.lastMsg,
    required this.status,
    this.lastMessageTime,
    this.imgUrl,
  });

  ChatHomeModel copyWith({
    String? chatUser,
    String? chatUserName,
    String? lastMsg,
    String? status,
    String? lastMessageTime,
    String? imgUrl,
  }) {
    return ChatHomeModel(
      chatUser: chatUser ?? this.chatUser,
      chatUserName: chatUserName ?? this.chatUserName,
      lastMsg: lastMsg ?? this.lastMsg,
      status: status ?? this.status,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      imgUrl: imgUrl ?? this.imgUrl,
    );
  }

  factory ChatHomeModel.fromJson(Map<String, dynamic> json) {
    return ChatHomeModel(
      chatUser: json['chatUser'] ?? '',
      chatUserName: json['chatUserName'],
      lastMsg: json['lastMsg'] ?? '',
      status: json['status']?.toString() ?? 'SENT',
      lastMessageTime: json['lastMessageTime']?.toString(),
      imgUrl: json['imgUrl'],
    );
  }

  Map<String, dynamic> toDbMap() {
    return {
      'chatUser': chatUser,
      'chatUserName': chatUserName,
      'lastMsg': lastMsg,
      'status': status,
      'lastMessageTime': lastMessageTime,
      'imgUrl': imgUrl,
    };
  }

  factory ChatHomeModel.fromDbMap(Map<String, dynamic> map) {
    return ChatHomeModel(
      chatUser: map['chatUser'],
      chatUserName: map['chatUserName'],
      lastMsg: map['lastMsg'],
      status: map['status'],
      lastMessageTime: map['lastMessageTime'],
      imgUrl: map['imgUrl'],
    );
  }
}
