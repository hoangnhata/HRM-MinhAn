import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/search_field.dart';
import '../../../core/widgets/skeleton.dart';
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

  Future<void> _load({required bool reset}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
        _page = 0;
        _hasMore = true;
      });
    }
    try {
      final page = await ref.read(employeeRepositoryProvider).list(
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

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.88;
    return Container(
      height: height,
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.borderSoft,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: AppTypography.style(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
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
            child: Row(
              children: [
                _Chip(
                  label: 'Đang làm',
                  selected: _status == 'WORKING',
                  onTap: () {
                    if (_status == 'WORKING') return;
                    setState(() => _status = 'WORKING');
                    _load(reset: true);
                  },
                ),
                const SizedBox(width: 8),
                _Chip(
                  label: 'Chính thức',
                  selected: _status == 'OFFICIAL',
                  onTap: () {
                    if (_status == 'OFFICIAL') return;
                    setState(() => _status = 'OFFICIAL');
                    _load(reset: true);
                  },
                ),
                const SizedBox(width: 8),
                _Chip(
                  label: 'Thử việc',
                  selected: _status == 'TRIAL',
                  onTap: () {
                    if (_status == 'TRIAL') return;
                    setState(() => _status = 'TRIAL');
                    _load(reset: true);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
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
    return ListView.separated(
      controller: _scrollController,
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
        final selected = emp.id == widget.highlightId;
        return Material(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.08)
              : AppColors.surface,
          borderRadius: AppRadius.brCard,
          child: InkWell(
            borderRadius: AppRadius.brCard,
            onTap: () {
              HapticFeedback.selectionClick();
              Navigator.pop(context, emp);
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Row(
                children: [
                  AppAvatar(
                    name: emp.fullName,
                    imageUrl: emp.avatarUrl,
                    size: 44,
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
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          [
                            if ((emp.positionTitle ?? '').isNotEmpty)
                              emp.positionTitle!,
                            if ((emp.departmentName ?? '').isNotEmpty)
                              emp.departmentName!,
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.style(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.chevron_right_rounded,
                    color: selected
                        ? AppColors.primary
                        : AppColors.textTertiary,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.primary.withValues(alpha: 0.12)
          : AppColors.surfaceMuted,
      borderRadius: AppRadius.brPill,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.brPill,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            label,
            style: AppTypography.style(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: selected ? AppColors.primaryDark : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
