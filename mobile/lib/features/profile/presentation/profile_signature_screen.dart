import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:signature/signature.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/auth_network_image.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/notice_banner.dart';
import '../../auth/application/auth_controller.dart';
import '../data/profile_repository.dart';

enum _SignatureMode { overview, draw }

class ProfileSignatureScreen extends ConsumerStatefulWidget {
  const ProfileSignatureScreen({super.key});

  @override
  ConsumerState<ProfileSignatureScreen> createState() =>
      _ProfileSignatureScreenState();
}

class _ProfileSignatureScreenState
    extends ConsumerState<ProfileSignatureScreen> {
  late final SignatureController _controller;
  _SignatureMode _mode = _SignatureMode.overview;
  bool _submitting = false;
  bool _hasStrokes = false;
  Uint8List? _previewUpload;
  String? _uploadMime;

  static const _maxUploadBytes = 2 * 1024 * 1024;

  @override
  void initState() {
    super.initState();
    _controller = SignatureController(
      penStrokeWidth: 3,
      penColor: AppColors.textPrimary,
      exportBackgroundColor: AppColors.surface,
      onDrawEnd: () {
        if (!_hasStrokes) setState(() => _hasStrokes = true);
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _clearDraw() {
    _controller.clear();
    setState(() => _hasStrokes = false);
  }

  void _backToOverview() {
    _controller.clear();
    setState(() {
      _mode = _SignatureMode.overview;
      _hasStrokes = false;
      _previewUpload = null;
      _uploadMime = null;
    });
  }

  Future<void> _persist(
    List<int> bytes, {
    String mimeType = 'image/png',
    String successMessage = 'Đã lưu chữ ký',
  }) async {
    setState(() => _submitting = true);
    final ok = await ref
        .read(authControllerProvider.notifier)
        .submitSignature(bytes, mimeType: mimeType);
    if (!mounted) return;
    setState(() => _submitting = false);

    if (ok) {
      showAppSnackBar(context, successMessage, isSuccess: true);
      _backToOverview();
    } else {
      showAppSnackBar(
        context,
        ref.read(authControllerProvider).errorMessage ??
            'Lưu chữ ký thất bại. Vui lòng thử lại.',
        isError: true,
      );
    }
  }

  Future<void> _saveDraw() async {
    if (_controller.isEmpty) {
      showAppSnackBar(context, 'Vui lòng ký trước khi lưu', isError: true);
      return;
    }
    final bytes = await _controller.toPngBytes();
    if (!mounted) return;
    if (bytes == null) {
      showAppSnackBar(
        context,
        'Không đọc được chữ ký. Vui lòng ký lại.',
        isError: true,
      );
      return;
    }
    await _persist(bytes, successMessage: 'Đã lưu chữ ký từ khung vẽ');
  }

  Future<void> _pickUpload() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 92,
      maxWidth: 1600,
    );
    if (file == null) return;

    final bytes = await file.readAsBytes();
    if (!mounted) return;
    if (bytes.length > _maxUploadBytes) {
      showAppSnackBar(
        context,
        'Ảnh vượt quá 2MB. Vui lòng chọn ảnh nhỏ hơn.',
        isError: true,
      );
      return;
    }

    final path = file.path.toLowerCase();
    final mime = path.endsWith('.jpg') || path.endsWith('.jpeg')
        ? 'image/jpeg'
        : 'image/png';

    setState(() {
      _previewUpload = bytes;
      _uploadMime = mime;
    });
  }

  Future<void> _saveUpload() async {
    final bytes = _previewUpload;
    if (bytes == null) {
      showAppSnackBar(context, 'Chưa chọn ảnh chữ ký', isError: true);
      return;
    }
    await _persist(
      bytes,
      mimeType: _uploadMime ?? 'image/png',
      successMessage: 'Đã lưu chữ ký từ ảnh',
    );
  }

  Future<void> _deleteSignature() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Xóa chữ ký?',
      message: 'Chữ ký hiện tại sẽ bị gỡ. Bạn có thể tạo lại bất cứ lúc nào.',
      confirmLabel: 'Xóa',
      danger: true,
    );
    if (confirmed != true || !mounted) return;

    setState(() => _submitting = true);
    try {
      await ref.read(profileRepositoryProvider).deleteSignature();
      await ref.read(authControllerProvider.notifier).refreshCurrentUser();
      if (!mounted) return;
      showAppSnackBar(context, 'Đã xóa chữ ký', isSuccess: true);
      setState(() => _submitting = false);
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      showAppSnackBar(context, 'Xóa chữ ký thất bại', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(authControllerProvider).currentUser;
    final hasSignature = me?.hasSignature == true;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: GradientAppBar(
        title: 'Chữ ký số',
        subtitle: hasSignature ? 'Đã thiết lập' : 'Chưa thiết lập',
      ),
      body: _mode == _SignatureMode.draw
          ? _DrawMode(
              controller: _controller,
              hasStrokes: _hasStrokes,
              submitting: _submitting,
              onClear: _clearDraw,
              onCancel: _backToOverview,
              onSave: _saveDraw,
            )
          : _OverviewMode(
              hasSignature: hasSignature,
              submitting: _submitting,
              previewUpload: _previewUpload,
              onStartDraw: () => setState(() {
                _previewUpload = null;
                _mode = _SignatureMode.draw;
              }),
              onPickUpload: _pickUpload,
              onClearUploadPreview: () => setState(() {
                _previewUpload = null;
                _uploadMime = null;
              }),
              onSaveUpload: _saveUpload,
              onDelete: hasSignature ? _deleteSignature : null,
            ),
    );
  }
}

