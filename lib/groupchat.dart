import 'dart:html' as html; // Add this for web functionality
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class GroupChatPage extends StatefulWidget {
  final String groupId;
  final String groupName;

  GroupChatPage({required this.groupId, required this.groupName});

  @override
  _GroupChatPageState createState() => _GroupChatPageState();
}

class _GroupChatPageState extends State<GroupChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final DatabaseReference _groupsRef = FirebaseDatabase.instance.ref('groups');
  final DatabaseReference _usersRef = FirebaseDatabase.instance.ref('users');
  final User? currentUser = FirebaseAuth.instance.currentUser;
  final ImagePicker _picker = ImagePicker();
  List<Map<dynamic, dynamic>> _messagesList = [];
  List<Map<dynamic, dynamic>> _groupMembersList = [];
  DateTime? _lastDisplayedDate;

  @override
  void initState() {
    super.initState();
    _listenForMessages();
    _fetchGroupMembers();
  }

  void _listenForMessages() {
    _groupsRef.child(widget.groupId).child('messages').onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      _messagesList.clear();
      if (data != null) {
        data.forEach((key, value) {
          _messagesList.add({...value, 'key': key}); // Include the key in the message data
        });
        _messagesList.sort((a, b) => a['timestamp'].compareTo(b['timestamp']));
      }
      setState(() {});
    });
  }

  void _fetchGroupMembers() {
    _groupsRef.child(widget.groupId).child('members').onValue.listen((event) async {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      _groupMembersList.clear();
      if (data != null) {
        for (var memberId in data.keys) {
          final userSnapshot = await _usersRef.child(memberId).get();
          if (userSnapshot.exists) {
            final userData = userSnapshot.value as Map<dynamic, dynamic>;
            _groupMembersList.add({
              'uid': memberId,
              'name': userData['name'],
              'email': userData['email'],
            });
          }
        }
      }
      setState(() {});
    });
  }

  void _showGroupMembersDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Group Members'),
          content: _groupMembersList.isEmpty
              ? Text('No members in this group.')
              : Container(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _groupMembersList.length,
              itemBuilder: (context, index) {
                final member = _groupMembersList[index];
                return ListTile(
                  leading: Icon(Icons.person),
                  title: Text(member['name'] ?? 'Unknown'),
                  subtitle: Text(member['email'] ?? ''),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.isNotEmpty) {
      String message = _messageController.text.trim();
      String messageId = _groupsRef.child(widget.groupId).child('messages').push().key ?? '';

      final userSnapshot = await _usersRef.child(currentUser!.uid).get();
      final userName = userSnapshot.child('name').value as String?;

      _groupsRef.child(widget.groupId).child('messages').child(messageId).set({
        'senderId': currentUser?.uid,
        'senderName': userName ?? 'Unknown',
        'message': message,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'deleted': false, // Add deleted flag
      }).then((_) {
        _messageController.clear();
      });
    }
  }

  Future<void> _sendMedia() async {
    if (kIsWeb) {
      // Web-specific implementation for file selection
      html.FileUploadInputElement uploadInput = html.FileUploadInputElement();
      uploadInput.accept = 'image/*'; // Accept images
      uploadInput.click();

      uploadInput.onChange.listen((e) async {
        final files = uploadInput.files;
        if (files!.isEmpty) return;

        final reader = html.FileReader();
        reader.readAsArrayBuffer(files[0]!);

        reader.onLoadEnd.listen((e) async {
          final bytes = reader.result as Uint8List;
          final fileName = files[0]!.name;

          // Create a reference to the storage location
          Reference storageRef = FirebaseStorage.instance.ref('group_media/$fileName');
          await storageRef.putData(bytes);

          String downloadUrl = await storageRef.getDownloadURL();
          String messageId = _groupsRef.child(widget.groupId).child('messages').push().key ?? '';

          final userSnapshot = await _usersRef.child(currentUser!.uid).get();
          final userName = userSnapshot.child('name').value as String?;

          _groupsRef.child(widget.groupId).child('messages').child(messageId).set({
            'senderId': currentUser?.uid,
            'senderName': userName ?? 'Unknown',
            'mediaUrl': downloadUrl,
            'timestamp': DateTime.now().millisecondsSinceEpoch,
            'deleted': false, // Add deleted flag
          });
        });
      });
    } else {
      // Mobile-specific implementation for media selection
      final XFile? mediaFile = await _picker.pickImage(source: ImageSource.gallery);
      if (mediaFile != null) {
        String fileName = mediaFile.name;
        Reference storageRef = FirebaseStorage.instance.ref('group_media/$fileName');

        await storageRef.putFile(File(mediaFile.path));

        String downloadUrl = await storageRef.getDownloadURL();
        String messageId = _groupsRef.child(widget.groupId).child('messages').push().key ?? '';

        final userSnapshot = await _usersRef.child(currentUser!.uid).get();
        final userName = userSnapshot.child('name').value as String?;

        _groupsRef.child(widget.groupId).child('messages').child(messageId).set({
          'senderId': currentUser?.uid,
          'senderName': userName ?? 'Unknown',
          'mediaUrl': downloadUrl,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'deleted': false, // Add deleted flag
        });
      }
    }
  }

  String _formatTimestamp(int timestamp) {
    var date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return DateFormat('h:mm a').format(date);
  }

  String _formatDate(int timestamp) {
    var date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return DateFormat('MMMM d, y').format(date);
  }

  Widget _buildMessageBubble(Map<dynamic, dynamic> message, bool isMe) {
    final messageDate = DateTime.fromMillisecondsSinceEpoch(message['timestamp']);
    bool showDate = _lastDisplayedDate == null ||
        messageDate.day != _lastDisplayedDate?.day ||
        messageDate.month != _lastDisplayedDate?.month ||
        messageDate.year != _lastDisplayedDate?.year;

    if (showDate) {
      _lastDisplayedDate = messageDate; // Update the last displayed date
    }

    return GestureDetector(
      onLongPress: (){
        if (isMe&&message['deleted'] != true && isMe){
          _showDeleteConfirmationDialog(message['key']);
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showDate)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5.0),
              child: Center(
                child: Text(
                  _formatDate(message['timestamp']),
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54),
                ),
              ),
            ),
          Align(
            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              margin: EdgeInsets.symmetric(vertical: 5.0, horizontal: 8.0),
              padding: EdgeInsets.all(10.0),
              decoration: BoxDecoration(
                color: isMe ? Colors.blueAccent : Colors.grey[300],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (!isMe)
                    Text(
                      message['senderName'] ?? 'Unknown',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  SizedBox(height: 5),
                  if (message['deleted'] == true) // Check if the message is deleted
                    Text(
                      'Message deleted',
                      style: TextStyle(
                        color: Colors.red,
                      ),
                    )
                  else if (message.containsKey('mediaUrl')) // Check if the message has media
                    Container(
                      height: 200,
                      width: 200,
                      child: Image.network(message['mediaUrl']),
                    )
                  else
                    Text(
                      message['message'] ?? '',
                      style: TextStyle(color: Colors.black),
                    ),
                  Text(
                    _formatTimestamp(message['timestamp']),
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.black54,
                    ),
                  ),
                  // Add the delete message button


                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showDeleteConfirmationDialog(String messageId) async {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Delete Message'),
          content: Text('Are you sure you want to delete this message?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                _deleteMessage(messageId); // Proceed to delete the message
                Navigator.of(context).pop(); // Close the dialog
              },
              child: Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteMessage(String messageId) async {
    // Update the message to mark it as deleted
    await _groupsRef.child(widget.groupId).child('messages').child(messageId).update({
      'deleted': true,
      'message': 'Message deleted', // Change the message text
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.groupName),
        actions: [
          IconButton(
            icon: Icon(Icons.group),
            onPressed: _showGroupMembersDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _messagesList.length,
              itemBuilder: (context, index) {
                final message = _messagesList[index];
                bool isMe = message['senderId'] == currentUser?.uid;
                return _buildMessageBubble(message, isMe);
              },
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
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.photo),
                  onPressed: _sendMedia,
                ),
                IconButton(
                  icon: Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
