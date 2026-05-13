import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'auth_provider.dart' as paylio_auth;

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _countryController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final user = Provider.of<paylio_auth.PaylioAuthProvider>(context, listen: false).user;
    if (user != null) {
      _nameController.text = user.name;
      _emailController.text = user.email;
      _usernameController.text = user.username ?? '';
      _phoneController.text = user.phoneNumber ?? '';
      _countryController.text = user.country ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<paylio_auth.PaylioAuthProvider>(context);
    final user = auth.user;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: const Color(0xFF0F766E).withAlpha(25),
                      child: const Icon(Icons.person, size: 50, color: Color(0xFF0F766E)),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Color(0xFF0F766E),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: Column(
                  children: [
                    Text('Paylio ID: ${user?.paylioId}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                    const SizedBox(height: 4),
                    Text(user?.email ?? '', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Please enter your name';
                  return null;
                },
              ),
              const SizedBox(height: 20),
              
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Username (Optional)',
                  prefixIcon: Icon(Icons.alternate_email),
                  hintText: 'e.g. johndoe',
                ),
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number (Optional)',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _countryController,
                decoration: const InputDecoration(
                  labelText: 'Country / Region (Optional)',
                  prefixIcon: Icon(Icons.public_outlined),
                ),
              ),
              const SizedBox(height: 40),
              
              ElevatedButton(
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    final updatedUser = auth.user!.copyWith(
                      name: _nameController.text.trim(),
                      username: _usernameController.text.isEmpty ? null : _usernameController.text.trim(),
                      phoneNumber: _phoneController.text.isEmpty ? null : _phoneController.text.trim(),
                      country: _countryController.text.isEmpty ? null : _countryController.text.trim(),
                    );
                    await auth.updateProfile(updatedUser);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Profile updated successfully!')),
                      );
                      Navigator.pop(context);
                    }
                  }
                },
                child: const Text('Save Changes'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
