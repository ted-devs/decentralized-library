import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:decentralized_library/src/features/communities/data/community_repository.dart';
import 'package:decentralized_library/src/features/communities/domain/community.dart';
import 'package:decentralized_library/src/features/auth/application/auth_service.dart';
import 'package:decentralized_library/src/shared/constants/countries.dart';
import 'package:decentralized_library/src/shared/utils/snackbar_utils.dart';

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

class CountryPickerField extends StatefulWidget {
  final String? initialValue;
  final ValueChanged<String?> onChanged;
  final String? Function(String?)? validator;

  const CountryPickerField({
    super.key,
    this.initialValue,
    required this.onChanged,
    this.validator,
  });

  @override
  State<CountryPickerField> createState() => _CountryPickerFieldState();
}

class _CountryPickerFieldState extends State<CountryPickerField> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void didUpdateWidget(CountryPickerField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != oldWidget.initialValue) {
      _controller.text = widget.initialValue ?? '';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _showPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return _CountryPickerSheet(
          onSelected: (country) {
            _controller.text = country;
            widget.onChanged(country);
            Navigator.pop(context);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _controller,
      readOnly: true,
      onTap: _showPicker,
      validator: widget.validator,
      decoration: const InputDecoration(
        labelText: 'Country *',
        border: OutlineInputBorder(),
        suffixIcon: Icon(Icons.arrow_drop_down),
      ),
    );
  }
}

class _CountryPickerSheet extends StatefulWidget {
  final ValueChanged<String> onSelected;

  const _CountryPickerSheet({required this.onSelected});

  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<_CountryPickerSheet> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final filteredCountries = countries
        .where((c) => c.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search country...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
            autofocus: true,
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: filteredCountries.length,
            itemBuilder: (context, index) {
              final country = filteredCountries[index];
              return ListTile(
                title: Text(country),
                onTap: () => widget.onSelected(country),
              );
            },
          ),
        ),
      ],
    );
  }
}
