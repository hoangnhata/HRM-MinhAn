import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_ambient_background.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/notice_banner.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../shared/models/attendance_models.dart';
import '../data/attendance_repository.dart';

class _DayAssignment {
  const _DayAssignment({
    required this.shiftTypeId,
    required this.shiftTypeName,
    required this.kind,
    required this.continuousStart,
    required this.continuousEnd,
  });

  final int shiftTypeId;
  final String shiftTypeName;
  final ContinuousShiftKind kind;
  final String continuousStart;
  final String continuousEnd;

  factory _DayAssignment.fromType(ContinuousShiftType type) {
    final split = type.isSplit;
    return _DayAssignment(
      shiftTypeId: type.id,
      shiftTypeName: type.name,
      kind: type.kind,
      continuousStart: split
          ? (type.morningStart ?? type.startTime)
          : type.startTime,
      continuousEnd: split
          ? (type.afternoonEnd ?? type.endTime)
          : type.endTime,
    );
  }

  factory _DayAssignment.fromDay(
    ContinuousShiftDayInfo day,
    List<ContinuousShiftType> types,
  ) {
    if (day.shiftTypeId != null) {
      for (final t in types) {
        if (t.id == day.shiftTypeId) {
          return _DayAssignment.fromType(t);
        }
      }
    }
    final kind = day.kind ?? ContinuousShiftKind.continuous;
    return _DayAssignment(
      shiftTypeId: day.shiftTypeId ?? 0,
      shiftTypeName: day.shiftTypeName ?? 'Ca tùy chỉnh',
      kind: kind,
      continuousStart: day.continuousStart ?? '',
      continuousEnd: day.continuousEnd ?? '',
    );
  }

  String get timeLabel {
    final s = DayShiftSchedule.hhmm(continuousStart) ?? continuousStart;
    final e = DayShiftSchedule.hhmm(continuousEnd) ?? continuousEnd;
    if (s.isEmpty && e.isEmpty) return '';
    if (kind == ContinuousShiftKind.split) {
      return '$s…$e · SC';
    }
    return '$s–$e · TT';
  }

  String get cellSubLabel {
    final s = DayShiftSchedule.hhmm(continuousStart);
    final e = DayShiftSchedule.hhmm(continuousEnd);
    if (s == null && e == null) return kind.shortLabel;
    if (kind == ContinuousShiftKind.split) {
      return '${s ?? '—'}…${e ?? '—'} · SC';
    }
    return '${s ?? '—'}–${e ?? '—'} · TT';
  }
}

/// Palette ổn định theo id ca — dễ phân biệt nhiều loại trên lịch.
Color _shiftColor(int shiftTypeId) {
  const palette = [
    Color(0xFF0F766E), // teal
    Color(0xFF2563EB), // blue
    Color(0xFFC2410C), // terracotta
    Color(0xFF7C3AED), // violet
    Color(0xFFB45309), // amber
    Color(0xFF047857), // emerald
    Color(0xFFBE185D), // rose
    Color(0xFF0369A1), // sky
  ];
  if (shiftTypeId <= 0) return palette.first;
  return palette[shiftTypeId.abs() % palette.length];
}

/// Gắn ca thông tầm theo ngày — API đồng bộ web, UI tối ưu mobile.
class ContinuousShiftScreen extends ConsumerStatefulWidget {
  const ContinuousShiftScreen({
    super.key,
    required this.employeeId,
    required this.year,
    required this.month,
    this.employeeName,
  });

  final int employeeId;
  final int year;
  final int month;
  final String? employeeName;

  @override
  ConsumerState<ContinuousShiftScreen> createState() =>
      _ContinuousShiftScreenState();
}

