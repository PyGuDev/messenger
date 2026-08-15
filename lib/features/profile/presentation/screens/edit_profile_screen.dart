import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:messenger/shared/theme/app_colors.dart';
import 'package:messenger/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:messenger/features/profile/presentation/bloc/profile_event.dart';
import 'package:messenger/features/profile/presentation/bloc/profile_state.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;

  @override
  void initState() {
    super.initState();
    final state = context.read<ProfileBloc>().state;
    if (state is ProfileLoaded) {
      _firstNameController = TextEditingController(text: state.firstName);
      _lastNameController = TextEditingController(text: state.lastName);
      _phoneController = TextEditingController(text: state.phone ?? '');
      _emailController = TextEditingController(text: state.email);
    } else {
      _firstNameController = TextEditingController();
      _lastNameController = TextEditingController();
      _phoneController = TextEditingController();
      _emailController = TextEditingController();
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _onSave() {
    context.read<ProfileBloc>().add(
      UpdateProfile(
        firstName: _firstNameController.text,
        lastName: _lastNameController.text,
        phone: _phoneController.text,
        email: _emailController.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ProfileBloc, ProfileState>(
      listener: (context, state) {
        if (state is ProfileUpdateSuccess) {
          context.pop();
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Профиль обновлен')));
        } else if (state is ProfileUpdateFailure || state is ProfileError) {
          final message = state is ProfileUpdateFailure
              ? state.message
              : (state as ProfileError).message;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message), backgroundColor: AppColors.error),
          );
        }
      },
      child: Scaffold(
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
            'Редактирование',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w600,
              fontFamily: 'Inter',
            ),
          ),
        ),
        body: BlocBuilder<ProfileBloc, ProfileState>(
          builder: (context, state) {
            final isLoading = state is ProfileUpdateInProgress;

            return Column(
              children: [
                const Divider(height: 1, color: AppColors.borderDefault),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        // Avatar section (simplified for now as in design)
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
                        const Divider(
                          height: 1,
                          color: AppColors.borderDefault,
                        ),
                        // Form
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                          child: Column(
                            children: [
                              _buildFormField(
                                'Имя',
                                'Введите имя...',
                                _firstNameController,
                              ),
                              const SizedBox(height: 20),
                              _buildFormField(
                                'Фамилия',
                                'Введите фамилию...',
                                _lastNameController,
                              ),
                              const SizedBox(height: 20),
                              _buildFormField(
                                'Телефон',
                                '+7 (___) ___-__-__',
                                _phoneController,
                                keyboardType: TextInputType.phone,
                              ),
                              const SizedBox(height: 20),
                              _buildFormField(
                                'Email',
                                'Введите email...',
                                _emailController,
                                keyboardType: TextInputType.emailAddress,
                              ),
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
                    onTap: isLoading ? null : _onSave,
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: AppColors.accentBlue,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (isLoading)
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: AppColors.textOnAccent,
                                strokeWidth: 2,
                              ),
                            )
                          else ...[
                            const Icon(
                              Icons.save,
                              color: AppColors.textOnAccent,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Сохранить',
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
            );
          },
        ),
      ),
    );
  }

  Widget _buildFormField(
    String label,
    String hint,
    TextEditingController controller, {
    TextInputType? keyboardType,
  }) {
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
