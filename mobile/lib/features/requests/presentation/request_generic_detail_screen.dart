import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/nursing_block.dart';
import '../../../core/utils/request_edit_access.dart';
import '../../../core/utils/user_role.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/auth_image_preview.dart';
import '../../../core/widgets/auth_network_image.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/highlight_pulse.dart';
import '../../../core/widgets/info_row.dart';
import '../../../core/widgets/status_chip.dart';
import '../../auth/application/auth_controller.dart';
import '../application/generic_request_controller.dart';
import '../data/request_type_config.dart';
import 'approval_fields_sheet.dart';
import 'generic_request_ui.dart';
import 'request_generic_card.dart';
import 'typed_request_detail_body.dart';

class RequestGenericDetailScreen extends ConsumerStatefulWidget {
  const RequestGenericDetailScreen({
    super.key,
    required this.typeKey,
    required this.requestId,
    this.highlight = false,
  });

  final String typeKey;
  final int requestId;
  final bool highlight;

  @override
  ConsumerState<RequestGenericDetailScreen> createState() =>
      _RequestGenericDetailScreenState();
}

class _RequestGenericDetailScreenState
    extends ConsumerState<RequestGenericDetailScreen> {
  bool _busy = false;

  /// Đơn tải riêng theo id khi không có trong danh sách đã nạp.
  Map<String, dynamic>? _fetched;
  bool _fetching = false;
  bool _fetchFailed = false;

  /// Chỉ gọi API khi các danh sách đã nạp xong mà vẫn không thấy đơn.
  void _ensureFetched(GenericRequestState state) {
    if (state.loading || _fetching || _fetched != null || _fetchFailed) return;
    _fetching = true;
    Future.microtask(() async {
      final row = await ref
          .read(genericRequestControllerProvider(widget.typeKey).notifier)
          .fetchById(widget.requestId);
      if (!mounted) return;
      setState(() {
        _fetched = row;
        _fetching = false;
        _fetchFailed = row == null;
      });
    });
  }

  void _retryFetch() {
    setState(() {
      _fetched = null;
      _fetching = false;
      _fetchFailed = false;
    });
  }

  Future<void> _review(PendingItem item, bool approved) async {
    String? comment;
    var extra = const <String, dynamic>{};

    if (approved) {
      if (item.stage.approveFields.isNotEmpty) {
        // Một số bước duyệt yêu cầu nhập thêm dữ liệu (backend chặn nếu thiếu).
        final input = await showApprovalFieldsSheet(
          context,
          stage: item.stage,
          title: 'Duyệt ở bước ${item.stage.label}',
        );
        if (input == null) return;
        extra = input.extra;
        comment = input.comment;
      } else {
        final confirm = await showConfirmDialog(
          context,
          title: 'Duyệt đơn',
          message:
              'Đơn sẽ được chuyển sang bước tiếp theo kèm chữ ký của bạn. Xác nhận duyệt?',
          confirmLabel: 'Duyệt',
          icon: Icons.check_circle_outline_rounded,
        );
        if (!confirm) return;
      }
    } else {
      comment = await showNoteInputDialog(
        context,
        title: 'Từ chối đơn',
        label: 'Lý do từ chối',
        hint: 'Nêu rõ lý do để người gửi nắm được...',
        required: true,
        confirmLabel: 'Từ chối',
        confirmColor: AppColors.error,
      );
      if (comment == null) return;
    }

    setState(() => _busy = true);
    final ok = await ref
        .read(genericRequestControllerProvider(widget.typeKey).notifier)
        .review(item, approved: approved, comment: comment, extra: extra);
    if (!mounted) return;
    setState(() => _busy = false);

    if (ok) {
      showAppSnackBar(
        context,
        approved ? 'Đã duyệt đơn' : 'Đã từ chối đơn',
        isSuccess: true,
      );
      Navigator.of(context).maybePop();
    } else {
      showAppSnackBar(
        context,
        ref.read(genericRequestControllerProvider(widget.typeKey)).error ??
            'Thao tác thất bại',
        isError: true,
      );
    }
  }

  Future<void> _cancel(int id) async {
    final confirm = await showConfirmDialog(
      context,
      title: 'Huỷ đơn',
      message: 'Đơn sẽ bị huỷ và không tiếp tục quy trình duyệt. Xác nhận huỷ?',
      confirmLabel: 'Huỷ đơn',
      danger: true,
    );
    if (!confirm) return;

    setState(() => _busy = true);
    final ok = await ref
        .read(genericRequestControllerProvider(widget.typeKey).notifier)
        .cancel(id);
    if (!mounted) return;
    setState(() => _busy = false);

    if (ok) {
      showAppSnackBar(context, 'Đã huỷ đơn', isSuccess: true);
      Navigator.of(context).maybePop();
    } else {
      showAppSnackBar(
        context,
        ref.read(genericRequestControllerProvider(widget.typeKey)).error ??
            'Huỷ đơn thất bại',
        isError: true,
      );
    }
  }

  void _edit(Map<String, dynamic> raw) {
    final employeeId = (raw['employeeId'] as num?)?.toInt();
    if (employeeId == null) return;
    context.push(
      RoutePaths.requestCreatePath(
        widget.typeKey,
        employeeId: employeeId,
        requestId: widget.requestId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = RequestTypeConfig.byKey(widget.typeKey);
    final state = ref.watch(genericRequestControllerProvider(widget.typeKey));
    final auth = ref.watch(authControllerProvider);
    final role = auth.role;

    Map<String, dynamic>? raw;
    PendingItem? pendingItem;
    var fromRelated = false;

    for (final list in [state.related, state.history]) {
      for (final item in list) {
        if ((item['id'] as num).toInt() == widget.requestId) raw = item;
      }
    }
    for (final p in state.pending) {
      if ((p.raw['id'] as num).toInt() == widget.requestId) {
        pendingItem = p;
        raw = p.raw;
      }
    }
    for (final item in state.related) {
      if ((item['id'] as num).toInt() == widget.requestId) {
        fromRelated = true;
        break;
      }
    }

    raw ??= _fetched;

    if (raw == null) {
      _ensureFetched(state);
      final loading = state.loading || _fetching;
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: GradientAppBar(title: config.label),
        body: loading
            ? const LoadingState(label: 'Đang tải đơn...')
            : state.error != null
            ? ErrorState(message: state.error!, onRetry: _retryFetch)
            : EmptyState(
                icon: Icons.search_off_rounded,
                title: 'Không tìm thấy đơn',
                message: 'Đơn có thể đã bị huỷ hoặc bạn không còn quyền xem.',
                action: OutlinedButton.icon(
                  onPressed: _retryFetch,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Tải lại'),
                ),
              ),
      );
    }

    final status = raw['status'] as String?;
    final canCancel =
        RoleGroups.isIn(role, config.canCancelRoles) &&
        state.related.any(
          (r) => (r['id'] as num).toInt() == widget.requestId,
        ) &&
        (status?.toUpperCase().contains('PENDING') ?? false);
    final inOwnView = fromRelated || _fetched != null;
    final canEdit = inOwnView &&
        canEditOwnPendingRequest(
          raw,
          username: auth.currentUser?.username,
          role: role,
        );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: GradientAppBar(title: config.shortLabel, subtitle: config.label),
      body: Column(
        children: [
          Expanded(
            child: HighlightPulse(
              active: widget.highlight,
              child: _Body(
                config: config,
                raw: raw,
                status: status,
                stageLabel: pendingItem?.stage.label,
                currentStage: pendingItem?.stage,
              ),
            ),
          ),
          if (pendingItem != null || canCancel || canEdit)
            _ActionBar(
              busy: _busy,
              onApprove: pendingItem == null
                  ? null
                  : () => _review(pendingItem!, true),
              onReject: pendingItem == null
                  ? null
                  : () => _review(pendingItem!, false),
              onCancel: canCancel ? () => _cancel(widget.requestId) : null,
              onEdit: canEdit ? () => _edit(raw!) : null,
            ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.config,
    required this.raw,
    required this.status,
    required this.stageLabel,
    required this.currentStage,
  });

  final RequestTypeConfig config;
  final Map<String, dynamic> raw;
  final String? status;
  final String? stageLabel;
  final RequestReviewStage? currentStage;

  @override
  Widget build(BuildContext context) {
    final timeline = config.stages.isEmpty
        ? null
        : _ApprovalTimeline(
            config: config,
            raw: raw,
            currentStage: currentStage,
          );

    if (TypedRequestDetailBody.supports(config.key)) {
      return TypedRequestDetailBody(
        config: config,
        raw: raw,
        status: status,
        stageLabel: stageLabel,
        bottom: timeline,
      );
    }

    final name =
        raw['employeeName'] as String? ??
        raw['fullName'] as String? ??
        'Đơn #${raw['id']}';
    final department =
        raw['departmentName'] as String? ?? raw['department'] as String?;

    return ListView(
      padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.xl),
      children: [
        Padding(
          padding: AppSpacing.pageH,
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AppIconBadge(
                      icon: config.icon,
                      color: config.color,
                      size: 48,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                              height: 1.25,
                              letterSpacing: -0.2,
                            ),
                          ),
                          if (department != null && department.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              department,
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                          if (status != null) ...[
                            const SizedBox(height: 6),
                            StatusChip(
                              label: genericRequestStatusLabel(status),
                              color: GenericRequestUi.statusColor(status!),
                              dense: true,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                if (stageLabel != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.09),
                      borderRadius: AppRadius.brXs,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.pending_actions_outlined,
                          size: 15,
                          color: AppColors.warning,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Đơn đang chờ bạn duyệt ở bước: $stageLabel',
                            style: const TextStyle(
                              fontSize: 11.8,
                              fontWeight: FontWeight.w700,
                              color: AppColors.warning,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        SectionCard(
          title: 'Thông tin đơn',
          icon: Icons.description_outlined,
          accentColor: config.color,
          child: Column(
            children: [
              if (raw['createdAt'] != null)
                InfoRow(
                  label: 'Ngày gửi',
                  value: AppFormat.dateTime(
                    DateTime.tryParse(raw['createdAt'] as String),
                  ),
                  icon: Icons.send_outlined,
                ),
              for (final entry in GenericRequestUi.displayableEntries(raw))
                _RequestValueRow(config: config, entry: entry),
            ],
          ),
        ),
        if (config.stages.isNotEmpty) timeline!,
      ],
    );
  }
}

class _RequestValueRow extends StatelessWidget {
  const _RequestValueRow({required this.config, required this.entry});

  final RequestTypeConfig config;
  final MapEntry<String, dynamic> entry;

  @override
  Widget build(BuildContext context) {
    final value = entry.value;
    final key = entry.key.toLowerCase();
    final complex = value is Map || value is List;
    final multiline =
        complex ||
        key.contains('reason') ||
        key.contains('comment') ||
        key.contains('goal') ||
        (value is String && value.length > 48);

    return InfoRow(
      label: GenericRequestUi.fieldLabel(config, entry.key),
      value: _semanticValue(value),
      multiline: multiline,
      valueWidget: _TypedRequestValue(
        config: config,
        fieldKey: entry.key,
        value: value,
        alignEnd: !multiline,
      ),
    );
  }
}

class _TypedRequestValue extends StatelessWidget {
  const _TypedRequestValue({
    required this.config,
    required this.fieldKey,
    required this.value,
    this.alignEnd = false,
    this.depth = 0,
  });

  final RequestTypeConfig config;
  final String fieldKey;
  final dynamic value;
  final bool alignEnd;
  final int depth;

  @override
  Widget build(BuildContext context) {
    if (value is bool) {
      return Align(
        alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
        child: StatusChip(
          label: value as bool ? 'Có' : 'Không',
          color: value as bool ? AppColors.success : AppColors.textSecondary,
          dense: true,
          showDot: false,
        ),
      );
    }

    if (value is List) return _buildList(context, value as List<dynamic>);
    if (value is Map) return _buildMap(context, value as Map<dynamic, dynamic>);

    return Text(
      _friendlyScalar(value),
      textAlign: alignEnd ? TextAlign.end : TextAlign.start,
      style: const TextStyle(
        fontSize: 13.2,
        fontWeight: FontWeight.w600,
        height: 1.4,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildList(BuildContext context, List<dynamic> values) {
    if (values.isEmpty) return const Text('—');
    final scalarOnly = values.every((item) => item is! Map && item is! List);

    if (scalarOnly) {
      return Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final item in values)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.07),
                borderRadius: AppRadius.brPill,
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.14),
                ),
              ),
              child: Text(
                _friendlyScalar(item),
                style: const TextStyle(
                  fontSize: 12.2,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < values.length; index++) ...[
          Container(
            padding: const EdgeInsets.all(AppSpacing.xs),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: AppRadius.brXs,
              border: Border.all(color: AppColors.borderSoft),
            ),
            child: _TypedRequestValue(
              config: config,
              fieldKey: fieldKey,
              value: values[index],
              depth: depth + 1,
            ),
          ),
          if (index != values.length - 1) const SizedBox(height: AppSpacing.xs),
        ],
      ],
    );
  }

  Widget _buildMap(BuildContext context, Map<dynamic, dynamic> values) {
    final entries = values.entries
        .where((entry) => entry.value != null)
        .toList();
    if (entries.isEmpty) return const Text('—');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: AppRadius.brXs,
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var index = 0; index < entries.length; index++) ...[
            Text(
              GenericRequestUi.fieldLabel(
                config,
                entries[index].key.toString(),
              ),
              style: const TextStyle(
                fontSize: 11.8,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 3),
            _TypedRequestValue(
              config: config,
              fieldKey: entries[index].key.toString(),
              value: entries[index].value,
              depth: depth + 1,
            ),
            if (index != entries.length - 1)
              const Divider(height: AppSpacing.md),
          ],
        ],
      ),
    );
  }
}

