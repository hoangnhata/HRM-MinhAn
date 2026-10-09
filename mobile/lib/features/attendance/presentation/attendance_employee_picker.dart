import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_segmented_control.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/search_field.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/tinted_card_backdrop.dart';
import '../../../shared/models/employee.dart';
import '../../employees/data/employee_repository.dart';

/// Bottom sheet chọn nhân viên để xem công / gắn ca / đề xuất chế độ.
Future<EmployeeSummary?> showAttendanceEmployeePicker(
  BuildContext context, {
  required String title,
  int? departmentId,
  int? highlightId,
  String statusGroup = 'OFFICIAL',
}) {
  return showModalBottomSheet<EmployeeSummary>(
    context: context,
    showDragHandle: false,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AttendanceEmployeePickerSheet(
      title: title,
      departmentId: departmentId,
      highlightId: highlightId,
      statusGroup: statusGroup,
    ),
  );
}

class _AttendanceEmployeePickerSheet extends ConsumerStatefulWidget {
  const _AttendanceEmployeePickerSheet({
    required this.title,
    this.departmentId,
    this.highlightId,
    this.statusGroup = 'OFFICIAL',
  });

  final String title;
  final int? departmentId;
  final int? highlightId;
  final String statusGroup;

  @override
  ConsumerState<_AttendanceEmployeePickerSheet> createState() =>
      _AttendanceEmployeePickerSheetState();
}

