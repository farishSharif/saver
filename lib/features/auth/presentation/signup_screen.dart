import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _inviteCodeController = TextEditingController();
  
  String _role = 'user'; // 'user' or 'saver'
  bool _isLoading = false;

  Future<void> _signup() async {
    final email = _emailController.text.trim();
    final pass = _passwordController.text.trim();
    final name = _fullNameController.text.trim();
    final code = _inviteCodeController.text.trim();

    if (email.isEmpty || pass.isEmpty || name.isEmpty) return;

    if (_role == 'user' && code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter an Admin Invite Code')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      String? adminId;
      if (_role == 'user') {
        adminId = await ref.read(authRepositoryProvider).getAdminIdFromInviteCode(code);
        if (adminId == null) {
          throw Exception('Invalid Admin Invite Code.');
        }
      }

      await ref.read(authRepositoryProvider).signUp(
        email: email,
        password: pass,
        fullName: name,
        role: _role,
        adminId: adminId,
      );
      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Registration successful! Please login.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign Up')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _fullNameController,
                decoration: const InputDecoration(labelText: 'Full Name', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _role,
                decoration: const InputDecoration(labelText: 'Role', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'user', child: Text('User (Friend)')),
                  DropdownMenuItem(value: 'saver', child: Text('Saver (Admin)')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _role = value);
                },
              ),
              if (_role == 'user') ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _inviteCodeController,
                  decoration: const InputDecoration(
                    labelText: 'Admin Invite Code', 
                    border: OutlineInputBorder(),
                    helperText: 'Your unique code given by your group Saver',
                  ),
                  maxLength: 6,
                  textCapitalization: TextCapitalization.characters,
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _signup,
                child: _isLoading ? const CircularProgressIndicator() : const Text('Sign Up'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
