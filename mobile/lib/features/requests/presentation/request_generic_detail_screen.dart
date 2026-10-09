import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/nursing_block.dart';
import '../../../core/utils/request_edit_access.dart';
import '../../../core/utils/user_role.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/approval_action_bar.dart';
import '../../../core/widgets/auth_image_preview.dart';
import '../../../core/widgets/auth_network_image.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/highlight_pulse.dart';
import '../../../core/widgets/info_row.dart';
import '../../../core/widgets/status_chip.dart';
import '../../../core/widgets/tinted_card_backdrop.dart';
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

    final stage = item.stage;
    if (stage == null) return;
    if (approved) {
      if (stage.approveFields.isNotEmpty) {
        // Một số bước duyệt yêu cầu nhập thêm dữ liệu (backend chặn nếu thiếu).
        final input = await showApprovalFieldsSheet(
          context,
          stage: stage,
          title: 'Duyệt ở bước ${stage.label}',
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
      HapticFeedback.mediumImpact();
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

  /// Giám đốc sửa quyết định phiếu hội thảo đã xử lý (có công / không công / từ chối).
  Future<void> _correctSeminar(
    Map<String, dynamic> raw,
    RequestReviewStage stage,
  ) async {
    final input = await showSeminarDecisionSheet(context, raw: raw);
    if (input == null || !mounted) return;

    setState(() => _busy = true);
    final ok = await ref
        .read(genericRequestControllerProvider(widget.typeKey).notifier)
        .review(
          PendingItem(raw: raw, stage: stage),
          approved: input.approved,
          comment: input.comment,
          extra: input.extra,
        );
    if (!mounted) return;
    setState(() => _busy = false);

    if (ok) {
      HapticFeedback.mediumImpact();
      showAppSnackBar(context, 'Đã cập nhật quyết định', isSuccess: true);
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

  /// Bước duyệt Giám đốc cho phép sửa lại phiếu hội thảo — null nếu không áp dụng.
  RequestReviewStage? _seminarCorrectionStage(
    RequestTypeConfig config,
    Map<String, dynamic> raw,
    String? status,
    UserRole role,
    bool directorApprovalEnabled,
  ) {
    if (widget.typeKey != 'seminar-proposal') return null;
    const processed = {'APPROVED', 'COMPLETED', 'DIRECTOR_REJECTED'};
    if (!processed.contains(status) || raw['directorReviewedAt'] == null) {
      return null;
    }
    final stages = config
        .stagesFor(role, directorApprovalEnabled: directorApprovalEnabled)
        .where((s) => s.reviewSlug == 'director-review')
        .toList();
    return stages.isEmpty ? null : stages.first;
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
        body: Column(
          children: [
            AppScreenHeader(
              dense: true,
              title: config.label,
              icon: Icons.assignment_outlined,
              eyebrow: 'Đơn từ',
              onBack: () => context.pop(),
            ),
            Expanded(
              child: loading
                  ? const LoadingState(label: 'Đang tải đơn...')
                  : state.error != null
                  ? ErrorState(message: state.error!, onRetry: _retryFetch)
                  : EmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'Không tìm thấy đơn',
                      message:
                          'Đơn có thể đã bị huỷ hoặc bạn không còn quyền xem.',
                      action: OutlinedButton.icon(
                        onPressed: _retryFetch,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Tải lại'),
                      ),
                    ),
            ),
          ],
        ),
      );
    }

    final canActOnPending = pendingItem?.stage != null;
    final status = raw['status'] as String?;
    final correctionStage = canActOnPending
        ? null
        : _seminarCorrectionStage(
            config,
            raw,
            status,
            role,
            auth.currentUser?.directorApprovalEnabled ?? false,
          );
    final canCancel =
        config.canCancel(role) &&
        state.related.any(
          (r) => (r['id'] as num).toInt() == widget.requestId,
        ) &&
        (status?.toUpperCase().contains('PENDING') ?? false);
    final inOwnView = fromRelated || _fetched != null;
    final canEdit =
        inOwnView &&
        canEditOwnPendingRequest(
          raw,
          username: auth.currentUser?.username,
          role: role,
        );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          AppScreenHeader(
            dense: true,
            title: config.shortLabel,
            subtitle: config.label,
            icon: Icons.assignment_outlined,
            eyebrow: 'Đơn từ',
            onBack: () => context.pop(),
          ),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: HighlightPulse(
                    active: widget.highlight,
                    child: RefreshIndicator(
                      color: AppColors.primary,
                      onRefresh: () => ref
                          .read(
                            genericRequestControllerProvider(
                              widget.typeKey,
                            ).notifier,
                          )
                          .refreshQuietly(),
                      child: _Body(
                        config: config,
                        raw: raw,
                        status: status,
                        stageLabel: canActOnPending
                            ? pendingItem?.stage?.label
                            : null,
                        currentStage: canActOnPending
                            ? pendingItem?.stage
                            : null,
                      ),
                    ),
                  ),
                ),
                if (canActOnPending ||
                    correctionStage != null ||
                    canCancel ||
                    canEdit)
                  ApprovalActionBar(
                    busy: _busy,
                    onApprove: canActOnPending
                        ? () => _review(pendingItem!, true)
                        : correctionStage != null
                        ? () => _correctSeminar(raw!, correctionStage)
                        : null,
                    approveLabel: correctionStage != null
                        ? 'Sửa quyết định'
                        : 'Duyệt',
                    approveIcon: correctionStage != null
                        ? Icons.edit_note_rounded
                        : Icons.check_rounded,
                    onReject: canActOnPending
                        ? () => _review(pendingItem!, false)
                        : null,
                    onWithdraw: canCancel
                        ? () => _cancel(widget.requestId)
                        : null,
                    withdrawLabel: 'Huỷ đơn',
                    withdrawIcon: Icons.delete_outline_rounded,
                    onEdit: canEdit ? () => _edit(raw!) : null,
                  ),
              ],
            ),
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
        // Hội thảo tự dựng lịch sử duyệt kèm chữ ký người lập.
        bottom: config.key == 'seminar-proposal' ? null : timeline,
      );
    }

    final name =
        raw['employeeName'] as String? ??
        raw['fullName'] as String? ??
        'Đơn #${raw['id']}';
    final department =
        raw['departmentName'] as String? ?? raw['department'] as String?;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
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
                    TintedIconTile(
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
                            style: AppTypography.style(
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
                              style: AppTypography.style(
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
                            style: AppTypography.style(
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
      style: AppTypography.style(
        fontSize: 13.5,
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
                style: AppTypography.style(
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
              style: AppTypography.style(
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

    final states = [
      for (var index = 0; index < stages.length; index++)
        _stepState(
          index: index,
          currentIndex: currentIndex,
          rejectedIndex: rejectedIndex,
          completed: completed,
          stopped: stopped,
          hasEvidence: _stageHasEvidence(raw, stages[index]),
        ),
    ];

    return SectionCard(
      title: 'Lịch sử duyệt',
      icon: Icons.draw_outlined,
      accentColor: AppColors.info,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _RequesterSignatureRow(raw: raw, isLast: stages.isEmpty),
          for (var index = 0; index < stages.length; index++)
            _ApprovalStepRow(
              stage: stages[index],
              raw: raw,
              state: states[index],
              nextState: index + 1 < states.length ? states[index + 1] : null,
              isLast: index == stages.length - 1,
            ),
        ],
      ),
    );
  }

  static List<RequestReviewStage> _displayStages(
    RequestTypeConfig config,
    Map<String, dynamic> raw,
  ) {
    final status = (raw['status'] as String? ?? '').toUpperCase();
    final nursingTouched =
        status.contains('NURSING_HEAD') || raw['nursingHeadReviewedAt'] != null;
    final showNursing =
        nursingTouched ||
        isNursingBlockTitle(
          raw['positionTitle'] as String?,
          (raw['department'] ?? raw['departmentName']) as String?,
        );

    final isMainDuty = config.key == 'main-duty-authorization';
    final headTouched =
        raw['headReviewedAt'] != null ||
        status == 'PENDING_HEAD' ||
        status == 'HEAD_REJECTED';

    return [
      for (final stage in config.stages)
        if (isNursingHeadStageLabel(stage.label)) ...[
          if (showNursing) stage,
        ] else if (isMainDuty &&
            showNursing &&
            stage.reviewSlug == 'head-review')
        // Khối ĐD: thường lập sẵn bởi trưởng khoa — hiện khi đã có dấu vết.
        ...[
          if (headTouched) stage,
        ] else
          stage,
    ];
  }
}

/// Một mốc trên dòng thời gian duyệt: nút tròn + đường nối xuống mốc sau.
class _TimelineTile extends StatelessWidget {
  const _TimelineTile({
    required this.icon,
    required this.color,
    required this.filled,
    required this.isLast,
    required this.lineColor,
    required this.child,
  });

  final IconData icon;
  final Color color;

  /// Mốc đã qua / đang xử lý: nút đặc màu; mốc chưa tới: nút viền nhạt.
  final bool filled;
  final bool isLast;
  final Color lineColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 34,
            child: Column(
              children: [
                if (filled)
                  TintedIconTile(icon: icon, color: color, size: 34)
                else
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(34 * 0.3),
                      border: Border.all(
                        color: color.withValues(alpha: 0.35),
                        width: 1.4,
                      ),
                    ),
                    child: Icon(icon, size: 17, color: color),
                  ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: lineColor,
                        borderRadius: AppRadius.brPill,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 2 : 18),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

/// Khung ảnh chữ ký: nền giấy nhạt, nhãn nhỏ, chạm để phóng to.
class _SignatureBox extends StatelessWidget {
  const _SignatureBox({required this.url, required this.title});

  final String url;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceAlt,
      borderRadius: AppRadius.brControl,
      child: InkWell(
        onTap: () => showAuthImagePreview(
          context,
          url: AppConfig.resolveUrl(url),
          title: title,
        ),
        borderRadius: AppRadius.brControl,
        child: Container(
          width: double.infinity,
          height: 124,
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
          decoration: BoxDecoration(
            borderRadius: AppRadius.brControl,
            border: Border.all(color: AppColors.borderSoft),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: AuthNetworkImage(
                  url: AppConfig.resolveUrl(url),
                  fit: BoxFit.contain,
                ),
              ),
              Positioned(
                right: 0,
                top: 0,
                child: Icon(
                  Icons.zoom_out_map_rounded,
                  size: 14,
                  color: AppColors.textTertiary.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Viên trạng thái nhỏ cạnh tên bước.
class _StepPill extends StatelessWidget {
  const _StepPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(7, 2, 8, 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: AppRadius.brPill,
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        label,
        style: AppTypography.style(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          height: AppTypography.uppercaseHeight,
          color: Color.lerp(color, AppColors.textPrimary, 0.2)!,
        ),
      ),
    );
  }
}

class _RequesterSignatureRow extends StatelessWidget {
  const _RequesterSignatureRow({required this.raw, required this.isLast});

  final Map<String, dynamic> raw;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final name = raw['requestedByUsername']?.toString().trim();
    final signature = raw['requesterSignatureUrl']?.toString().trim();
    final createdAt = raw['createdAt']?.toString();
    final hasSignature = signature != null && signature.isNotEmpty;
    return _TimelineTile(
      icon: Icons.edit_document,
      color: AppColors.success,
      filled: true,
      isLast: isLast,
      lineColor: AppColors.success.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Người lập phiếu${name != null && name.isNotEmpty ? ' · $name' : ''}',
            style: AppTypography.style(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              height: 1.35,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _StepPill(
                label: hasSignature ? 'Đã ký khi gửi' : 'Chưa có chữ ký',
                color: hasSignature
                    ? AppColors.success
                    : AppColors.textSecondary,
              ),
              if (createdAt != null && createdAt.isNotEmpty)
                Text(
                  AppFormat.dateTime(DateTime.tryParse(createdAt)),
                  style: AppTypography.style(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textTertiary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (hasSignature)
            _SignatureBox(url: signature, title: 'Người lập phiếu')
          else
            Text(
              'Phiếu này chưa lưu chữ ký người lập.',
              style: AppTypography.style(
                fontSize: 12,
                height: 1.4,
                color: AppColors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }
}

class _ApprovalStepRow extends StatelessWidget {
  const _ApprovalStepRow({
    required this.stage,
    required this.raw,
    required this.state,
    required this.isLast,
    required this.nextState,
  });

  final RequestReviewStage stage;
  final Map<String, dynamic> raw;
  final _ProcessStepState state;
  final bool isLast;

  /// Trạng thái bước kế tiếp — quyết định màu đường nối.
  final _ProcessStepState? nextState;

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
    final filled =
        state == _ProcessStepState.completed ||
        state == _ProcessStepState.current ||
        state == _ProcessStepState.rejected;
    final lineDone =
        state == _ProcessStepState.completed &&
        nextState != null &&
        nextState != _ProcessStepState.upcoming &&
        nextState != _ProcessStepState.stopped;
    final hasComment = comment != null && comment.isNotEmpty;

    return Semantics(
      container: true,
      label:
          '${stage.label}. $statusText'
          '${hasComment ? '. Ý kiến: $comment' : ''}',
      child: ExcludeSemantics(
        child: _TimelineTile(
          icon: _stepIcon(state),
          color: color,
          filled: filled,
          isLast: isLast,
          lineColor: lineDone
              ? AppColors.success.withValues(alpha: 0.35)
              : AppColors.borderSoft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                stage.label,
                style: AppTypography.style(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  height: 1.35,
                  color: state == _ProcessStepState.upcoming
                      ? AppColors.textSecondary
                      : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _StepPill(label: statusText, color: color),
                  if ((reviewer != null && reviewer.isNotEmpty) ||
                      (reviewedAt != null && reviewedAt.isNotEmpty))
                    Text(
                      [
                        if (reviewer != null && reviewer.isNotEmpty) reviewer,
                        if (reviewedAt != null && reviewedAt.isNotEmpty)
                          AppFormat.dateTime(DateTime.tryParse(reviewedAt)),
                      ].join(' · '),
                      style: AppTypography.style(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textTertiary,
                      ),
                    ),
                ],
              ),
              if (signature != null && signature.isNotEmpty) ...[
                const SizedBox(height: 8),
                _SignatureBox(url: signature, title: stage.label),
              ],
              if (hasComment || state == _ProcessStepState.current) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
                  decoration: BoxDecoration(
                    color: hasComment
                        ? color.withValues(alpha: 0.06)
                        : AppColors.surfaceMuted,
                    borderRadius: AppRadius.brControl,
                    border: Border.all(
                      color: hasComment
                          ? color.withValues(alpha: 0.16)
                          : AppColors.borderSoft,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        hasComment
                            ? Icons.chat_bubble_outline_rounded
                            : Icons.hourglass_top_rounded,
                        size: 14,
                        color: hasComment ? color : AppColors.textTertiary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          hasComment ? comment : 'Đang chờ duyệt ký.',
                          style: AppTypography.style(
                            fontSize: 12.5,
                            height: 1.4,
                            fontWeight: hasComment
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: hasComment
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
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
