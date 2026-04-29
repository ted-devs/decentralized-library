import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:decentralized_library/src/features/communities/data/community_repository.dart';
import 'package:decentralized_library/src/features/communities/domain/community.dart';
import 'package:decentralized_library/src/features/auth/application/auth_service.dart';
import 'package:decentralized_library/src/shared/constants/countries.dart';
import 'package:decentralized_library/src/shared/utils/snackbar_utils.dart';
import 'package:decentralized_library/src/shared/widgets/country_picker_field.dart';

class CreateCommunityScreen extends ConsumerStatefulWidget {
  const CreateCommunityScreen({super.key});

  @override
  ConsumerState<CreateCommunityScreen> createState() => _CreateCommunityScreenState();
}

class _CreateCommunityScreenState extends ConsumerState<CreateCommunityScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _cityController = TextEditingController();
  final _orgController = TextEditingController();
  String? _selectedCountry;
  bool _isPublic = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _cityController.dispose();
    _orgController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCountry == null) {
      AppSnackBar.show(context, 'Please select a country');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = ref.read(authStateProvider).value;
      if (user == null) return;

      final community = Community(
        id: '', 
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        adminId: user.uid,
        isPublic: _isPublic,
        country: _selectedCountry!,
        city: _cityController.text.trim(),
        organization: _orgController.text.trim().isEmpty ? null : _orgController.text.trim(),
      );

      await ref.read(communityRepositoryProvider).createCommunity(community);
      
      if (mounted) {
        Navigator.pop(context);
        AppSnackBar.show(context, 'Community "${community.name}" created!');
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(context, 'Error: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Community')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name *', border: OutlineInputBorder()),
                validator: (v) => v == null || v.isEmpty ? 'Please enter name' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description *', border: OutlineInputBorder()),
                maxLines: 3,
                validator: (v) => v == null || v.isEmpty ? 'Please enter description' : null,
              ),
              const SizedBox(height: 16),
              CountryPickerField(
                initialValue: _selectedCountry,
                onChanged: (value) {
                  setState(() {
                    _selectedCountry = value;
                  });
                },
                validator: (value) => value == null || value.isEmpty ? 'Please select a country' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _cityController,
                decoration: const InputDecoration(labelText: 'City *', border: OutlineInputBorder()),
                validator: (v) => v == null || v.isEmpty ? 'Please enter city' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _orgController,
                decoration: const InputDecoration(labelText: 'Organization, Institution or Group (Optional)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 24),
              const Text('Privacy Settings', style: TextStyle(fontWeight: FontWeight.bold)),
              SwitchListTile(
                title: const Text('Public Community'),
                subtitle: const Text('Anyone can join and see the shared library instantly.'),
                value: _isPublic,
                onChanged: (v) => setState(() => _isPublic = v),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  child: _isLoading ? const CircularProgressIndicator() : const Text('Create Community'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

