import 'package:chat_application/Authentication%20pages/LoginPage.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({Key? key}) : super(key: key);

  @override
  _SignupScreenState createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>(); // Form key for validation

  // Define FocusNodes
  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();
  final FocusNode _confirmPasswordFocusNode = FocusNode();

  @override
  void dispose() {
    // Clean up the FocusNodes when the widget is disposed
    _nameFocusNode.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final signupProvider = Provider.of<SignupProvider>(context);
    final height = MediaQuery.of(context).size.height;
    final width = MediaQuery.of(context).size.width;

    return Scaffold(
      resizeToAvoidBottomInset: true, // Ensures the content resizes when the keyboard appears
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          'Chat Zone',
          style: TextStyle(
            fontSize: height * 0.05,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        toolbarHeight: height * 0.1,
      ),
      body: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus(); // Dismisses the keyboard when tapping outside
        },
        child: SingleChildScrollView(
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: width * 0.1),
            child: Column(
              children: [
                SizedBox(height: height * 0.03),
                (signupProvider.file != null || signupProvider.pickfile != null)
                    ? CircleAvatar(
                  radius: 60,
                  child: Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.all(Radius.circular(60)),
                          image: DecorationImage(
                            image: signupProvider.pickfile != null
                                ? NetworkImage(signupProvider.pickfile.path) as ImageProvider
                                : FileImage(signupProvider.file!),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: -10,
                        right: -3,
                        child: IconButton(
                          onPressed: signupProvider.clearImage,
                          icon: Icon(Icons.delete, color: Colors.red, size: 30),
                        ),
                      ),
                    ],
                  ),
                )
                    : InkWell(
                  onTap: signupProvider.pickImage,
                  child: CircleAvatar(
                    radius: 60,
                    child: Icon(
                      Icons.upload_outlined,
                      size: 40,
                    ),
                  ),
                ),
                SizedBox(height: height * 0.03),
                Form(
                  key: _formKey, // Use the same form key
                  child: Column(
                    children: [
                      _buildTextFormField(signupProvider.nameController, 'Name', height, _nameFocusNode),
                      SizedBox(height: height * 0.02),
                      _buildEmailField(signupProvider.emailController, 'Email', height, _emailFocusNode),
                      SizedBox(height: height * 0.02),
                      Consumer<SignupProvider>(
                        builder: (context, signupProvider, child) {
                          return _buildPasswordField(signupProvider, signupProvider.passwordController, 'Password',
                              signupProvider.obscurePassword, _passwordFocusNode);
                        },
                      ),
                      SizedBox(height: height * 0.02),
                      Consumer<SignupProvider>(
                        builder: (context, signupProvider, child) {
                          return _buildPasswordField(
                              signupProvider,
                              signupProvider.confirmPasswordController,
                              'Confirm Password',
                              signupProvider.obscureConfirmPassword,
                              _confirmPasswordFocusNode);
                        },
                      ),
                      SizedBox(height: height * 0.02),
                      SizedBox(
                        height: 50,
                        width: 200,
                        child: signupProvider.status == false
                            ? ElevatedButton(
                          onPressed: () async {
                            if (_formKey.currentState!.validate()) {
                              if (signupProvider.passwordController.text !=
                                  signupProvider.confirmPasswordController.text) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Passwords do not match!'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              } else {
                                await signupProvider.signUp(context);
                              }
                            }
                          },
                          child: Text(
                            'Sign Up',
                            style: TextStyle(
                                fontSize: 25,
                                fontFamily: 'Ubuntu',
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
                        )
                            : Center(
                          child: SizedBox(
                            height: 30, // Set height
                            width: 30, // Set width
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue), // Set color
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Already have an account?'),
                            TextButton(
                              onPressed: () {
                                Navigator.push(context, MaterialPageRoute(
                                  builder: (context) {
                                    return Login();
                                  },
                                ));
                              },
                              child: Text(
                                'Login',
                                style: TextStyle(color: Colors.blue),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextFormField(
      TextEditingController controller, String label, double height, FocusNode focusNode) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode, // Assign the focus node
      decoration: InputDecoration(
        labelText: label,
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: Colors.black12,
            width: 1.0,
          ),
          borderRadius: BorderRadius.circular(10.0),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: Colors.black12,
            width: 1.0,
          ),
          borderRadius: BorderRadius.circular(10.0),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your $label';
        }
        return null;
      },
    );
  }

  Widget _buildPasswordField(SignupProvider signupProvider, TextEditingController controller, String label,
      bool obscureText, FocusNode focusNode) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode, // Assign the focus node
      decoration: InputDecoration(
        labelText: label,
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: Colors.black12,
            width: 1.0,
          ),
          borderRadius: BorderRadius.circular(10.0),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: Colors.black12,
            width: 1.0,
          ),
          borderRadius: BorderRadius.circular(10.0),
        ),
        suffixIcon: IconButton(
          icon: Icon(
            obscureText ? Icons.visibility : Icons.visibility_off,
          ),
          onPressed: () {
            if (label == 'Password') {
              setState(() {
                signupProvider.obscurePassword = !obscureText;
              });
            } else {
              setState(() {
                signupProvider.obscureConfirmPassword = !obscureText;
              });
            }
          },
        ),
      ),
      obscureText: obscureText,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your $label';
        } else if (value.length < 8) {
          return 'Your $label must be at least 8 characters long';
        }
        return null;
      },
    );
  }

  Widget _buildEmailField(
      TextEditingController controller, String label, double height, FocusNode focusNode) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode, // Assign the focus node
      keyboardType: TextInputType.emailAddress, // Ensures correct keyboard type for email
      decoration: InputDecoration(
        labelText: label,
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: Colors.black12,
            width: 1.0,
          ),
          borderRadius: BorderRadius.circular(10.0),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: Colors.black12,
            width: 1.0,
          ),
          borderRadius: BorderRadius.circular(10.0),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your email';
        } else if (!RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+")
            .hasMatch(value)) {
          return 'Please enter a valid email';
        }
        return null;
      },
    );
  }
}