class _ContinuousShiftScreenState extends ConsumerState<ContinuousShiftScreen> {
  final Map<String, _DayAssignment> _selected = {};
  List<ContinuousShiftType> _types = const [];
  ContinuousShiftType? _brush;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  static const _weekdays = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
  static const _monthNames = [
    '',
    'Tháng 1',
    'Tháng 2',
    'Tháng 3',
    'Tháng 4',
    'Tháng 5',
    'Tháng 6',
    'Tháng 7',
    'Tháng 8',
    'Tháng 9',
    'Tháng 10',
    'Tháng 11',
    'Tháng 12',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  String _iso(int day) {
    final m = widget.month.toString().padLeft(2, '0');
    final d = day.toString().padLeft(2, '0');
    return '${widget.year}-$m-$d';
  }

  List<({int? day, String? iso})> _cells() {
    final first = DateTime(widget.year, widget.month, 1);
    final daysInMonth = DateTime(widget.year, widget.month + 1, 0).day;
    final startPad = (first.weekday + 6) % 7;
    final cells = <({int? day, String? iso})>[];
    for (var i = 0; i < startPad; i++) {
      cells.add((day: null, iso: null));
    }
    for (var d = 1; d <= daysInMonth; d++) {
      cells.add((day: d, iso: _iso(d)));
    }
    while (cells.length % 7 != 0) {
      cells.add((day: null, iso: null));
    }
    return cells;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(attendanceRepositoryProvider);
      final results = await Future.wait([
        repo.continuousShiftTypes(),
        repo.continuousShiftDays(
          employeeId: widget.employeeId,
          year: widget.year,
          month: widget.month,
        ),
      ]);
      final types = results[0] as List<ContinuousShiftType>;
      final month = results[1] as ContinuousShiftMonth;
      final map = <String, _DayAssignment>{};
      for (final day in month.days) {
        if (day.date.isEmpty) continue;
        final assignment = _DayAssignment.fromDay(day, types);
        if (assignment.continuousStart.isNotEmpty &&
            assignment.continuousEnd.isNotEmpty) {
          map[day.date] = assignment;
        } else if (day.shiftTypeId != null) {
          for (final t in types) {
            if (t.id == day.shiftTypeId) {
              map[day.date] = _DayAssignment.fromType(t);
              break;
            }
          }
        }
      }
      if (!mounted) return;
      setState(() {
        _types = types;
        _brush = types.isEmpty ? null : types.first;
        _selected
          ..clear()
          ..addAll(map);
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Không tải được xếp ca theo ngày';
      });
    }
  }

  void _selectBrush(ContinuousShiftType type) {
    HapticFeedback.selectionClick();
    setState(() {
      _brush = type;
      _error = null;
    });
  }

  void _toggleDay(String iso) {
    final brush = _brush;
    if (brush == null) {
      setState(() => _error = 'Chọn một loại ca trước khi gắn ngày.');
      return;
    }
    HapticFeedback.selectionClick();
    setState(() {
      _error = null;
      final existing = _selected[iso];
      if (existing == null) {
        _selected[iso] = _DayAssignment.fromType(brush);
      } else if (existing.shiftTypeId == brush.id) {
        _selected.remove(iso);
      } else {
        _selected[iso] = _DayAssignment.fromType(brush);
      }
    });
  }

  void _applyMonth() {
    final brush = _brush;
    if (brush == null) {
      setState(() => _error = 'Chọn một loại ca trước.');
      return;
    }
    HapticFeedback.mediumImpact();
    final a = _DayAssignment.fromType(brush);
    setState(() {
      _error = null;
      for (final cell in _cells()) {
        final iso = cell.iso;
        if (iso != null) _selected[iso] = a;
      }
    });
  }

