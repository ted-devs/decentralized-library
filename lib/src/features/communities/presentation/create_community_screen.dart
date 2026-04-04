import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:decentralized_library/src/features/communities/data/community_repository.dart';
import 'package:decentralized_library/src/features/communities/domain/community.dart';
import 'package:decentralized_library/src/features/auth/application/auth_service.dart';

class CreateCommunityScreen extends ConsumerStatefulWidget {
  const CreateCommunityScreen({super.key});

  @override
  ConsumerState<CreateCommunityScreen> createState() => _CreateCommunityScreenState();
}

class _CreateCommunityScreenState extends ConsumerState<CreateCommunityScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isPublic = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

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
      );

      await ref.read(communityRepositoryProvider).createCommunity(community);
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Community "${community.name}" created!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
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
