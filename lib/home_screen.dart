import 'package:chat_application/chatPage.dart';
import 'package:chat_application/providers/login_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'Authentication pages/profile.dart';
import 'groups.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late DatabaseReference chatRef;
  Map<String, List<Map<String, dynamic>>> userMessages = {};
  String? imageUrl;
  String? userId = FirebaseAuth.instance.currentUser?.uid;
  List<Map<dynamic, dynamic>> usersList = []; // List of all users
  List<Map<dynamic, dynamic>> filteredUsersList = []; // Filtered users based on search
  String searchQuery = ''; // Search query for filtering

  @override
  void initState() {
    super.initState();
    Provider.of<LoginProvider>(context, listen: false).fetchUserDetails();
    _fetchAllMessages(); // Fetch messages for all users once
    _fetchAllUsers(); // Fetch all users once
  }

  String _getChatId(String senderId, String receiverId) {
    return senderId.hashCode <= receiverId.hashCode
        ? '${senderId}_${receiverId}'
        : '${receiverId}_${senderId}';
  }

  void _fetchMessages(String senderId, String receiverId) {
    String chatId = _getChatId(senderId, receiverId);
    chatRef = FirebaseDatabase.instance.ref('chats/$chatId/messages');

    chatRef.onValue.listen((DatabaseEvent event) {
      final data = event.snapshot.value;
      if (data != null) {
        List<Map<String, dynamic>> messages = [];
        (data as Map<dynamic, dynamic>).forEach((key, value) {
          if (value is Map) {
            messages.add(value.cast<String, dynamic>());
          }
        });

        // Sort messages by time (latest first)
        messages.sort((a, b) => DateTime.parse(b['time']).compareTo(DateTime.parse(a['time'])));

        // Store messages in the map with userId as key
        setState(() {
          userMessages[receiverId] = messages;
        });
      }
    });
  }

  void _fetchAllUsers() {
    final databaseRef = FirebaseDatabase.instance.ref('users');

    databaseRef.onValue.listen((DatabaseEvent event) {
      final data = event.snapshot.value;
      if (data != null) {
        usersList.clear();
        (data as Map<dynamic, dynamic>).forEach((key, value) {
          usersList.add(value);
        });
        setState(() {
          filteredUsersList = usersList; // Initialize filtered list
        });
      }
    });
  }

  void _fetchAllMessages() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final databaseRef = FirebaseDatabase.instance.ref('users');

    databaseRef.onValue.listen((DatabaseEvent event) {
      final data = event.snapshot.value;
      if (data != null) {
        (data as Map<dynamic, dynamic>).forEach((key, value) {
          if (value['uid'] != uid) { // Exclude current user
            _fetchMessages(uid!, value['uid']); // Fetch messages for each user
          }
        });
      }
    });
  }

  void _filterUsers(String query) {
    final filtered = usersList.where((user) {
      final name = user['name']?.toLowerCase() ?? '';
      return name.contains(query.toLowerCase());
    }).toList();

    setState(() {
      filteredUsersList = filtered;
    });
  }

  @override
  Widget build(BuildContext context) {
    final loginProvider = Provider.of<LoginProvider>(context);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    imageUrl = loginProvider.profileImageUrl;

    return Scaffold(
      appBar: AppBar(
        elevation: 90,
        iconTheme: IconThemeData(color: Colors.white),
        toolbarHeight: 80,
        backgroundColor: Colors.grey[500],
        title: Center(
          child: Text(
            'Messages',
            style: TextStyle(color: Colors.white, fontFamily: 'Lora', fontSize: 30),
          ),
        ),
        actions: [
          IconButton(
            iconSize: 40,
            onPressed: () {
              loginProvider.logout(context);
            },
            icon: Icon(Icons.logout, color: Colors.white),
          ),
        ],
      ),
      drawer: Drawer(
        child: Container(
          color: Colors.grey[900],
          child: Column(
            children: [
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.3,
                width: double.infinity,
                child: DrawerHeader(
                  decoration: BoxDecoration(color: Colors.grey[850]),
                  child: Container(
                    height: 220,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        (imageUrl!.isNotEmpty && imageUrl != null)
                            ? CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.white,
                          backgroundImage: NetworkImage(imageUrl!),
                        )
                            : CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.white,
                          child: Icon(Icons.person, color: Colors.white),
                        ),
                        SizedBox(height: 10),
                        Text(
                          loginProvider.userName,
                          style: TextStyle(color: Colors.white, fontSize: 20),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          loginProvider.userEmail,
                          style: TextStyle(color: Colors.white70),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    ListTile(
                      leading: Icon(Icons.home, color: Colors.white),
                      title: Text('Home', style: TextStyle(color: Colors.white)),
                      onTap: () => Navigator.pop(context),
                    ),
                    ListTile(
                      leading: Icon(Icons.person, color: Colors.white),
                      title: Text('Profile', style: TextStyle(color: Colors.white)),
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) {
                          return ProfilePage();
                        }));
                      },
                    ),
                    ListTile(
                      leading: Icon(Icons.group, color: Colors.white),
                      title: Text('Groups', style: TextStyle(color: Colors.white)),
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) {
                          return GroupsPage();
                        }));
                      },
                    ),
                    Divider(color: Colors.white),
                    ListTile(
                      leading: Icon(Icons.logout, color: Colors.white),
                      title: Text('Logout', style: TextStyle(color: Colors.white)),
                      onTap: () {
                        loginProvider.logout(context);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(
                labelText: 'Search Users',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: _filterUsers, // Update search on text change
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: filteredUsersList.length,
              itemBuilder: (context, index) {
                final user = filteredUsersList[index];

                if (user['email'].toString().toLowerCase() != FirebaseAuth.instance.currentUser?.email) {
                  final messages = userMessages[user['uid']]?.reversed ?? []; // Get messages for user
                  return Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(),
                        borderRadius: BorderRadius.all(Radius.circular(20)),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          radius: 40,
                          backgroundImage: NetworkImage(user['imageUrl'] ?? ''),
                        ),
                        title: Text(
                          user['name'] ?? 'No Name',
                          style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
                        ),
                        subtitle: messages.isNotEmpty
                            ? messages.last.containsKey('mediaUrl')
                            ? Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            Icon(Icons.image),
                            Text(' photo')
                          ],
                        )
                            : Text(messages.last['text'] ?? 'no message')
                            : Text('No messages'),
                        trailing: messages.isNotEmpty && messages.last['time'] != null
                            ? Text(
                          DateTime.parse(messages.last['time']).toLocal().toString().split(' ')[1].substring(0, 5),
                          style: TextStyle(color: Colors.black54),
                        )
                            : null,
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) {
                            return ChatPage(user['uid'], userId!);
                          }));
                        },
                      ),
                    ),
                  );
                } else {
                  return SizedBox.shrink();
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