String _friendlyScalar(dynamic value) {
  if (value == null) return '—';
  if (value is bool) return value ? 'Có' : 'Không';
  if (value is String) {
    final normalized = value.trim().toUpperCase();
    const labels = <String, String>{
      'MALE': 'Nam',
      'FEMALE': 'Nữ',
      'YES': 'Có',
      'NO': 'Không',
      'WINTER': 'Mùa đông',
      'SUMMER': 'Mùa hè',
      'MORNING': 'Buổi sáng',
      'AFTERNOON': 'Buổi chiều',
      'FULL_DAY': 'Cả ngày',
      'INTERNAL': 'Nội bộ',
      'EXTERNAL': 'Bên ngoài',
    };
    if (labels.containsKey(normalized)) return labels[normalized]!;
  }
  return GenericRequestUi.formatValue(value);
}

String _semanticValue(dynamic value) {
  if (value is List) {
    if (value.isEmpty) return 'Không có mục nào';
    final preview = value
        .take(3)
        .map(
          (item) => item is Map || item is List
              ? 'một nhóm thông tin'
              : _friendlyScalar(item),
        )
        .join(', ');
    return '${value.length} mục: $preview';
  }
  if (value is Map) {
    final count = value.values.where((item) => item != null).length;
    return count == 0 ? 'Không có thông tin' : '$count trường thông tin';
  }
  return _friendlyScalar(value);
}

