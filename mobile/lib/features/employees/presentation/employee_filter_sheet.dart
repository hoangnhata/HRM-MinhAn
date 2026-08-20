import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../shared/models/department.dart';
import '../application/employee_list_controller.dart';
import '../data/department_repository.dart';
import 'org_unit_picker.dart';

Future<void> showEmployeeFilterSheet(
  BuildContext context,
  WidgetRef ref,
) async {
  final state = ref.read(employeeListControllerProvider);
  await showAppBottomSheet<void>(
    context,
    title: 'Bộ lọc nâng cao',
    child: _EmployeeFilterSheet(
      initialDepartmentId: state.departmentId,
      initialDepartmentName: state.departmentName,
      initialWorkUnit: state.workUnit,
      initialOfficialWorkFilter: state.officialWorkFilter,
      showOfficialWorkFilter: state.status == 'OFFICIAL',
    ),
  );
}

class _EmployeeFilterSheet extends ConsumerStatefulWidget {
  const _EmployeeFilterSheet({
    required this.initialDepartmentId,
    required this.initialDepartmentName,
    required this.initialWorkUnit,
    required this.initialOfficialWorkFilter,
    required this.showOfficialWorkFilter,
  });

  final int? initialDepartmentId;
  final String? initialDepartmentName;
  final String? initialWorkUnit;
  final String? initialOfficialWorkFilter;
  final bool showOfficialWorkFilter;

  @override
  ConsumerState<_EmployeeFilterSheet> createState() =>
      _EmployeeFilterSheetState();
}

class _EmployeeFilterSheetState extends ConsumerState<_EmployeeFilterSheet> {
  static const _workFilters = [
    (null, 'Tất cả tình trạng'),
    ('WORKING', 'Đang làm việc'),
    ('MATERNITY_LEAVE', 'Nghỉ thai sản'),
    ('FULL_TIME', 'Toàn thời gian (TTG)'),
    ('PART_TIME', 'Bán thời gian (BTG)'),
  ];

  int? _departmentId;
  String? _departmentName;
  String? _workUnit;
  String? _officialWorkFilter;

  @override
  void initState() {
    super.initState();
    _departmentId = widget.initialDepartmentId;
    _departmentName = widget.initialDepartmentName;
    _workUnit = widget.initialWorkUnit;
    _officialWorkFilter = widget.initialOfficialWorkFilter;
  }

  Future<void> _pickDepartmentSafe(List<Department> departments) async {
    final result = await showDepartmentPicker(
      context,
      departments: departments,
      selectedId: _departmentId,
      allowClear: true,
    );
    if (!mounted || result == null) return;
    setState(() {
      if (result.cleared) {
        _departmentId = null;
        _departmentName = null;
        _workUnit = null;
      } else {
        _departmentId = result.department?.id;
        _departmentName = result.department?.name;
        _workUnit = null;
      }
    });
  }

  Future<void> _pickWorkUnit(List<WorkUnit> units) async {
    final result = await showWorkUnitPicker(
      context,
      units: units,
      selectedName: _workUnit,
      allowClear: true,
      departmentName: _departmentName,
    );
    if (!mounted || result == null) return;
    setState(() => _workUnit = result.cleared ? null : result.name);
  }

  Future<void> _pickWorkFilter() async {
    final result = await showModalBottomSheet<(bool, String?)>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderSoft,
                  borderRadius: AppRadius.brPill,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Tình trạng làm việc',
                    style: AppTypography.style(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              for (final opt in _workFilters)
                ListTile(
                  title: Text(opt.$2),
                  trailing: opt.$1 == _officialWorkFilter
                      ? const Icon(Icons.check_rounded, color: AppColors.primary)
                      : null,
                  onTap: () => Navigator.pop(ctx, (true, opt.$1)),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (!mounted || result == null || result.$1 != true) return;
    setState(() => _officialWorkFilter = result.$2);
  }

  @override
  Widget build(BuildContext context) {
    final departmentsAsync = ref.watch(departmentListProvider);
    final workUnitsAsync = _departmentId == null
        ? null
        : ref.watch(departmentWorkUnitsProvider(_departmentId!));

    final workFilterLabel = _workFilters
        .firstWhere(
          (e) => e.$1 == _officialWorkFilter,
          orElse: () => (null, 'Tất cả tình trạng'),
        )
        .$2;

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.page,
        right: AppSpacing.page,
        bottom: MediaQuery.paddingOf(context).bottom + 12,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          departmentsAsync.when(
            loading: () => const LinearProgressIndicator(minHeight: 2),
            error: (_, _) => Text(
              'Không tải được danh sách phòng ban',
              style: AppTypography.caption(color: AppColors.error),
            ),
            data: (departments) => _FilterPickerTile(
              label: 'Phòng ban',
              value: _departmentName ?? 'Tất cả',
              icon: Icons.apartment_rounded,
              onTap: () => _pickDepartmentSafe(departments),
            ),
          ),
          const SizedBox(height: 8),
          _FilterPickerTile(
            label: 'Bộ phận',
            value: _workUnit ?? 'Tất cả',
            icon: Icons.meeting_room_outlined,
            enabled: _departmentId != null,
            subtitle: _departmentId == null
                ? 'Chọn phòng ban trước'
                : workUnitsAsync?.isLoading == true
                    ? 'Đang tải…'
                    : null,
            onTap: () {
              final units = workUnitsAsync?.valueOrNull ?? const <WorkUnit>[];
              if (_departmentId == null) return;
              _pickWorkUnit(units);
            },
          ),
          if (widget.showOfficialWorkFilter) ...[
            const SizedBox(height: 8),
            _FilterPickerTile(
              label: 'Tình trạng làm việc',
              value: workFilterLabel,
              icon: Icons.work_outline_rounded,
              onTap: _pickWorkFilter,
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    ref
                        .read(employeeListControllerProvider.notifier)
                        .clearFilters();
                    Navigator.pop(context);
                  },
                  child: const Text('Xóa bộ lọc'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    ref.read(employeeListControllerProvider.notifier).applyFilters(
                          departmentId: _departmentId,
                          departmentName: _departmentName,
                          workUnit: _workUnit,
                          officialWorkFilter: widget.showOfficialWorkFilter
                              ? _officialWorkFilter
                              : null,
                        );
                    Navigator.pop(context);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                  ),
                  child: const Text('Áp dụng'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterPickerTile extends StatelessWidget {
  const _FilterPickerTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
    this.enabled = true,
    this.subtitle,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: enabled
          ? AppColors.surfaceMuted
          : AppColors.surfaceMuted.withValues(alpha: 0.5),
      borderRadius: AppRadius.brMd,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: AppRadius.brMd,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: AppRadius.brSm,
                ),
                child: Icon(icon, size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppTypography.style(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.style(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: AppTypography.caption(
                          color: AppColors.textTertiary,
                        ),
                      ),
                  ],
                ),
              ),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: enabled
                    ? AppColors.textSecondary
                    : AppColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
