import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_action_button.dart';
import '../../../core/widgets/app_ambient_background.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/notice_banner.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/tinted_card_backdrop.dart';
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
      continuousEnd: split ? (type.afternoonEnd ?? type.endTime) : type.endTime,
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

  Future<void> _load({bool silent = false}) async {
    setState(() {
      if (!silent) _loading = true;
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
      final result = await ref
          .read(attendanceRepositoryProvider)
          .setContinuousShiftDays(
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
    final accent = _brush != null ? _shiftColor(_brush!.id) : AppColors.primary;
    final name = widget.employeeName?.trim();
    final periodLabel = '${_monthNames[widget.month]} / ${widget.year}';

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
                    : RefreshIndicator(
                        color: AppColors.primary,
                        onRefresh: () => _load(silent: true),
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
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
                              totalDays: DateTime(
                                widget.year,
                                widget.month + 1,
                                0,
                              ).day,
                            ),
                            const SizedBox(height: 14),
                            _SectionLabel(
                              title: 'Chọn ca để gắn',
                              icon: Icons.layers_rounded,
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
                                height: 122,
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
                                color: accent,
                              ),
                            ],
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: _QuickAction(
                                    icon: Icons.event_repeat_rounded,
                                    label: 'Gắn cả tháng',
                                    color: accent,
                                    onTap: _types.isEmpty ? null : _applyMonth,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _QuickAction(
                                    icon: Icons.layers_clear_rounded,
                                    label: 'Bỏ hết ngày',
                                    color: AppColors.error,
                                    onTap: _selected.isEmpty ? null : _clearAll,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            _SectionLabel(
                              title: 'Lịch tháng',
                              icon: Icons.calendar_month_rounded,
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
                                    if (_types.every(
                                      (t) => t.id != a.shiftTypeId,
                                    ))
                                      a,
                                ],
                              ),
                            ],
                            const SizedBox(height: 12),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(top: 1),
                                  child: Icon(
                                    Icons.info_outline_rounded,
                                    size: 14,
                                    color: AppColors.textTertiary,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Ngày trống = ca bình thường (sáng/chiều theo mùa). Danh mục ca chỉ cấu hình trên web.',
                                    style: AppTypography.style(
                                      fontSize: 12,
                                      height: 1.4,
                                      color: AppColors.textTertiary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: _BottomBar(
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
    required this.totalDays,
  });

  final String? employeeName;
  final String periodLabel;
  final int selectedCount;
  final int totalDays;

  @override
  Widget build(BuildContext context) {
    const accent = AppColors.primary;
    final name = (employeeName == null || employeeName!.isEmpty)
        ? 'Nhân viên'
        : employeeName!;
    final ratio = totalDays == 0 ? 0.0 : selectedCount / totalDays;

    return AppCard(
      gradient: TintedCardBackdrop.gradient(accent),
      borderRadius: AppRadius.brCard,
      padding: EdgeInsets.zero,
      margin: EdgeInsets.zero,
      child: TintedCardBackdrop(
        accent: accent,
        watermarkIcon: Icons.edit_calendar_rounded,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  AppAvatar(name: name, size: 44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.style(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                            height: AppTypography.uppercaseHeight,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          periodLabel,
                          style: AppTypography.style(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '$selectedCount',
                              style: AppTypography.metric(
                                fontSize: 20,
                                color: AppColors.primaryDark,
                                height: 1.0,
                              ),
                            ),
                            TextSpan(
                              text: '/$totalDays',
                              style: AppTypography.metric(
                                fontSize: 12.5,
                                color: AppColors.textTertiary,
                                height: 1.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'NGÀY ĐÃ GẮN',
                        style: AppTypography.uppercase(
                          fontSize: 8.5,
                          letterSpacing: 0.6,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: AppRadius.brPill,
                child: Container(
                  height: 6,
                  color: accent.withValues(alpha: 0.10),
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: ratio.clamp(0.0, 1.0),
                    heightFactor: 1,
                    child: const DecoratedBox(
                      decoration: BoxDecoration(gradient: AppGradients.brand),
                    ),
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title, required this.icon, this.trailing});

  final String title;
  final IconData icon;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        TintedIconTile(icon: icon, color: AppColors.primary, size: 28),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            title,
            style: AppTypography.style(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
              height: AppTypography.uppercaseHeight,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        if (trailing != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.brPill,
              border: Border.all(color: AppColors.borderSoft),
            ),
            child: Text(
              trailing!,
              style: AppTypography.style(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                height: AppTypography.uppercaseHeight,
                color: AppColors.textSecondary,
              ),
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
    final dark = Color.lerp(color, AppColors.textPrimary, 0.3)!;
    return Semantics(
      button: true,
      selected: selected,
      label: '${type.name}, ${type.displayLabel}, ${type.timeLabel}',
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.brCard,
          side: BorderSide(
            color: selected ? color : AppColors.borderSoft,
            width: selected ? 1.6 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            color: selected ? null : AppColors.surface,
            gradient: selected ? TintedCardBackdrop.gradient(color) : null,
          ),
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              width: 196,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        TintedIconTile(
                          icon: type.isSplit
                              ? Icons.call_split_rounded
                              : Icons.timeline_rounded,
                          color: color,
                          size: 28,
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.10),
                            borderRadius: AppRadius.brPill,
                          ),
                          child: Text(
                            type.displayLabel,
                            style: AppTypography.style(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              height: AppTypography.uppercaseHeight,
                              color: dark,
                            ),
                          ),
                        ),
                        const Spacer(),
                        AnimatedContainer(
                          duration: AppDurations.fast,
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: selected ? color : AppColors.surface,
                            border: Border.all(
                              color: selected ? color : AppColors.border,
                              width: 1.5,
                            ),
                          ),
                          child: selected
                              ? const Icon(
                                  Icons.check_rounded,
                                  size: 13,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 9),
                    Text(
                      type.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.style(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        height: 1.3,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 13,
                          color: color.withValues(alpha: 0.8),
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            type.timeLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.metric(
                              fontSize: 13,
                              color: dark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Thanh "cọ" đang chọn: ca nào sẽ được gắn khi chạm ngày.
class _BrushHint extends StatelessWidget {
  const _BrushHint({
    required this.name,
    required this.timeLabel,
    required this.color,
  });

  final String name;
  final String timeLabel;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 9, 12, 9),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.brCard,
        border: Border.all(color: color.withValues(alpha: 0.28)),
        boxShadow: AppShadows.soft,
      ),
      child: Row(
        children: [
          TintedIconTile(icon: Icons.touch_app_rounded, color: color, size: 32),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CHẠM NGÀY ĐỂ GẮN / BỎ',
                  style: AppTypography.uppercase(
                    fontSize: 9.5,
                    letterSpacing: 0.6,
                    color: AppColors.textTertiary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.style(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    height: AppTypography.uppercaseHeight,
                    color: Color.lerp(color, AppColors.textPrimary, 0.3)!,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            timeLabel,
            style: AppTypography.metric(
              fontSize: 12.5,
              color: AppColors.textSecondary,
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
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final fg = enabled ? color : AppColors.textTertiary;
    return Material(
      type: MaterialType.transparency,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.brCard,
        side: BorderSide(
          color: enabled ? color.withValues(alpha: 0.28) : AppColors.borderSoft,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        color: enabled ? AppColors.surface : AppColors.surfaceAlt,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 44,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 17, color: fg),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.style(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      height: AppTypography.uppercaseHeight,
                      color: enabled
                          ? Color.lerp(color, AppColors.textPrimary, 0.25)!
                          : AppColors.textTertiary,
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
    final now = DateTime.now();
    final todayIso =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.brCard,
        border: Border.all(color: AppColors.borderSoft),
        boxShadow: AppShadows.soft,
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
                      style: AppTypography.uppercase(
                        fontSize: 10.5,
                        letterSpacing: 0.3,
                        color: i >= 5
                            ? AppColors.errorDark.withValues(alpha: 0.75)
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
                        weekend: col >= 5,
                        today: cells[row * 7 + col].iso == todayIso,
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
    this.weekend = false,
    this.today = false,
    this.brushId,
    this.onTap,
  });

  final ({int? day, String? iso}) cell;
  final _DayAssignment? assignment;
  final bool weekend;
  final bool today;
  final int? brushId;
  final VoidCallback? onTap;

  static const double _height = 54;

  @override
  Widget build(BuildContext context) {
    if (cell.day == null) return const SizedBox(height: _height);

    final active = assignment != null;
    final color = active
        ? _shiftColor(assignment!.shiftTypeId)
        : AppColors.primary;
    final matchesBrush =
        active && brushId != null && assignment!.shiftTypeId == brushId;
    final numberColor = active
        ? Color.lerp(color, AppColors.textPrimary, 0.3)!
        : weekend
        ? AppColors.errorDark.withValues(alpha: 0.75)
        : AppColors.textPrimary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.brControl,
          child: AnimatedContainer(
            duration: AppDurations.fast,
            height: _height,
            decoration: BoxDecoration(
              color: active
                  ? color.withValues(alpha: 0.12)
                  : AppColors.surfaceAlt,
              borderRadius: AppRadius.brControl,
              border: Border.all(
                color: matchesBrush
                    ? color
                    : active
                    ? color.withValues(alpha: 0.35)
                    : today
                    ? AppColors.primary.withValues(alpha: 0.5)
                    : AppColors.borderSoft,
                width: matchesBrush || today ? 1.5 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${cell.day}',
                  style: AppTypography.metric(
                    fontSize: 14.5,
                    color: numberColor,
                  ),
                ),
                const SizedBox(height: 4),
                if (active)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: AppRadius.brPill,
                    ),
                    child: Text(
                      assignment!.kind.shortLabel,
                      style: AppTypography.style(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                        color: Colors.white,
                      ),
                    ),
                  )
                else
                  Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: today ? AppColors.primary : Colors.transparent,
                      shape: BoxShape.circle,
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
    final items = <({Color color, String label, String time, int count})>[];
    for (final type in types) {
      final count = counts[type.id];
      if (count == null || count <= 0) continue;
      items.add((
        color: _shiftColor(type.id),
        label: type.name,
        time: type.timeLabel,
        count: count,
      ));
    }
    final seenCustom = <int>{};
    for (final a in customAssignments) {
      if (!seenCustom.add(a.shiftTypeId)) continue;
      items.add((
        color: _shiftColor(a.shiftTypeId),
        label: a.shiftTypeName,
        time: a.timeLabel,
        count: counts[a.shiftTypeId] ?? 0,
      ));
    }
    if (items.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.brCard,
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'CHÚ GIẢI',
            style: AppTypography.uppercase(
              fontSize: 9.5,
              letterSpacing: 0.6,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 6),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: item.color,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.style(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if (item.time.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Text(
                      item.time,
                      style: AppTypography.metric(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(width: 8),
                  Container(
                    constraints: const BoxConstraints(minWidth: 26),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: item.color.withValues(alpha: 0.12),
                      borderRadius: AppRadius.brPill,
                    ),
                    child: Text(
                      '${item.count}',
                      textAlign: TextAlign.center,
                      style: AppTypography.metric(
                        fontSize: 11.5,
                        color: Color.lerp(
                          item.color,
                          AppColors.textPrimary,
                          0.3,
                        )!,
                      ),
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

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.saving,
    required this.loading,
    required this.selectedCount,
    required this.onCancel,
    required this.onSave,
  });

  final bool saving;
  final bool loading;
  final int selectedCount;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl),
        ),
        boxShadow: AppShadows.nav,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: AppActionButton(
                  variant: AppActionVariant.outlineNeutral,
                  label: 'Hủy',
                  onPressed: saving ? null : onCancel,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                flex: 3,
                child: AppActionButton(
                  variant: AppActionVariant.primary,
                  icon: Icons.save_rounded,
                  label: selectedCount == 0
                      ? 'Lưu (bỏ hết ca)'
                      : 'Lưu · $selectedCount ngày',
                  loading: saving,
                  onPressed: loading ? null : onSave,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
