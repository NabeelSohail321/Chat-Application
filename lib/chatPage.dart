import 'dart:html' as html; // Import for web
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class ChatPage extends StatefulWidget {
  final String receiverId;
  final String senderId;

  const ChatPage(this.receiverId, this.senderId, {Key? key}) : super(key: key);

  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  List<Map<String, dynamic>> messages = [];
  String currentUserEmail = FirebaseAuth.instance.currentUser?.email ?? "user@example.com";
  String receiverName = "";
  late DatabaseReference chatRef;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _fetchReceiverInfo();
    _initializeChat();
    _fetchMessages();
  }

  void _fetchReceiverInfo() async {
    final DatabaseReference userRef = FirebaseDatabase.instance.ref('users/${widget.receiverId}');
    final snapshot = await userRef.get();
    if (snapshot.exists) {
      final userData = snapshot.value as Map<dynamic, dynamic>;
      setState(() {
        receiverName = userData['name'] ?? 'Unknown';
      });
    }
  }

  void _initializeChat() {
    String chatId = _getChatId(widget.senderId, widget.receiverId);
    chatRef = FirebaseDatabase.instance.ref('chats/$chatId/messages');
  }

  String _getChatId(String senderId, String receiverId) {
    return senderId.hashCode <= receiverId.hashCode
        ? '${senderId}_${receiverId}'
        : '${receiverId}_${senderId}';
  }

  void _fetchMessages() {
    chatRef.onValue.listen((DatabaseEvent event) {
      final data = event.snapshot.value;
      if (data != null) {
        messages.clear();
        (data as Map<dynamic, dynamic>).forEach((key, value) {
          if (value is Map) {
            messages.add(value.cast<String, dynamic>()..['key'] = key); // Store the message key
          }
        });
        messages.sort((a, b) => DateTime.parse(a['time']).compareTo(DateTime.parse(b['time'])));
        setState(() {});
      } else {
        print("No messages found.");
      }
    });
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.isNotEmpty) {
      final now = DateTime.now();
      final messageData = {
        'sender': currentUserEmail,
        'text': _messageController.text,
        'time': now.toString(),
        'date': '${now.year}-${now.month}-${now.day}', // Storing date
      };
      chatRef.push().set(messageData).then((_) {
        _messageController.clear();
      }).catchError((error) {
        print("Error sending message: $error");
      });
    } else {
      print("Message is empty.");
    }
  }

  Future<void> _sendMedia() async {
    if (kIsWeb) {
      // Web implementation
      html.FileUploadInputElement uploadInput = html.FileUploadInputElement();
      uploadInput.accept = 'image/*,video/*'; // Accept images and videos
      uploadInput.click();

      uploadInput.onChange.listen((e) async {
        final files = uploadInput.files;
        if (files!.isEmpty) return;

        final reader = html.FileReader();
        reader.readAsArrayBuffer(files[0]);
        reader.onLoadEnd.listen((e) async {
          final bytes = reader.result as Uint8List;

          // Upload media to Firebase Storage
          String fileName = files[0].name;
          Reference storageRef = FirebaseStorage.instance.ref('chat_media/$fileName');
          await storageRef.putData(bytes);

          // Get the download URL
          String downloadUrl = await storageRef.getDownloadURL();

          // Create a message data with the media URL
          final now = DateTime.now();
          final mediaMessageData = {
            'sender': currentUserEmail,
            'mediaUrl': downloadUrl,
            'time': now.toString(),
            'date': '${now.year}-${now.month}-${now.day}', // Storing date
          };

          // Push the media message to Firebase
          chatRef.push().set(mediaMessageData).then((_) {
            setState(() {}); // Optionally, update the state
          }).catchError((error) {
            print("Error sending media: $error");
          });
        });
      });
    } else {
      // Mobile implementation
      final XFile? mediaFile = await _picker.pickImage(source: ImageSource.gallery);
      if (mediaFile != null) {
        // Upload media to Firebase Storage
        String fileName = mediaFile.name;
        Reference storageRef = FirebaseStorage.instance.ref('chat_media/$fileName');
        await storageRef.putFile(File(mediaFile.path));

        // Get the download URL
        String downloadUrl = await storageRef.getDownloadURL();

        // Create a message data with the media URL
        final now = DateTime.now();
        final mediaMessageData = {
          'sender': currentUserEmail,
          'mediaUrl': downloadUrl,
          'time': now.toString(),
          'date': '${now.year}-${now.month}-${now.day}', // Storing date
        };

        // Push the media message to Firebase
        chatRef.push().set(mediaMessageData).then((_) {
          setState(() {}); // Optionally, update the state
        }).catchError((error) {
          print("Error sending media: $error");
        });
      }
    }
  }

  Future<void> _confirmDeleteMessage(String messageKey) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Delete Message'),
          content: Text('Are you sure you want to delete this message?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('Delete'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancel'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      _deleteMessage(messageKey);
    }
  }

  Future<void> _deleteMessage(String messageKey) async {
    // Update the message to indicate it has been deleted
    await chatRef.child(messageKey).update({'text': 'Message deleted', 'isDeleted': true}).then((_) {
      print("Message deleted successfully.");
    }).catchError((error) {
      print("Error deleting message: $error");
    });
  }

  Widget _buildMessageItem(Map<String, dynamic> message, {String? displayedDate}) {
    final isMe = message['sender'] == currentUserEmail;

    // Check if the message is marked as deleted
    bool isDeleted = message['isDeleted'] == true;
    String deletedMessage = message['time'];

    return GestureDetector(
      onLongPress: (){
        (!isDeleted && isMe)? _confirmDeleteMessage(message['key']):null;
      },
      child: Column(
        children: [
          if (displayedDate != null) // Only display the date if it's not null
            Center(
              child: Text(
                displayedDate,
                style: TextStyle(color: Colors.black54, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ListTile(
            title: Align(
              alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 10, horizontal: 15),
                margin: EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                decoration: BoxDecoration(
                  color: isMe ? Colors.blue[300] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [

                    Column(
                      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: [
                        if (!isDeleted) // Show the original message if not deleted
                          Text(
                            message['text'] ?? '',
                            style: TextStyle(color: Colors.black, fontSize: 16),
                          ),
                        if (isDeleted) // Show "Message deleted" if the message is deleted
                          Text(
                            'Message deleted',
                            style: TextStyle(color: Colors.red, fontSize: 16, fontStyle: FontStyle.italic),
                          ),
                        if (message.containsKey('mediaUrl') && !isDeleted)
                          Image.network(
                            message['mediaUrl'],
                            width: 200,
                            height: 200,
                            fit: BoxFit.cover,
                          ),
                        SizedBox(height: 5),
                         // Show time if the message is not deleted
                          Text(
                            message['time'] != null
                                ? DateTime.parse(message['time']).toLocal().toString().split(' ')[1].substring(0, 5)
                                : '',
                            style: TextStyle(color: Colors.black54, fontSize: 12),
                          ),
                        // Add delete button if the message is sent by the current user

                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String? lastDisplayedDate;

    return Scaffold(
      appBar: AppBar(
        elevation: 90,
        iconTheme: IconThemeData(color: Colors.white),
        toolbarHeight: 80,
        backgroundColor: Colors.grey[500],
        title: Text(receiverName, style: TextStyle(color: Colors.white)),
      ),
      body: Column(
        children: [
          messages.isNotEmpty
              ? Expanded(
            child: ListView.builder(
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final message = messages[index];

                // Check if the message's date is different from the last displayed date
                final messageDate = DateTime.parse(message['time']).toLocal();
                String displayDate = '${messageDate.day}/${messageDate.month}/${messageDate.year}';

                // Determine if we should show the date
                if (lastDisplayedDate == null || lastDisplayedDate != displayDate) {
                  lastDisplayedDate = displayDate;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildMessageItem(message, displayedDate: displayDate), // Show message with date
                    ],
                  );
                } else {
                  return _buildMessageItem(message); // Only display message without date
                }
              },
            ),
          )
              : Expanded(
            child: Center(
              child: Text("No messages yet."),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Type a message',
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
                IconButton(
                  icon: Icon(Icons.photo),
                  onPressed: _sendMedia,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