class _OverviewMode extends StatelessWidget {
  const _OverviewMode({
    required this.hasSignature,
    required this.submitting,
    required this.previewUpload,
    required this.onStartDraw,
    required this.onPickUpload,
    required this.onClearUploadPreview,
    required this.onSaveUpload,
    this.onDelete,
  });

  final bool hasSignature;
  final bool submitting;
  final Uint8List? previewUpload;
  final VoidCallback onStartDraw;
  final VoidCallback onPickUpload;
  final VoidCallback onClearUploadPreview;
  final VoidCallback onSaveUpload;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.md,
        AppSpacing.page,
        AppSpacing.xl,
      ),
      children: [
        NoticeBanner(
          icon: hasSignature
              ? Icons.verified_outlined
              : Icons.info_outline_rounded,
          color: hasSignature ? AppColors.success : AppColors.info,
          message: hasSignature
              ? 'Chữ ký được đính kèm tự động khi gửi / duyệt đơn (đồng bộ web).'
              : 'Thiết lập chữ ký bằng cách vẽ hoặc tải ảnh PNG/JPG.',
        ),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Chữ ký hiện tại',
                style: AppTypography.style(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                height: 148,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: AppRadius.brMd,
                  border: Border.all(
                    color: AppColors.borderSoft,
                    style: BorderStyle.solid,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: hasSignature
                    ? Padding(
                        padding: const EdgeInsets.all(12),
                        child: AuthNetworkImage(
                          url: ProfileRepository.mySignatureUrl,
                          fit: BoxFit.contain,
                        ),
                      )
                    : Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.gesture_rounded,
                              size: 32,
                              color: AppColors.textTertiary,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Chưa có chữ ký',
                              style: AppTypography.caption(
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
              if (onDelete != null) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: submitting ? null : onDelete,
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: const Text('Xóa chữ ký'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.error,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        _ActionChoiceCard(
          icon: Icons.draw_rounded,
          color: AppColors.primary,
          title: 'Vẽ chữ ký',
          subtitle: 'Ký bằng ngón tay hoặc bút cảm ứng',
          onTap: submitting ? null : onStartDraw,
        ),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          accentColor: AppColors.info,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.info.withValues(alpha: 0.12),
                      borderRadius: AppRadius.brSm,
                    ),
                    child: const Icon(
                      Icons.upload_file_rounded,
                      color: AppColors.info,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tải ảnh chữ ký',
                          style: AppTypography.style(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'PNG hoặc JPG, tối đa 2MB · nền trắng, chữ rõ',
                          style: AppTypography.style(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (previewUpload != null) ...[
                const SizedBox(height: 12),
                Container(
                  height: 120,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: AppRadius.brMd,
                    border: Border.all(color: AppColors.info.withValues(alpha: 0.35)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.memory(previewUpload!, fit: BoxFit.contain),
                ),
              ],
              const SizedBox(height: 12),
              if (previewUpload == null)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: submitting ? null : onPickUpload,
                    icon: const Icon(Icons.image_outlined, size: 18),
                    label: const Text('Chọn ảnh từ thư viện'),
                  ),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: submitting ? null : onClearUploadPreview,
                        child: const Text('Huỷ'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: submitting ? null : onSaveUpload,
                        icon: submitting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.check_rounded, size: 18),
                        label: Text(submitting ? 'Đang lưu…' : 'Lưu ảnh chữ ký'),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionChoiceCard extends StatelessWidget {
  const _ActionChoiceCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.brCard,
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.brCard,
            border: Border.all(color: AppColors.borderSoft),
            boxShadow: AppShadows.soft,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: AppRadius.brSm,
                  ),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTypography.style(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: AppTypography.style(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: color),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DrawMode extends StatelessWidget {
  const _DrawMode({
    required this.controller,
    required this.hasStrokes,
    required this.submitting,
    required this.onClear,
    required this.onCancel,
    required this.onSave,
  });

  final SignatureController controller;
  final bool hasStrokes;
  final bool submitting;
  final VoidCallback onClear;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.md,
              AppSpacing.page,
              AppSpacing.md,
            ),
            children: [
              const NoticeBanner(
                icon: Icons.gesture_rounded,
                color: AppColors.primary,
                message:
                    'Ký bằng ngón tay hoặc bút cảm ứng. Chữ ký mới sẽ thay thế chữ ký cũ.',
              ),
              const SizedBox(height: AppSpacing.md),
              Container(
                height: 280,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppRadius.brMd,
                  border: Border.all(
                    color: hasStrokes
                        ? AppColors.primary.withValues(alpha: 0.5)
                        : AppColors.border,
                    width: hasStrokes ? 1.5 : 1,
                  ),
                  boxShadow: AppShadows.soft,
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Signature(
                      controller: controller,
                      backgroundColor: AppColors.surface,
                    ),
                    if (!hasStrokes)
                      IgnorePointer(
                        child: Center(
                          child: Text(
                            'Ký tên của bạn vào đây',
                            style: AppTypography.caption(
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              8,
              AppSpacing.page,
              AppSpacing.md,
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: submitting ? null : onCancel,
                    child: const Text('Huỷ'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: (submitting || !hasStrokes) ? null : onClear,
                    icon: const Icon(Icons.refresh_rounded, size: 17),
                    label: const Text('Ký lại'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: submitting ? null : onSave,
                    icon: submitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_rounded, size: 18),
                    label: Text(submitting ? 'Đang lưu…' : 'Lưu chữ ký'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
