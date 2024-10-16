import 'dart:io';
import 'package:chat_application/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_database/firebase_database.dart'; // Import for Firebase Realtime Database
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';

class SignupProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final DatabaseReference _database = FirebaseDatabase.instance.ref(); // Reference to Firebase Realtime Database

  TextEditingController nameController = TextEditingController();
  TextEditingController emailController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  TextEditingController confirmPasswordController = TextEditingController();

  bool _status = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  File? file;
  dynamic pickfile;

  bool get status => _status;
  bool get obscurePassword => _obscurePassword;
  bool get obscureConfirmPassword => _obscureConfirmPassword;

  set obscurePassword(bool value) {
    _obscurePassword = value;
    notifyListeners();
  }

  set obscureConfirmPassword(bool value) {
    _obscureConfirmPassword = value;
    notifyListeners();
  }

  Future<void> pickImage() async {
    final ImagePicker imagePicker = ImagePicker();
    final image = await imagePicker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      if (kIsWeb) {
        pickfile = image;
      } else {
        file = File(image.path);
      }
      notifyListeners();
    }
  }

  void clearImage() {
    file = null;
    pickfile = null;
    notifyListeners();
  }

  Future<void> signUp(BuildContext context) async {
    _status = true;
    notifyListeners();

    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: emailController.text,
        password: passwordController.text,
      );
      User? user = userCredential.user;

      if (user != null) {
        String? imageUrl;

        // Upload image to Firebase Storage and get the download URL
        if (file != null || pickfile != null) {
          final storref = FirebaseStorage.instance;
          final imageRef = storref.ref().child("profile_images/${user.uid}.jpg");
          UploadTask uploadTask;
          if (kIsWeb) {
            final byte = await pickfile.readAsBytes();
            uploadTask = imageRef.putData(byte);
          } else {
            uploadTask = imageRef.putFile(file!);
          }

          final snapshot = await uploadTask.whenComplete(() {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text("Image Uploaded")));
          });

          imageUrl = await snapshot.ref.getDownloadURL();
          print("Image URL: $imageUrl");
        }

        // Save user information to Firebase Realtime Database
        await _database.child('users').child(user.uid).set({
          'name': nameController.text,
          'email': emailController.text.toString().toLowerCase(),
          'imageUrl': imageUrl, // Store the image URL
          'uid': user.uid
          // Add any other user information you want to save
        });

        // Navigate to the next screen
        Navigator.push(context, MaterialPageRoute(builder: (context) {
          return HomeScreen();
        },));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      _status = false;
      notifyListeners();
    }
  }
}
