import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_motion.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/search_field.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../shared/models/department.dart';
import '../data/department_repository.dart';

class DepartmentsScreen extends ConsumerStatefulWidget {
  const DepartmentsScreen({super.key});

  @override
  ConsumerState<DepartmentsScreen> createState() => _DepartmentsScreenState();
}

class _DepartmentsScreenState extends ConsumerState<DepartmentsScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(departmentListProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: GradientAppBar(
        title: 'Phòng ban',
        subtitle: async.maybeWhen(
          data: (list) => '${list.length} khoa/phòng',
          orElse: () => null,
        ),
      ),
      body: Column(
        children: [
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.sm,
              AppSpacing.page,
              AppSpacing.sm,
            ),
            child: AppSearchField(
              hintText: 'Tìm tên, mã hoặc trưởng khoa/phòng...',
              onChanged: (value) => setState(() => _query = value.trim()),
            ),
          ),
          Expanded(
            child: async.when(
              loading: () =>
                  const SkeletonList(itemCount: 7, showAvatar: false),
              error: (e, _) => ErrorState(
                message: 'Không tải được danh sách phòng ban',
                onRetry: () => ref.invalidate(departmentListProvider),
              ),
              data: (departments) => _DepartmentList(
                departments: _filter(departments),
                hasQuery: _query.isNotEmpty,
                onRefresh: () async {
                  final _ = await ref.refresh(departmentListProvider.future);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Department> _filter(List<Department> departments) {
    final query = _query.toLowerCase();
    if (query.isEmpty) return departments;
    return departments.where((department) {
      return department.name.toLowerCase().contains(query) ||
          department.code.toLowerCase().contains(query) ||
          (department.headName?.toLowerCase().contains(query) ?? false);
    }).toList();
  }
}

class _DepartmentList extends StatelessWidget {
  const _DepartmentList({
    required this.departments,
    required this.hasQuery,
    required this.onRefresh,
  });

  final List<Department> departments;
  final bool hasQuery;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (departments.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            EmptyState(
              icon: hasQuery
                  ? Icons.search_off_rounded
                  : Icons.apartment_outlined,
              title: hasQuery
                  ? 'Không tìm thấy khoa/phòng'
                  : 'Chưa có phòng ban',
              message: hasQuery
                  ? 'Thử một từ khoá ngắn hơn hoặc kiểm tra lại mã đơn vị.'
                  : null,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          AppSpacing.sm,
          AppSpacing.page,
          AppSpacing.xxl,
        ),
        itemCount: departments.length,
        itemBuilder: (context, i) {
          final department = departments[i];
          final color =
              AppColors.chartPalette[i % AppColors.chartPalette.length];

          return AppReveal(
            delay: AppStagger.delayFor(i),
            offset: 9,
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs + 2),
              child: Semantics(
                container: true,
                label: department.headName == null
                    ? '${department.name}, mã ${department.code}'
                    : '${department.name}, mã ${department.code}, phụ trách ${department.headName}',
                child: AppCard(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: ExcludeSemantics(
                    child: Row(
                      children: [
                        AppIconBadge(
                          icon: Icons.apartment_rounded,
                          color: color,
                          size: 44,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                department.name,
                                style: AppTypography.listTitle(),
                              ),
                              const SizedBox(height: 5),
                              Wrap(
                                spacing: 7,
                                runSpacing: 5,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceHigh,
                                      borderRadius: AppRadius.brChip,
                                      border: Border.all(
                                        color: AppColors.borderSoft,
                                      ),
                                    ),
                                    child: Text(
                                      department.code,
                                      style: AppTypography.style(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                  if (department.headName != null)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.person_outline_rounded,
                                          size: 13,
                                          color: AppColors.textTertiary,
                                        ),
                                        const SizedBox(width: 3),
                                        ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            maxWidth: 220,
                                          ),
                                          child: Text(
                                            department.headName!,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppTypography.caption(),
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
