import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/app_user.dart';
import '../../../shared/constants/countries.dart';
import '../../../shared/utils/snackbar_utils.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  final User firebaseUser;
  const OnboardingScreen({super.key, required this.firebaseUser});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _displayNameController;
  final _cityController = TextEditingController();
  String? _selectedCountry;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _displayNameController = TextEditingController(text: widget.firebaseUser.displayName);
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCountry == null) {
      AppSnackBar.show(context, 'Please select your country');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = widget.firebaseUser;
      final appUser = AppUser(
        uid: user.uid,
        email: user.email ?? '',
        displayName: _displayNameController.text.trim(),
        photoUrl: user.photoURL ?? '',
        city: _cityController.text.trim(),
        country: _selectedCountry!,
        createdAt: DateTime.now(),
      );

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(appUser.toMap());
      // Upon creating the document, AuthWrapper stream will automatically route to Home.
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(context, 'Error saving profile: $e');
      }
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Your Profile'),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundImage: widget.firebaseUser.photoURL != null
                        ? NetworkImage(widget.firebaseUser.photoURL!)
                        : null,
                    child: widget.firebaseUser.photoURL == null
                        ? const Icon(Icons.person, size: 40)
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Welcome!',
                    style: theme.textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'We need just a little more info to help you connect with your local communities.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  
                  // Display Name Field
                  TextFormField(
                    controller: _displayNameController,
                    decoration: const InputDecoration(
                      labelText: 'Display Name',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        value == null || value.isEmpty ? 'Please enter your name' : null,
                  ),
                  const SizedBox(height: 16),
                  
                  // Country Dropdown
                  DropdownButtonFormField<String>(
                    value: _selectedCountry,
                    decoration: const InputDecoration(
                      labelText: 'Country',
                      prefixIcon: Icon(Icons.public),
                      border: OutlineInputBorder(),
                    ),
                    items: countries.map((country) {
                      return DropdownMenuItem(
                        value: country,
                        child: Text(country),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedCountry = value;
                      });
                    },
                    validator: (value) =>
                        value == null || value.isEmpty ? 'Please select your country' : null,
                    isExpanded: true, // Prevents overflow for long country names
                  ),
                  const SizedBox(height: 16),

                  // City Field
                  TextFormField(
                    controller: _cityController,
                    decoration: const InputDecoration(
                      labelText: 'City',
                      prefixIcon: Icon(Icons.location_city),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        value == null || value.isEmpty ? 'Please enter your city' : null,
                  ),
                  const SizedBox(height: 32),
                  
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _completeOnboarding,
                      child: _isLoading
                          ? const CircularProgressIndicator()
                          : const Text('Save Profile & Continue', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