enum _ProcessStepState { completed, current, rejected, upcoming, stopped }

class _ApprovalTimeline extends StatelessWidget {
  const _ApprovalTimeline({
    required this.config,
    required this.raw,
    required this.currentStage,
  });

  final RequestTypeConfig config;
  final Map<String, dynamic> raw;
  final RequestReviewStage? currentStage;

  @override
  Widget build(BuildContext context) {
    final status = (raw['status'] as String? ?? '').toUpperCase();
    final stages = _displayStages(config, raw);
    final currentFromStatus = stages.indexWhere(
      (stage) => status == 'PENDING_${_stageCode(stage.reviewSlug)}',
    );
    final currentFromPending = currentStage == null
        ? -1
        : stages.indexWhere(
            (stage) => stage.reviewSlug == currentStage!.reviewSlug,
          );
    final currentIndex = currentFromStatus >= 0
        ? currentFromStatus
        : currentFromPending;
    final rejectedIndex = stages.indexWhere(
      (stage) => status == '${_stageCode(stage.reviewSlug)}_REJECTED',
    );
    final completed = status == 'APPROVED' || status == 'COMPLETED';
    final stopped = status.contains('CANCEL') || status.contains('WITHDRAW');

    if (stages.isEmpty) return const SizedBox.shrink();

    return SectionCard(
      title: 'Tiến trình phê duyệt',
      icon: Icons.account_tree_outlined,
      accentColor: AppColors.info,
      child: Column(
        children: [
          for (var index = 0; index < stages.length; index++) ...[
            _ApprovalStepRow(
              stage: stages[index],
              raw: raw,
              state: _stepState(
                index: index,
                currentIndex: currentIndex,
                rejectedIndex: rejectedIndex,
                completed: completed,
                stopped: stopped,
                hasEvidence: _stageHasEvidence(raw, stages[index]),
              ),
            ),
            if (index != stages.length - 1)
              const Divider(height: AppSpacing.lg),
          ],
        ],
      ),
    );
  }

