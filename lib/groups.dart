import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import 'groupchat.dart';

class GroupsPage extends StatefulWidget {
  @override
  _GroupsPageState createState() => _GroupsPageState();
}

class _GroupsPageState extends State<GroupsPage> {
  final DatabaseReference _groupsRef = FirebaseDatabase.instance.ref('groups');
  final DatabaseReference _usersRef = FirebaseDatabase.instance.ref('users'); // Reference to users node
  List<Map<dynamic, dynamic>> _groupsList = [];

  @override
  void initState() {
    super.initState();
    _fetchGroups();
  }

  // Fetch groups from Firebase based on the current user
  Future<void> _fetchGroups() async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId != null) {
      DatabaseEvent event = await _groupsRef.once();
      final data = event.snapshot.value;

      if (data != null) {
        _groupsList = [];
        (data as Map<dynamic, dynamic>).forEach((key, value) {
          if (value['members'] != null && value['members'][currentUserId] == true) {
            value['id'] = key; // Store the group ID
            _groupsList.add(value);
          }
        });
      }
      setState(() {});
    }
  }

  // Create a new group
  void _createGroup() {
    String groupName = '';
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Create New Group'),
          content: TextField(
            onChanged: (value) {
              groupName = value;
            },
            decoration: InputDecoration(hintText: "Group Name"),
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (groupName.isNotEmpty) {
                  // Add the group to Firebase and retrieve the key
                  String id = _groupsRef.push().key.toString();
                  _groupsRef.child(id).set({
                    'name': groupName,
                    'members': {
                      FirebaseAuth.instance.currentUser?.uid: true, // Add current user as a member
                    },
                    'id': id,
                  }).then((value) {
                    Navigator.of(context).pop(); // Close the dialog
                    _fetchGroups(); // Refresh the groups list
                  });
                }
              },
              child: Text('Create'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
              child: Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  // Add members to the group
  void _addMember(String groupId) {
    String email = '';
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Add Member to Group'),
          content: TextField(
            onChanged: (value) {
              setState(() {
                email = value;
              });
            },
            decoration: InputDecoration(hintText: "User Email"),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                if (email.isNotEmpty) {
                  // Find the user by email
                  final snapshot = await _usersRef
                      .orderByChild('email')
                      .equalTo(email.toLowerCase())
                      .get();

                  final userData = snapshot.value;
                  if (userData != null) {
                    // Assuming userData contains only one user
                    final userId = (userData as Map<dynamic, dynamic>).keys.first;

                    // Add member to the group
                    await _groupsRef.child(groupId).child('members').child(userId).set(true);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Member added successfully!')),
                    );

                    // Close the dialog
                    Navigator.of(context).pop();

                    // Optionally, refresh the group member list if needed
                    _fetchGroups();
                  } else {
                    // Show error if user not found
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('User not found')),
                    );
                  }
                }
              },
              child: Text('Add'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
              child: Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 90,
        iconTheme: IconThemeData(color: Colors.white,size: 40),
        toolbarHeight: 80,
        backgroundColor: Colors.grey[500],
        title: Text('Groups',style: TextStyle(color: Colors.white, fontFamily: 'Lora', fontSize: 30),),
        actions: [
          IconButton(
            icon: Icon(Icons.add,),
            onPressed: _createGroup, // Call create group function
          ),
        ],
      ),
      body: _groupsList.isEmpty
          ? Center(child: Text('No groups available yet.'))
          : ListView.builder(
        itemCount: _groupsList.length,
        itemBuilder: (context, index) {
          final group = _groupsList[index];
          return Padding(
            padding: const EdgeInsets.all(8.0),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(),
                borderRadius: BorderRadius.all(Radius.circular(20)),
              ),
              child: ListTile(
                title: Text(group['name'],style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
                trailing: IconButton(
                  icon: Icon(Icons.add,size: 30,),
                  onPressed: () {
                    _addMember(group['id']); // Call function to add member
                  },
                ),
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) {
                    return GroupChatPage(groupId: group['id'], groupName: group['name'],);
                  },));
                  // Navigate to group chat page or other functionality
                  // Example: Navigator.push(context, MaterialPageRoute(builder: (context) => GroupChatPage(group['id'])));
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
