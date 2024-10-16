import 'dart:io';
import 'package:chat_application/providers/login_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  dynamic pickfile; // Variable for storing picked file for web
  File? file; // Variable for storing picked file for mobile
  final storref = FirebaseStorage.instance;
  String? img1;

  @override
  void initState() {
    super.initState();
    // Fetch user details to pre-fill the form
    final loginProvider = Provider.of<LoginProvider>(context, listen: false);
    loginProvider.fetchUserDetails();
  }

  Future<void> uploadImage() async {
    await _pickImage();
    try {
      if (file != null || pickfile != null) {
        User? user = FirebaseAuth.instance.currentUser;
        Reference storageRef = storref.ref().child("profile_images/${user?.uid}.jpg");
        await storageRef.delete();

        final imageRef = storref.ref().child("profile_images/${user?.uid}.jpg");
        UploadTask uploadTask;

        if (kIsWeb) {
          final byte = await pickfile.readAsBytes();
          uploadTask = imageRef.putData(byte);
        } else {
          uploadTask = imageRef.putFile(file!);
        }

        final snapshot = await uploadTask.whenComplete(() {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Image Uploaded")));
        });

        img1 = await snapshot.ref.getDownloadURL();
        print("Image URL: $img1");


      }
    } catch (e) {
      print("Error uploading image: $e");
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker imagePicker = ImagePicker();
    final image = await imagePicker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      if (kIsWeb) {
        setState(() {
          pickfile = image; // Set picked file for web
        });
      } else {
        setState(() {
          file = File(image.path); // Set picked file for mobile
        });
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("No Image Selected")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final loginProvider = Provider.of<LoginProvider>(context, listen: false);
    loginProvider.fetchUserDetails();
    String img = loginProvider.profileImageUrl; // Get the current profile image URL

    // Initialize controllers with user details
    _nameController.text = loginProvider.userName;
    _emailController.text = loginProvider.userEmail;

    return Scaffold(
      appBar: AppBar(
        title: Text('Profile'),
        backgroundColor: Colors.grey[300],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: uploadImage, // Open the image picker
                child: Center(
                  child: (file != null || pickfile != null || img.isNotEmpty)
                      ? CircleAvatar(
                    radius: 60,
                    backgroundImage: (file != null)
                        ? FileImage(file!)
                        : (kIsWeb && pickfile != null)
                        ? NetworkImage(pickfile.path) as ImageProvider
                        : NetworkImage(img),
                    child: (file == null && pickfile == null)
                        ? Icon(Icons.upload_outlined, size: 40)
                        : null,
                  )
                      : CircleAvatar(
                    radius: 60,
                    child: Icon(
                      Icons.upload_outlined,
                      size: 40,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 20),
              Text(
                'Name',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: 'Enter your name',
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.grey[200],
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Email',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              TextField(
                readOnly: true,
                controller: _emailController,
                decoration: InputDecoration(
                  hintText: 'Enter your email',
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.grey[200],
                ),
              ),
              SizedBox(height: 16),
              Center(
                child: ElevatedButton(
                  onPressed: () async {
                    if(img1==null){
                      setState(() {
                        img1=img;
                      });
                    }
                    await loginProvider.updateUserProfile(
                      _nameController.text,
                      _emailController.text,
                      img1
                    );
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Profile updated successfully!'),
                    ));
                  },
                  child: Text(
                    'Update Profile',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    padding: EdgeInsets.symmetric(horizontal: 40, vertical: 10),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
