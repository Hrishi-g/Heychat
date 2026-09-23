import '../models/chat_home_model.dart';
import '../models/message_model.dart';

class DummyData {
  static List<ChatHomeModel> getDummyHomeChats() {
    final now = DateTime.now();

    return [
      ChatHomeModel(
        chatUser: '+91 98765 43210',
        chatUserName: 'Aarav Sharma',
        lastMsg: 'Are we still meeting for coffee today? ☕',
        status: 'READ',
        lastMessageTime:
            now.subtract(const Duration(minutes: 5)).toIso8601String(),
      ),
      ChatHomeModel(
        chatUser: '+91 98123 45678',
        chatUserName: 'Priya Patel',
        lastMsg: 'The new UI design looks super clean and modern! 🚀',
        status: 'DELIVERED',
        lastMessageTime:
            now.subtract(const Duration(minutes: 28)).toIso8601String(),
      ),
      ChatHomeModel(
        chatUser: '+91 99234 56789',
        chatUserName: 'Dev Team Group',
        lastMsg: 'Rohan: Pushed the latest build to staging branch.',
        status: 'READ',
        lastMessageTime: now
            .subtract(const Duration(hours: 1, minutes: 15))
            .toIso8601String(),
      ),
      ChatHomeModel(
        chatUser: '+91 97345 67890',
        chatUserName: 'Neha Verma',
        lastMsg: 'Can you check the APK on your device?',
        status: 'SENT',
        lastMessageTime: now
            .subtract(const Duration(hours: 2, minutes: 40))
            .toIso8601String(),
      ),
      ChatHomeModel(
        chatUser: '+91 96456 78901',
        chatUserName: 'Vikram Malhotra',
        lastMsg: 'Haha that was hilarious 😂 Talk to you later!',
        status: 'READ',
        lastMessageTime: now
            .subtract(const Duration(hours: 4, minutes: 10))
            .toIso8601String(),
      ),
      ChatHomeModel(
        chatUser: '+91 95567 89012',
        chatUserName: 'Ananya Gupta',
        lastMsg: 'Please send over the project requirements doc.',
        status: 'DELIVERED',
        lastMessageTime: now
            .subtract(const Duration(hours: 6, minutes: 5))
            .toIso8601String(),
      ),
      ChatHomeModel(
        chatUser: '+91 94678 90123',
        chatUserName: 'Karan Mehta',
        lastMsg: 'Thanks for the quick review, man! Really appreciate it 🙏',
        status: 'READ',
        lastMessageTime: now
            .subtract(const Duration(hours: 9, minutes: 20))
            .toIso8601String(),
      ),
      ChatHomeModel(
        chatUser: '+91 93789 01234',
        chatUserName: 'Siddharth Rao',
        lastMsg: 'Let\'s catch up over the weekend.',
        status: 'SENT',
        lastMessageTime:
            now.subtract(const Duration(days: 1, hours: 2)).toIso8601String(),
      ),
      ChatHomeModel(
        chatUser: '+91 92890 12345',
        chatUserName: 'Riya Sen',
        lastMsg: 'Happy Birthday! Wishing you a fantastic year ahead! 🎂🎉',
        status: 'READ',
        lastMessageTime:
            now.subtract(const Duration(days: 1, hours: 6)).toIso8601String(),
      ),
      ChatHomeModel(
        chatUser: '+91 91901 23456',
        chatUserName: 'Aditya Joshi',
        lastMsg: 'I will send the invoice by end of day today.',
        status: 'DELIVERED',
        lastMessageTime:
            now.subtract(const Duration(days: 2, hours: 1)).toIso8601String(),
      ),
      ChatHomeModel(
        chatUser: '+91 90012 34567',
        chatUserName: 'Pooja Iyer',
        lastMsg: 'Perfect! See you at 10 AM tomorrow.',
        status: 'READ',
        lastMessageTime:
            now.subtract(const Duration(days: 2, hours: 9)).toIso8601String(),
      ),
      ChatHomeModel(
        chatUser: '+91 89123 45670',
        chatUserName: 'Manish Kumar',
        lastMsg: 'Call me whenever you are free.',
        status: 'READ',
        lastMessageTime:
            now.subtract(const Duration(days: 3, hours: 4)).toIso8601String(),
      ),
      ChatHomeModel(
        chatUser: '+91 88234 56781',
        chatUserName: 'Sneha Reddy',
        lastMsg: 'Great job on the demo today!',
        status: 'DELIVERED',
        lastMessageTime:
            now.subtract(const Duration(days: 4, hours: 7)).toIso8601String(),
      ),
      ChatHomeModel(
        chatUser: '+91 87345 67892',
        chatUserName: 'Rahul Nair',
        lastMsg: 'Sure, I will take care of it right away.',
        status: 'SENT',
        lastMessageTime:
            now.subtract(const Duration(days: 5, hours: 3)).toIso8601String(),
      ),
      ChatHomeModel(
        chatUser: '+91 86456 78903',
        chatUserName: 'Ishaan Deshmukh',
        lastMsg: 'All test cases passed successfully! ✅',
        status: 'READ',
        lastMessageTime:
            now.subtract(const Duration(days: 6, hours: 11)).toIso8601String(),
      ),
    ];
  }