  static List<RequestReviewStage> _displayStages(
    RequestTypeConfig config,
    Map<String, dynamic> raw,
  ) {
    final status = (raw['status'] as String? ?? '').toUpperCase();
    final nursingTouched = status.contains('NURSING_HEAD') ||
        raw['nursingHeadReviewedAt'] != null;
    final showNursing =
        nursingTouched || isNursingBlockTitle(raw['positionTitle'] as String?);

    final isMainDuty = config.key == 'main-duty-authorization';
    final hrTouched =
        status.contains('_HR') ||
        status.startsWith('HR_') ||
        raw['hrReviewedAt'] != null;
    final headTouched = raw['headReviewedAt'] != null ||
        status == 'PENDING_HEAD' ||
        status == 'HEAD_REJECTED';

    return [
      for (final stage in config.stages)
        if (isNursingHeadStageLabel(stage.label))
          ...[if (showNursing) stage]
        else if (isMainDuty && stage.reviewSlug == 'hr-review')
          // Web: trực chính không qua HCNS; chỉ hiện nếu đơn thực sự đã qua.
          ...[if (hrTouched) stage]
        else if (isMainDuty &&
            showNursing &&
            stage.reviewSlug == 'head-review')
          // Khối ĐD: thường lập sẵn bởi trưởng khoa — hiện khi đã có dấu vết.
          ...[if (headTouched) stage]
        else
          stage,
    ];
  }
}

