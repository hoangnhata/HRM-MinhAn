import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/auth_network_image.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../auth/application/auth_controller.dart';
import '../data/profile_repository.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _fullNameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  bool _saving = false;
  bool _uploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    final me = ref.read(authControllerProvider).currentUser;
    _fullNameController = TextEditingController(text: me?.fullName ?? '');
    _emailController = TextEditingController(text: me?.email ?? '');
    _phoneController = TextEditingController(text: me?.phone ?? '');
    _addressController = TextEditingController(text: me?.address ?? '');
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar(ImageSource source) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 800,
    );
    if (file == null) return;

    setState(() => _uploadingAvatar = true);
    try {
      final bytes = await File(file.path).readAsBytes();
      await ref.read(profileRepositoryProvider).uploadAvatar(bytes);
      await ref.read(authControllerProvider.notifier).refreshCurrentUser();
      if (mounted) {
        showAppSnackBar(context, 'Đã cập nhật ảnh đại diện', isSuccess: true);
      }
    } catch (_) {
      if (mounted) showAppSnackBar(context, 'Tải ảnh thất bại', isError: true);
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _chooseAvatarSource() async {
    final source = await showAppBottomSheet<ImageSource>(
      context,
      title: 'Ảnh đại diện',
      subtitle: 'Chọn nguồn ảnh bạn muốn dùng',
      child: Column(
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const AppIconBadge(icon: Icons.photo_library_outlined),
            title: const Text('Chọn từ thư viện ảnh'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.of(context).pop(ImageSource.gallery),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const AppIconBadge(
              icon: Icons.photo_camera_outlined,
              color: AppColors.secondaryDark,
            ),
            title: const Text('Chụp ảnh mới'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.of(context).pop(ImageSource.camera),
          ),
        ],
      ),
    );
    if (source != null) await _pickAvatar(source);
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      await ref
          .read(profileRepositoryProvider)
          .updateProfile(
            fullName: _fullNameController.text.trim(),
            email: _emailController.text.trim(),
            phone: _phoneController.text.trim(),
            address: _addressController.text.trim(),
          );
      await ref.read(authControllerProvider.notifier).refreshCurrentUser();
      if (mounted) {
        showAppSnackBar(context, 'Đã lưu thay đổi', isSuccess: true);
        Navigator.of(context).maybePop();
      }
    } catch (_) {
      if (mounted) {
        showAppSnackBar(
          context,
          'Lưu thất bại. Vui lòng thử lại.',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(authControllerProvider).currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const GradientAppBar(title: 'Chỉnh sửa hồ sơ'),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.lg,
            AppSpacing.page,
            AppSpacing.xxl,
          ),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Column(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 104,
                          height: 104,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primary.withValues(alpha: 0.10),
                            border: Border.all(
                              color: AppColors.surface,
                              width: 3,
                            ),
                            boxShadow: AppShadows.card,
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: me?.hasAvatar == true
                              ? AuthNetworkImage(
                                  url: ProfileRepository.myAvatarUrl,
                                  fit: BoxFit.cover,
                                )
                              : const Icon(
                                  Icons.person_rounded,
                                  size: 46,
                                  color: AppColors.primary,
                                ),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Semantics(
                            button: true,
                            label: _uploadingAvatar
                                ? 'Đang tải ảnh đại diện'
                                : 'Thay đổi ảnh đại diện',
                            child: SizedBox(
                              width: 48,
                              height: 48,
                              child: Material(
                                color: Colors.transparent,
                                shape: const CircleBorder(),
                                child: InkWell(
                                  customBorder: const CircleBorder(),
                                  onTap: _uploadingAvatar
                                      ? null
                                      : _chooseAvatarSource,
                                  child: Center(
                                    child: Container(
                                      width: 38,
                                      height: 38,
                                      decoration: const BoxDecoration(
                                        color: AppColors.primary,
                                        shape: BoxShape.circle,
                                      ),
                                      child: _uploadingAvatar
                                          ? Padding(
                                              padding: const EdgeInsets.all(10),
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.onPrimary,
                                                strokeCap: StrokeCap.round,
                                              ),
                                            )
                                          : Icon(
                                              Icons.photo_camera_rounded,
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onPrimary,
                                              size: 18,
                                            ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Nhấn vào biểu tượng để đổi ảnh',
                      textAlign: TextAlign.center,
                      style: AppTypography.caption(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: AppCard(
                  child: Column(
                    children: [
                      const AppSectionTitle(
                        title: 'Thông tin liên hệ',
                        icon: Icons.contact_mail_outlined,
                        padding: EdgeInsets.only(bottom: AppSpacing.md),
                      ),
                      TextFormField(
                        controller: _fullNameController,
                        enabled: !_saving,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.name],
                        decoration: const InputDecoration(
                          labelText: 'Họ và tên',
                          prefixIcon: Icon(Icons.person_outline_rounded),
                        ),
                        validator: (v) =>
                            Validators.required(v, label: 'Họ và tên'),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextFormField(
                        controller: _emailController,
                        enabled: !_saving,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.mail_outline_rounded),
                        ),
                        validator: Validators.email,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextFormField(
                        controller: _phoneController,
                        enabled: !_saving,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.telephoneNumber],
                        decoration: const InputDecoration(
                          labelText: 'Số điện thoại',
                          prefixIcon: Icon(Icons.phone_outlined),
                        ),
                        validator: Validators.phone,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextFormField(
                        controller: _addressController,
                        enabled: !_saving,
                        minLines: 1,
                        maxLines: 3,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.streetAddressLine1],
                        onFieldSubmitted: (_) => _save(),
                        decoration: const InputDecoration(
                          labelText: 'Địa chỉ',
                          prefixIcon: Icon(Icons.home_outlined),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Semantics(
                  liveRegion: _saving,
                  label: _saving ? 'Đang lưu hồ sơ' : null,
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Theme.of(context).colorScheme.onPrimary,
                                strokeCap: StrokeCap.round,
                              ),
                            )
                          : const Icon(Icons.check_rounded, size: 19),
                      label: Text(_saving ? 'Đang lưu...' : 'Lưu thay đổi'),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
