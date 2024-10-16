import 'package:chat_application/Authentication%20pages/LoginPage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import '../home_screen.dart';

class LoginProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _dref = FirebaseDatabase.instance.ref("users");
  String _userName = '';
  String _userEmail = '';
  String _profileImageUrl = '';
  String _uid= '';

  bool _status = false;

  String get profileImageUrl => _profileImageUrl;
  bool get status => _status;
  String get userName => _userName;
  String get userEmail => _userEmail;
  String get uid => _uid;


  Future<void> fetchUserDetails() async {
    User? user = _auth.currentUser;

    if (user != null) {
      DatabaseEvent event = await _dref.child(user.uid).once();
      final userData = event.snapshot.value as Map<dynamic, dynamic>;

      _userName = userData['name'] ?? 'User Name';
      _userEmail = userData['email'] ?? 'user@example.com';
      _profileImageUrl = userData['imageUrl'] ?? '';
      _uid = userData['uid'];

      notifyListeners();
    }
  }

  Future<void> signIn(String email, String password, BuildContext context) async {
    _status = true;
    notifyListeners();

    try {
      UserCredential userCredential =
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      User? user = userCredential.user;

      if (user != null) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => HomeScreen()),
              (Route<dynamic> route) => false, // Remove all previous routes
        );
      }
    } catch (e) {
      throw e; // Rethrow error for handling in UI
    } finally {
      _status = false;
      notifyListeners();
    }
  }

  Future<void> logout(BuildContext context) async {
    User? user = _auth.currentUser;
    await _auth.signOut();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => Login()),
          (Route<dynamic> route) => false, // This will remove all previous routes
    ).then((value) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Logged out'),
      ));
    });
  }

  Future<void> updateUserProfile(String name, String email, String? imageUrl) async {
    User? user = _auth.currentUser; // Get the current user
    if (user != null) {
      try {
        // Update the user's information in the Realtime Database
        await _dref.child('${user.uid}').update({
          'name': name,
          'email': email,
          'imageUrl': imageUrl, // Save the new image URL
        });
        await fetchUserDetails(); // Refresh user details after updating
        notifyListeners(); // Notify listeners after updating
      } catch (e) {
        print("Error updating user profile: $e");
      }
    }
  }
}