class _AttendanceEmployeePickerSheetState
    extends ConsumerState<_AttendanceEmployeePickerSheet> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();

  List<EmployeeSummary> _items = const [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _total = 0;
  int _page = 0;
  String? _error;
  String _query = '';
  late String _status = widget.statusGroup;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      final pos = _scrollController.position;
      if (pos.pixels > pos.maxScrollExtent - 240) _loadMore();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _load(reset: true));
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({required bool reset, bool silent = false}) async {
    if (reset) {
      setState(() {
        if (!silent) _loading = true;
        _error = null;
        _page = 0;
        _hasMore = true;
      });
    }
    try {
      final page = await ref
          .read(employeeRepositoryProvider)
          .list(
            page: reset ? 0 : _page,
            size: 20,
            query: _query.isEmpty ? null : _query,
            statusGroup: _status,
            departmentId: widget.departmentId,
          );
      if (!mounted) return;
      setState(() {
        _items = reset ? page.content : [..._items, ...page.content];
        _page = page.number;
        _hasMore = !page.last;
        _total = page.totalElements;
        _loading = false;
        _loadingMore = false;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = e.message;
        if (reset) _items = const [];
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = 'Không tải được danh sách';
        if (reset) _items = const [];
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    _page += 1;
    await _load(reset: false);
  }

  static const _statuses = [
    ('WORKING', 'Đang làm'),
    ('OFFICIAL', 'Chính thức'),
    ('TRIAL', 'Thử việc'),
  ];

  void _setStatus(String value) {
    if (_status == value) return;
    setState(() => _status = value);
    _load(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.88;
    final statusIndex = _statuses.indexWhere((s) => s.$1 == _status);
    final statusLabel = statusIndex >= 0 ? _statuses[statusIndex].$2 : '';

    return Container(
      height: height,
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: AppRadius.brSheetTop,
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: AppRadius.brPill,
            ),
          ),
          // ── Đầu sheet ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
            child: Row(
              children: [
                const TintedIconTile(
                  icon: Icons.person_search_rounded,
                  color: AppColors.primary,
                  size: 40,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.style(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                          height: AppTypography.uppercaseHeight,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _loading && _items.isEmpty
                            ? 'Đang tải danh sách…'
                            : '$_total nhân viên · $statusLabel',
                        style: AppTypography.style(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Semantics(
                  button: true,
                  label: 'Đóng',
                  child: Material(
                    color: AppColors.surface,
                    shape: const CircleBorder(
                      side: BorderSide(color: AppColors.borderSoft),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => Navigator.pop(context),
                      child: const SizedBox(
                        width: 38,
                        height: 38,
                        child: Icon(
                          Icons.close_rounded,
                          size: 20,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: AppSearchField(
              controller: _searchController,
              hintText: 'Tìm tên, mã NV…',
              autofocus: true,
              onChanged: (v) {
                _query = v.trim();
                _load(reset: true);
              },
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: AppSegmentedControl(
              style: AppSegmentStyle.soft,
              dense: true,
              selectedIndex: statusIndex < 0 ? 1 : statusIndex,
              onChanged: (i) => _setStatus(_statuses[i].$1),
              items: [for (final s in _statuses) AppSegmentItem(label: s.$2)],
            ),
          ),
          const SizedBox(height: 6),
          Expanded(child: _buildList()),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_loading && _items.isEmpty) {
      return const SkeletonList(itemCount: 8);
    }
    if (_error != null && _items.isEmpty) {
      return ErrorState(message: _error!, onRetry: () => _load(reset: true));
    }
    if (_items.isEmpty) {
      return const EmptyState(
        icon: Icons.person_off_outlined,
        title: 'Không có nhân viên',
        message: 'Thử đổi từ khóa hoặc bộ lọc.',
      );
    }
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => _load(reset: true, silent: true),
      child: ListView.separated(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: _items.length + (_loadingMore ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          if (index >= _items.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                ),
              ),
            );
          }
          final emp = _items[index];
          return _EmployeeTile(
            employee: emp,
            selected: emp.id == widget.highlightId,
            onTap: () {
              HapticFeedback.selectionClick();
              Navigator.pop(context, emp);
            },
          );
        },
      ),
    );
  }
}

/// Sắc chức danh — giúp lướt danh sách nhận ra nhóm nghề nhanh.
Color _roleTone(String? title) {
  final t = (title ?? '').toLowerCase();
  if (t.contains('bác sĩ') || t.startsWith('bs')) return AppColors.info;
  if (t.contains('điều dưỡng')) return AppColors.roleNurse;
  if (t.contains('ktv') || t.contains('kỹ thuật')) {
    return AppColors.roleTechnician;
  }
  if (t.contains('hộ sinh')) return AppColors.roleMidwife;
  if (t.contains('dược')) return AppColors.success;
  return AppColors.primary;
}

/// "KHOA GÂY MÊ HỒI SỨC" → "Khoa Gây Mê Hồi Sức" (tên khoa lưu in hoa).
String _prettyDept(String raw) {
  final text = raw.trim();
  if (text.isEmpty || text != text.toUpperCase()) return text;
  return text
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .map(
        (w) => w.isEmpty
            ? w
            : '${w.characters.first.toUpperCase()}${w.characters.skip(1)}',
      )
      .join(' ');
}

class _EmployeeTile extends StatelessWidget {
  const _EmployeeTile({
    required this.employee,
    required this.selected,
    required this.onTap,
  });

  final EmployeeSummary employee;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final emp = employee;
    final tone = _roleTone(emp.positionTitle);
    final dept = _prettyDept(emp.departmentName ?? '');
    final position = (emp.positionTitle ?? '').trim();

    return Material(
      type: MaterialType.transparency,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.brCard,
        side: BorderSide(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.45)
              : AppColors.borderSoft,
          width: selected ? 1.4 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(
          color: selected ? null : AppColors.surface,
          gradient: selected
              ? TintedCardBackdrop.gradient(AppColors.primary)
              : null,
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: tone.withValues(alpha: 0.35),
                      width: 1.5,
                    ),
                  ),
                  child: AppAvatar(
                    name: emp.fullName,
                    imageUrl: emp.avatarUrl,
                    size: 42,
                    showShadow: false,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        emp.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.style(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                          height: AppTypography.uppercaseHeight,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          if (position.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: tone.withValues(alpha: 0.10),
                                borderRadius: AppRadius.brPill,
                              ),
                              child: Text(
                                position,
                                maxLines: 1,
                                style: AppTypography.style(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  height: AppTypography.uppercaseHeight,
                                  color: Color.lerp(
                                    tone,
                                    AppColors.textPrimary,
                                    0.2,
                                  )!,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Expanded(
                            child: Text(
                              dept,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.style(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (selected)
                  Container(
                    padding: const EdgeInsets.fromLTRB(6, 3, 8, 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: AppRadius.brPill,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.visibility_rounded,
                          size: 12,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Đang xem',
                          style: AppTypography.style(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            height: AppTypography.uppercaseHeight,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  const TintedChevron(accent: AppColors.textTertiary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