class _ApprovalStepRow extends StatelessWidget {
  const _ApprovalStepRow({
    required this.stage,
    required this.raw,
    required this.state,
  });

  final RequestReviewStage stage;
  final Map<String, dynamic> raw;
  final _ProcessStepState state;

  @override
  Widget build(BuildContext context) {
    final prefix = _stagePrefix(stage.reviewSlug);
    final comment = raw['${prefix}Comment']?.toString().trim();
    final reviewedAt = raw['${prefix}ReviewedAt']?.toString();
    final reviewer = raw['${prefix}ReviewerUsername']?.toString().trim();
    final signature =
        raw['${prefix}SignatureUrl']?.toString().trim() ??
        raw['${prefix}SignaturePath']?.toString().trim();
    final color = _stepColor(state);
    final statusText = _stepLabel(state, signature?.isNotEmpty ?? false);

    return Semantics(
      container: true,
      label:
          '${stage.label}. $statusText'
          '${comment == null || comment.isEmpty ? '' : '. Ý kiến: $comment'}',
      child: ExcludeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(color: color.withValues(alpha: 0.25)),
              ),
              child: Icon(_stepIcon(state), size: 18, color: color),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stage.label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 11.8,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                  if ((reviewer != null && reviewer.isNotEmpty) ||
                      (reviewedAt != null && reviewedAt.isNotEmpty)) ...[
                    const SizedBox(height: 3),
                    Text(
                      [
                        if (reviewer != null && reviewer.isNotEmpty) reviewer,
                        if (reviewedAt != null && reviewedAt.isNotEmpty)
                          AppFormat.dateTime(DateTime.tryParse(reviewedAt)),
                      ].join(' · '),
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                  if (signature != null && signature.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Material(
                      color: Colors.white,
                      borderRadius: AppRadius.brXs,
                      child: InkWell(
                        onTap: () => showAuthImagePreview(
                          context,
                          url: AppConfig.resolveUrl(signature),
                          title: stage.label,
                        ),
                        borderRadius: AppRadius.brXs,
                        child: Container(
                          width: double.infinity,
                          height: 64,
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            borderRadius: AppRadius.brXs,
                            border: Border.all(color: AppColors.borderSoft),
                          ),
                          child: AuthNetworkImage(
                            url: AppConfig.resolveUrl(signature),
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (comment != null && comment.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xs,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMuted,
                        borderRadius: AppRadius.brXs,
                      ),
                      child: Text(
                        comment,
                        style: const TextStyle(fontSize: 12, height: 1.4),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

_ProcessStepState _stepState({
  required int index,
  required int currentIndex,
  required int rejectedIndex,
  required bool completed,
  required bool stopped,
  required bool hasEvidence,
}) {
  if (rejectedIndex >= 0) {
    if (index < rejectedIndex) return _ProcessStepState.completed;
    if (index == rejectedIndex) return _ProcessStepState.rejected;
    return _ProcessStepState.stopped;
  }
  if (completed) return _ProcessStepState.completed;
  if (currentIndex >= 0) {
    if (index < currentIndex) return _ProcessStepState.completed;
    if (index == currentIndex) return _ProcessStepState.current;
    return _ProcessStepState.upcoming;
  }
  if (stopped) {
    return hasEvidence
        ? _ProcessStepState.completed
        : _ProcessStepState.stopped;
  }
  return hasEvidence ? _ProcessStepState.completed : _ProcessStepState.upcoming;
}

bool _stageHasEvidence(Map<String, dynamic> raw, RequestReviewStage stage) {
  final prefix = _stagePrefix(stage.reviewSlug);
  return [
    raw['${prefix}ReviewedAt'],
    raw['${prefix}ReviewerUsername'],
    raw['${prefix}SignatureUrl'],
    raw['${prefix}SignaturePath'],
  ].any((value) => value != null && value.toString().trim().isNotEmpty);
}

String _stepLabel(_ProcessStepState state, bool hasSignature) {
  return switch (state) {
    _ProcessStepState.completed =>
      hasSignature ? 'Đã duyệt và ký' : 'Đã hoàn tất bước',
    _ProcessStepState.current => 'Đang chờ duyệt',
    _ProcessStepState.rejected => 'Đã từ chối',
    _ProcessStepState.upcoming => 'Chưa đến bước',
    _ProcessStepState.stopped => 'Quy trình đã dừng',
  };
}

Color _stepColor(_ProcessStepState state) {
  return switch (state) {
    _ProcessStepState.completed => AppColors.success,
    _ProcessStepState.current => AppColors.warning,
    _ProcessStepState.rejected => AppColors.error,
    _ProcessStepState.upcoming => AppColors.textTertiary,
    _ProcessStepState.stopped => AppColors.textSecondary,
  };
}

IconData _stepIcon(_ProcessStepState state) {
  return switch (state) {
    _ProcessStepState.completed => Icons.check_rounded,
    _ProcessStepState.current => Icons.schedule_rounded,
    _ProcessStepState.rejected => Icons.close_rounded,
    _ProcessStepState.upcoming => Icons.lock_outline_rounded,
    _ProcessStepState.stopped => Icons.block_rounded,
  };
}

String _stageCode(String reviewSlug) =>
    reviewSlug.replaceAll('-review', '').replaceAll('-', '_').toUpperCase();

/// 'nursing-head-review' → 'nursingHead' để tra key trong JSON.
String _stagePrefix(String reviewSlug) {
  final withoutReview = reviewSlug.replaceAll('-review', '');
  final parts = withoutReview.split('-');
  if (parts.length == 1) return parts.first;
  return parts.first +
      parts
          .sublist(1)
          .map(
            (part) => part.isEmpty
                ? ''
                : '${part[0].toUpperCase()}${part.substring(1)}',
          )
          .join();
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.busy,
    required this.onApprove,
    required this.onReject,
    required this.onCancel,
    this.onEdit,
  });

  final bool busy;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final VoidCallback? onCancel;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final edit = onEdit == null
        ? null
        : OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: BorderSide(
                color: AppColors.primary.withValues(alpha: 0.45),
              ),
            ),
            onPressed: busy ? null : onEdit,
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Chỉnh sửa'),
          );
    final cancel = onCancel == null
        ? null
        : OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: BorderSide(
                color: AppColors.error.withValues(alpha: 0.45),
              ),
            ),
            onPressed: busy ? null : onCancel,
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            label: const Text('Huỷ đơn'),
          );

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(top: BorderSide(color: AppColors.borderSoft)),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (busy)
              Semantics(
                liveRegion: true,
                label: 'Đang xử lý yêu cầu, vui lòng chờ',
                child: const LinearProgressIndicator(minHeight: 2),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                AppSpacing.sm,
                AppSpacing.page,
                AppSpacing.sm,
              ),
              child: Column(
                children: [
                  if (onApprove != null)
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final textScale = MediaQuery.textScalerOf(
                          context,
                        ).scale(1);
                        final stack =
                            constraints.maxWidth < 330 || textScale > 1.25;
                        final reject = OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side: BorderSide(
                              color: AppColors.error.withValues(alpha: 0.45),
                            ),
                          ),
                          onPressed: busy ? null : onReject,
                          icon: const Icon(Icons.close_rounded, size: 18),
                          label: const Text('Từ chối'),
                        );
                        final approve = ElevatedButton.icon(
                          onPressed: busy ? null : onApprove,
                          icon: const Icon(Icons.check_rounded, size: 18),
                          label: const Text('Duyệt'),
                        );
                        if (stack) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              approve,
                              const SizedBox(height: AppSpacing.xs),
                              reject,
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(child: reject),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(flex: 2, child: approve),
                          ],
                        );
                      },
                    ),
                  if (edit != null || cancel != null) ...[
                    if (onApprove != null) const SizedBox(height: AppSpacing.xs),
                    if (edit != null && cancel != null)
                      Row(
                        children: [
                          Expanded(child: edit),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(child: cancel),
                        ],
                      )
                    else if (cancel != null)
                      SizedBox(width: double.infinity, child: cancel)
                    else if (edit != null)
                      SizedBox(width: double.infinity, child: edit),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
