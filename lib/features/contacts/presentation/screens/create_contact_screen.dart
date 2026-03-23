import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:messenger/shared/theme/app_colors.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

class CreateContactScreen extends StatefulWidget {
  const CreateContactScreen({super.key});

  @override
  State<CreateContactScreen> createState() => _CreateContactScreenState();
}

class _CreateContactScreenState extends State<CreateContactScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _companyController = TextEditingController();

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _companyController.dispose();
    super.dispose();
  }

  bool _isSaving = false;

  Future<void> _saveContact() async {
    if (_firstNameController.text.isEmpty && _phoneController.text.isEmpty) {
      context.pop();
      return;
    }

    setState(() => _isSaving = true);

    try {
      final contact = Contact(
        name: Name(first: _firstNameController.text, last: _lastNameController.text),
        phones: [if (_phoneController.text.isNotEmpty) Phone(number: _phoneController.text)],
        emails: [if (_emailController.text.isNotEmpty) Email(address: _emailController.text)],
        organizations: [if (_companyController.text.isNotEmpty) Organization(name: _companyController.text)],
      );

      await FlutterContacts.create(contact);
      
      if (mounted) {
        context.pop(true);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.bgPrimary,
        elevation: 0,
        titleSpacing: 0,
        leadingWidth: 48,
        leading: IconButton(
          padding: EdgeInsets.zero,
          icon: const Icon(Icons.arrow_back, color: AppColors.accentBlue),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Новый контакт',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w600,
            fontFamily: 'Inter',
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveContact,
            child: const Text(
              'Готово',
              style: TextStyle(
                color: AppColors.accentBlue,
                fontFamily: 'Inter',
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          const Divider(height: 1, color: AppColors.borderDefault),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Avatar section
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            color: AppColors.bgInput,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.camera_alt_outlined,
                            color: AppColors.textTertiary,
                            size: 32,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Добавить фото',
                          style: TextStyle(
                            color: AppColors.accentBlue,
                            fontFamily: 'Inter',
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: AppColors.borderDefault),
                  // Form
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                    child: Column(
                      children: [
                        _buildFormField('Имя', 'Введите имя...', _firstNameController),
                        const SizedBox(height: 20),
                        _buildFormField('Фамилия', 'Введите фамилию...', _lastNameController),
                        const SizedBox(height: 20),
                        _buildFormField('Телефон', '+7 (___) ___-__-__', _phoneController, keyboardType: TextInputType.phone),
                        const SizedBox(height: 20),
                        _buildFormField('Email', 'Введите email...', _emailController, keyboardType: TextInputType.emailAddress),
                        const SizedBox(height: 20),
                        _buildFormField('Компания', 'Введите компанию...', _companyController),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Bottom button
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: GestureDetector(
              onTap: _isSaving ? null : _saveContact,
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.accentBlue,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isSaving)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: AppColors.textOnAccent, strokeWidth: 2),
                      )
                    else ...[
                      const Icon(Icons.person_add_alt, color: AppColors.textOnAccent, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Сохранить контакт',
                        style: TextStyle(
                          color: AppColors.textOnAccent,
                          fontFamily: 'Inter',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormField(String label, String hint, TextEditingController controller, {TextInputType? keyboardType}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textTertiary,
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.bgInput,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.centerLeft,
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 15,
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(
                color: AppColors.textMuted,
                fontFamily: 'Inter',
                fontSize: 15,
              ),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
      ],
    );
  }
}