  static List<MessageModel> getDummyMessagesFor({
    required String contactMblNo,
    String? contactName,
    required String currentUserMblNo,
  }) {
    final displayName = contactName ?? contactMblNo;
    final baseTime = DateTime.now().subtract(const Duration(hours: 3));

    return [
      MessageModel(
        msgId: '${contactMblNo}_1',
        type: 'CHAT',
        sender: contactMblNo,
        receiver: currentUserMblNo,
        message: 'Hey! How is everything going with the new app update?',
        status: 'READ',
        timeStamp: baseTime.millisecondsSinceEpoch,
      ),
      MessageModel(
        msgId: '${currentUserMblNo}_2',
        type: 'CHAT',
        sender: currentUserMblNo,
        receiver: contactMblNo,
        message:
            'Going really well! Just finished tuning the smooth navigation dock and chat transitions.',
        status: 'READ',
        timeStamp:
            baseTime.add(const Duration(minutes: 5)).millisecondsSinceEpoch,
      ),
      MessageModel(
        msgId: '${contactMblNo}_3',
        type: 'CHAT',
        sender: contactMblNo,
        receiver: currentUserMblNo,
        message: 'Nice! Does it have that sliding pill effect?',
        status: 'READ',
        timeStamp:
            baseTime.add(const Duration(minutes: 8)).millisecondsSinceEpoch,
      ),
      MessageModel(
        msgId: '${currentUserMblNo}_4',
        type: 'CHAT',
        sender: currentUserMblNo,
        receiver: contactMblNo,
        message:
            'Yes, it smoothly slides across Chats, Status, and Calls with zero jerkiness 👌',
        status: 'READ',
        timeStamp:
            baseTime.add(const Duration(minutes: 12)).millisecondsSinceEpoch,
      ),
      MessageModel(
        msgId: '${contactMblNo}_5',
        type: 'CHAT',
        sender: contactMblNo,
        receiver: currentUserMblNo,
        message:
            'What about the message delete issue? The keyboard was bouncing earlier when tapping delete.',
        status: 'READ',
        timeStamp:
            baseTime.add(const Duration(minutes: 20)).millisecondsSinceEpoch,
      ),
      MessageModel(
        msgId: '${currentUserMblNo}_6',
        type: 'CHAT',
        sender: currentUserMblNo,
        receiver: contactMblNo,
        message:
            'Fixed that completely! The keyboard stays closed and only opens after you finish with the popup.',
        status: 'READ',
        timeStamp:
            baseTime.add(const Duration(minutes: 25)).millisecondsSinceEpoch,
      ),
      MessageModel(
        msgId: '${contactMblNo}_7',
        type: 'CHAT',
        sender: contactMblNo,
        receiver: currentUserMblNo,
        message:
            'Awesome! And new messages don\'t get hidden behind the keyboard anymore?',
        status: 'READ',
        timeStamp:
            baseTime.add(const Duration(minutes: 35)).millisecondsSinceEpoch,
      ),
      MessageModel(
        msgId: '${currentUserMblNo}_8',
        type: 'CHAT',
        sender: currentUserMblNo,
        receiver: contactMblNo,
        message:
            'Nope, the list view auto-scrolls in multiple passes so the latest bubble is always 100% visible.',
        status: 'READ',
        timeStamp:
            baseTime.add(const Duration(minutes: 42)).millisecondsSinceEpoch,
      ),
      MessageModel(
        msgId: '${contactMblNo}_9',
        type: 'CHAT',
        sender: contactMblNo,
        receiver: currentUserMblNo,
        message:
            'You can test long-pressing this bubble to test the delete flow! 🚀',
        status: 'READ',
        timeStamp: baseTime
            .add(const Duration(hours: 1, minutes: 10))
            .millisecondsSinceEpoch,
      ),
      MessageModel(
        msgId: '${currentUserMblNo}_10',
        type: 'CHAT',
        sender: currentUserMblNo,
        receiver: contactMblNo,
        message:
            'Will do! Also, try scrolling up to see the previous conversation history.',
        status: 'READ',
        timeStamp: baseTime
            .add(const Duration(hours: 1, minutes: 25))
            .millisecondsSinceEpoch,
      ),
      MessageModel(
        msgId: '${contactMblNo}_11',
        type: 'CHAT',
        sender: contactMblNo,
        receiver: currentUserMblNo,
        message: 'Looks great on mobile. Super fast and responsive.',
        status: 'READ',
        timeStamp:
            baseTime.add(const Duration(hours: 2)).millisecondsSinceEpoch,
      ),
      MessageModel(
        msgId: '${currentUserMblNo}_12',
        type: 'CHAT',
        sender: currentUserMblNo,
        receiver: contactMblNo,
        message:
            'Thanks $displayName! Let me know if you want any other tweaks.',
        status: 'READ',
        timeStamp: baseTime
            .add(const Duration(hours: 2, minutes: 20))
            .millisecondsSinceEpoch,
      ),
      MessageModel(
        msgId: '${contactMblNo}_13',
        type: 'CHAT',
        sender: contactMblNo,
        receiver: currentUserMblNo,
        message: 'Are we still meeting for coffee today? ☕',
        status: 'READ',
        timeStamp: DateTime.now()
            .subtract(const Duration(minutes: 5))
            .millisecondsSinceEpoch,
      ),
    ];
  }

  static String formatTimestamp(String? isoString) {
    if (isoString == null) return '';
    try {
      final date = DateTime.parse(isoString).toLocal();
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays == 0 && date.day == now.day) {
        final hour =
            date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
        final minute = date.minute.toString().padLeft(2, '0');
        final ampm = date.hour >= 12 ? 'PM' : 'AM';
        return '$hour:$minute $ampm';
      } else if (difference.inDays < 2 && now.day - date.day == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        return weekdays[date.weekday - 1];
      } else {
        return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year.toString().substring(2)}';
      }
    } catch (_) {
      return '';
    }
  }
}