  void _clearAll() {
    if (_selected.isEmpty) return;
    HapticFeedback.lightImpact();
    setState(() => _selected.clear());
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final days = _selected.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key));
      final result =
          await ref.read(attendanceRepositoryProvider).setContinuousShiftDays(
                employeeId: widget.employeeId,
                year: widget.year,
                month: widget.month,
                days: [
                  for (final e in days)
                    ContinuousShiftDayInfo(
                      date: e.key,
                      shiftTypeId: e.value.shiftTypeId == 0
                          ? null
                          : e.value.shiftTypeId,
                      shiftTypeName: e.value.shiftTypeName,
                      continuousStart: e.value.continuousStart,
                      continuousEnd: e.value.continuousEnd,
                    ),
                ],
              );
      if (!mounted) return;
      final msg = result.recalculateWarning?.trim().isNotEmpty == true
          ? result.recalculateWarning!
          : 'Đã lưu ${result.dayCount} ngày xếp ca'
              '${result.recalculated > 0 ? ' · tính lại ${result.recalculated} ngày' : ''}';
      showAppSnackBar(context, msg, isSuccess: true);
      context.pop(true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không lưu được. Thử lại.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Map<int, int> get _usedTypeCounts {
    final counts = <int, int>{};
    for (final a in _selected.values) {
      counts.update(a.shiftTypeId, (v) => v + 1, ifAbsent: () => 1);
    }
    return counts;
  }

  @override
  Widget build(BuildContext context) {
    final accent = _brush != null
        ? _shiftColor(_brush!.id)
        : AppColors.primary;
    final name = widget.employeeName?.trim();
    final periodLabel =
        '${_monthNames[widget.month]} / ${widget.year}';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const Positioned.fill(child: AppAmbientBackground(intensity: 0.7)),
          Column(
            children: [
              AppScreenHeader(
                dense: true,
                title: 'Xếp ca theo ngày',
                icon: Icons.edit_calendar_rounded,
                eyebrow: 'Lịch ca',
                subtitle: [
                  if (name != null && name.isNotEmpty) name,
                  periodLabel,
                ].join(' · '),
                onBack: () => context.pop(),
              ),
              Expanded(
                child: _loading
                    ? const SkeletonList(itemCount: 6)
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.page,
                          10,
                          AppSpacing.page,
                          120,
                        ),
                        children: [
                          if (_error != null) ...[
                            NoticeBanner.error(message: _error!),
                            const SizedBox(height: 10),
                          ],
                          _ContextCard(
                            employeeName: name,
                            periodLabel: periodLabel,
                            selectedCount: _selected.length,
                            accent: accent,
                          ),
                          const SizedBox(height: 14),
                          _SectionLabel(
                            title: 'Chọn ca để gắn',
                            trailing: _types.isEmpty
                                ? null
                                : '${_types.length} loại',
                          ),
                          const SizedBox(height: 8),
                          if (_types.isEmpty)
                            NoticeBanner.warning(
                              message:
                                  'Chưa có khung ca. Tạo danh mục ca (TT/SC) trên web (HCNS) trước.',
                            )
                          else
                            SizedBox(
                              height: 118,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: _types.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(width: 10),
                                itemBuilder: (context, index) {
                                  final type = _types[index];
                                  return _ShiftTypeCard(
                                    type: type,
                                    selected: _brush?.id == type.id,
                                    color: _shiftColor(type.id),
                                    onTap: () => _selectBrush(type),
                                  );
                                },
                              ),
                            ),
                          if (_brush != null) ...[
                            const SizedBox(height: 12),
                            _BrushHint(
                              name: _brush!.name,
                              timeLabel: _brush!.timeLabel,
                              kindLabel: _brush!.displayLabel,
                              color: accent,
                            ),
                          ],
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: _QuickAction(
                                  icon: Icons.calendar_month_rounded,
                                  label: 'Gắn cả tháng',
                                  color: accent,
                                  filled: true,
                                  onTap: _types.isEmpty ? null : _applyMonth,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _QuickAction(
                                  icon: Icons.layers_clear_rounded,
                                  label: 'Bỏ chọn',
                                  color: AppColors.textSecondary,
                                  filled: false,
                                  onTap: _selected.isEmpty ? null : _clearAll,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _SectionLabel(
                            title: 'Lịch tháng',
                            trailing: _selected.isEmpty
                                ? 'Chưa gắn'
                                : '${_selected.length} ngày',
                          ),
                          const SizedBox(height: 8),
                          _CalendarGrid(
                            weekdays: _weekdays,
                            cells: _cells(),
                            selected: _selected,
                            brushId: _brush?.id,
                            onToggle: _toggleDay,
                          ),
                          if (_usedTypeCounts.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            _Legend(
                              types: _types,
                              counts: _usedTypeCounts,
                              customAssignments: [
                                for (final a in _selected.values)
                                  if (_types.every((t) => t.id != a.shiftTypeId))
                                    a,
                              ],
                            ),
                          ],
                          const SizedBox(height: 12),
                          Text(
                            'Ngày trống = ca bình thường (sáng/chiều theo mùa). Danh mục ca chỉ cấu hình trên web.',
                            textAlign: TextAlign.center,
                            style: AppTypography.style(
                              fontSize: 12,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: _BottomBar(
        accent: accent,
        saving: _saving,
        loading: _loading,
        selectedCount: _selected.length,
        onCancel: () => context.pop(),
        onSave: _save,
      ),
    );
  }
}

class _ContextCard extends StatelessWidget {
  const _ContextCard({
    required this.employeeName,
    required this.periodLabel,
    required this.selectedCount,
    required this.accent,
  });

  final String? employeeName;
  final String periodLabel;
  final int selectedCount;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      accentColor: accent,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      margin: EdgeInsets.zero,
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  accent.withValues(alpha: 0.22),
                  accent.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.person_rounded, color: accent, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (employeeName == null || employeeName!.isEmpty)
                      ? 'Nhân viên'
                      : employeeName!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.style(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  periodLabel,
                  style: AppTypography.style(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: AppRadius.brPill,
            ),
            child: Text(
              '$selectedCount ngày',
              style: AppTypography.style(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title, this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: AppTypography.style(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.15,
          ),
        ),
        const Spacer(),
        if (trailing != null)
          Text(
            trailing!,
            style: AppTypography.style(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textTertiary,
            ),
          ),
      ],
    );
  }
}

class _ShiftTypeCard extends StatelessWidget {
  const _ShiftTypeCard({
    required this.type,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final ContinuousShiftType type;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color.withValues(alpha: 0.14) : AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
          duration: AppDurations.fast,
          width: 168,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? color : AppColors.borderSoft,
              width: selected ? 1.6 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.18),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: type.isSplit
                          ? AppColors.primary.withValues(alpha: 0.12)
                          : AppColors.success.withValues(alpha: 0.12),
                      borderRadius: AppRadius.brPill,
                    ),
                    child: Text(
                      type.kind.shortLabel,
                      style: AppTypography.style(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: type.isSplit
                            ? AppColors.primaryDark
                            : AppColors.success,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (selected)
                    Icon(Icons.check_circle_rounded, size: 16, color: color)
                  else
                    const SizedBox(width: 16, height: 16),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                type.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.style(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                  color: selected ? color : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                type.displayLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.style(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                  color: AppColors.textTertiary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                type.timeLabel,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.style(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                  color: selected
                      ? color.withValues(alpha: 0.9)
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrushHint extends StatelessWidget {
  const _BrushHint({
    required this.name,
    required this.timeLabel,
    required this.kindLabel,
    required this.color,
  });

  final String name;
  final String timeLabel;
  final String kindLabel;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: AppRadius.brMd,
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Icon(Icons.touch_app_rounded, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: AppTypography.style(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                  height: 1.35,
                ),
                children: [
                  const TextSpan(text: 'Chạm ngày để gắn/bỏ '),
                  TextSpan(
                    text: name,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                  TextSpan(
                    text: ' ($kindLabel · $timeLabel)',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.filled,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool filled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: filled
            ? color.withValues(alpha: 0.12)
            : AppColors.surface,
        borderRadius: AppRadius.brCard,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.brCard,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: AppRadius.brCard,
              border: Border.all(
                color: filled
                    ? color.withValues(alpha: 0.22)
                    : AppColors.borderSoft,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 17, color: color),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.style(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CalendarGrid extends StatelessWidget {
  const _CalendarGrid({
    required this.weekdays,
    required this.cells,
    required this.selected,
    required this.onToggle,
    this.brushId,
  });

  final List<String> weekdays;
  final List<({int? day, String? iso})> cells;
  final Map<String, _DayAssignment> selected;
  final ValueChanged<String> onToggle;
  final int? brushId;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderSoft),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              for (final (i, w) in weekdays.indexed)
                Expanded(
                  child: Center(
                    child: Text(
                      w,
                      style: AppTypography.style(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: i >= 5
                            ? AppColors.warning
                            : AppColors.textTertiary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          for (var row = 0; row < cells.length / 7; row++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  for (var col = 0; col < 7; col++)
                    Expanded(
                      child: _DayCell(
                        cell: cells[row * 7 + col],
                        assignment: cells[row * 7 + col].iso == null
                            ? null
                            : selected[cells[row * 7 + col].iso],
                        brushId: brushId,
                        onTap: cells[row * 7 + col].iso == null
                            ? null
                            : () => onToggle(cells[row * 7 + col].iso!),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.cell,
    required this.assignment,
    this.brushId,
    this.onTap,
  });

  final ({int? day, String? iso}) cell;
  final _DayAssignment? assignment;
  final int? brushId;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (cell.day == null) {
      return const SizedBox(height: 58);
    }

    final active = assignment != null;
    final color =
        active ? _shiftColor(assignment!.shiftTypeId) : AppColors.textPrimary;
    final matchesBrush =
        active && brushId != null && assignment!.shiftTypeId == brushId;
    final subLabel = assignment?.cellSubLabel;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: active ? color.withValues(alpha: 0.14) : AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: AppDurations.fast,
            height: 58,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: matchesBrush
                    ? color
                    : active
                        ? color.withValues(alpha: 0.35)
                        : Colors.transparent,
                width: matchesBrush ? 1.6 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${cell.day}',
                  style: AppTypography.style(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: active ? color : AppColors.textPrimary,
                  ),
                ),
                if (active && subLabel != null) ...[
                  const SizedBox(height: 1),
                  Text(
                    subLabel,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.style(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      height: 1.05,
                      color: color,
                    ),
                  ),
                ] else
                  const SizedBox(height: 11),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({
    required this.types,
    required this.counts,
    required this.customAssignments,
  });

  final List<ContinuousShiftType> types;
  final Map<int, int> counts;
  final List<_DayAssignment> customAssignments;

  @override
  Widget build(BuildContext context) {
    final items = <({Color color, String label, int count})>[];
    for (final type in types) {
      final count = counts[type.id];
      if (count == null || count <= 0) continue;
      items.add((
        color: _shiftColor(type.id),
        label: '${type.name} (${type.kind.shortLabel})',
        count: count,
      ));
    }
    final seenCustom = <int>{};
    for (final a in customAssignments) {
      if (!seenCustom.add(a.shiftTypeId)) continue;
      items.add((
        color: _shiftColor(a.shiftTypeId),
        label: a.shiftTypeName,
        count: counts[a.shiftTypeId] ?? 0,
      ));
    }
    if (items.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final item in items)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.1),
              borderRadius: AppRadius.brPill,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: item.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${item.label} · ${item.count}',
                  style: AppTypography.style(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: item.color,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.accent,
    required this.saving,
    required this.loading,
    required this.selectedCount,
    required this.onCancel,
    required this.onSave,
  });

  final Color accent;
  final bool saving;
  final bool loading;
  final int selectedCount;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      color: AppColors.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: saving ? null : onCancel,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.brMd,
                    ),
                  ),
                  child: const Text('Hủy'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: saving || loading ? null : onSave,
                  style: FilledButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.brMd,
                    ),
                  ),
                  child: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.save_rounded, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              selectedCount == 0
                                  ? 'Lưu (xóa hết)'
                                  : 'Lưu · $selectedCount ngày',
                              style: AppTypography.style(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
