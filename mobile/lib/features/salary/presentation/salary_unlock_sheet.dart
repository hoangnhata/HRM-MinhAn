import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/salary/salary_access_store.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../data/salary_repository.dart';

/// Mở khóa quản lý lương ADMIN/HCNS 1 — cùng API web `/v1/salary-profiles/unlock`.
Future<bool> ensureSalaryUnlocked(BuildContext context, WidgetRef ref) async {
  if (ref.read(salaryAccessStoreProvider).isUnlocked) return true;
  return await showSalaryUnlockSheet(context, ref) ?? false;
}

Future<bool?> showSalaryUnlockSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _SalaryUnlockSheet(ref: ref),
  );
}

class _SalaryUnlockSheet extends StatefulWidget {
  const _SalaryUnlockSheet({required this.ref});

  final WidgetRef ref;

  @override
  State<_SalaryUnlockSheet> createState() => _SalaryUnlockSheetState();
}

class _SalaryUnlockSheetState extends State<_SalaryUnlockSheet> {
  final _password = TextEditingController();
  final _focus = FocusNode();
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _password.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _unlock() async {
    final value = _password.text;
    if (value.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.ref.read(salaryRepositoryProvider).unlock(value);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      widget.ref.read(salaryAccessStoreProvider).clear();
      _password.clear();
      setState(() {
        _busy = false;
        _error = e.message;
      });
      _focus.requestFocus();
    } catch (_) {
      if (!mounted) return;
      widget.ref.read(salaryAccessStoreProvider).clear();
      _password.clear();
      setState(() {
        _busy = false;
        _error = 'Sai mật khẩu, vui lòng nhập lại.';
      });
      _focus.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: AppRadius.brPill,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: AppRadius.brMd,
                    ),
                    child: const Icon(
                      Icons.lock_outline_rounded,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mở khóa phần lương',
                          style: AppTypography.style(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'ADMIN / HCNS 1',
                          style: AppTypography.style(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Vì lý do bảo mật, cần mật khẩu riêng để xem và chỉnh sửa lương toàn bệnh viện.',
                style: AppTypography.style(
                  fontSize: 13,
                  height: 1.4,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _password,
                focusNode: _focus,
                obscureText: _obscure,
                enabled: !_busy,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _unlock(),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Mật khẩu phần lương',
                  errorText: _error,
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _busy || _password.text.isEmpty ? null : _unlock,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  backgroundColor: AppColors.primary,
                ),
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Mở khóa'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _busy ? null : () => Navigator.pop(context, false),
                child: const Text('Hủy'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
