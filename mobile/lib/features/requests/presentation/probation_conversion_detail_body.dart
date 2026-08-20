import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/status_chip.dart';

/// Nội dung chi tiết đơn lên chính thức — bố cục mobile, dữ liệu đồng bộ API web.
class ProbationConversionDetailBody extends StatelessWidget {
  const ProbationConversionDetailBody({
    super.key,
    required this.raw,
    this.status,
    this.stageLabel,
    this.bottom,
  });

  final Map<String, dynamic> raw;
  final String? status;
  final String? stageLabel;
  final Widget? bottom;

  static const _scoreLabels = <String, String>{
    'knowledge': 'Kiến thức chuyên môn',
    'clinical': 'Kỹ năng lâm sàng & thực hành',
    'admin': 'Nghiệp vụ hành chính',
    'attitude': 'Thái độ - đạo đức',
    'learning': 'Học tập & phát triển',
    'effectiveness': 'Hiệu quả công việc',
    'practice': 'Kỹ năng thực hành',
    'teamwork': 'Phối hợp & học tập',
  };

  static const _hrProposalLabels = <String, String>{
    'KY_HD': 'Ký HĐ chính thức',
    'GIA_HAN': 'Gia hạn thử việc',
    'NGUNG': 'Ngừng hợp tác',
  };

  static String employeeStatusLabel(String? raw) {
    return switch ((raw ?? '').toUpperCase()) {
      'INTERN' => 'Thực tập',
      'PROBATION' => 'Thử việc',
      'ACTIVE' => 'Chính thức',
      'RESIGNED' || 'LEFT' => 'Đã nghỉ',
      _ => (raw == null || raw.isEmpty) ? '—' : raw,
    };
  }

  static int criterionMax(String formType, String code) {
    if (formType == 'DOCTOR') return 5;
    return switch (code) {
      'knowledge' => 30,
      'practice' => 40,
      'attitude' => 20,
      'teamwork' => 10,
      _ => 0,
    };
  }

  static Map<String, num> parseScores(dynamic scoresJson) {
    if (scoresJson == null) return const {};
    try {
      final decoded = scoresJson is String
          ? jsonDecode(scoresJson)
          : scoresJson;
      if (decoded is! Map) return const {};
      final out = <String, num>{};
      for (final e in decoded.entries) {
        final v = e.value;
        if (v is num) out[e.key.toString()] = v;
      }
      return out;
    } catch (_) {
      return const {};
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = (raw['employeeName'] as String?)?.trim() ?? '—';
    final code = (raw['employeeCode'] as String?)?.trim();
    final department =
        (raw['departmentName'] as String?)?.trim() ??
        (raw['department'] as String?)?.trim();
    final position = (raw['positionTitle'] as String?)?.trim();
    final formType = (raw['formType'] as String?)?.trim().toUpperCase() ?? 'STAFF';
    final formLabel =
        (raw['formTypeLabel'] as String?)?.trim() ??
        switch (formType) {
          'DOCTOR' => 'Bác sĩ',
          'NURSE' => 'Điều dưỡng',
          _ => 'Nhân viên',
        };
    final officialDate = DateTime.tryParse(
      raw['officialDate']?.toString() ?? '',
    );
    final createdAt = DateTime.tryParse(raw['createdAt']?.toString() ?? '');
    final reason = (raw['reason'] as String?)?.trim();
    final requester = (raw['requestedByUsername'] as String?)?.trim();
    final requiresScoring = raw['requiresScoring'] as bool? ?? false;
    final scores = parseScores(raw['scoresJson'] ?? raw['scores']);
    final total = (raw['totalScore'] as num?)?.toDouble();
    final maxScore = (raw['maxScore'] as num?)?.toDouble();
    final grade = (raw['gradeLabel'] as String?)?.trim();
    final hrProposal = (raw['hrProposal'] as String?)?.trim();

    final mentor = (raw['mentorComment'] as String?)?.trim();
    final headDept = (raw['headDeptComment'] as String?)?.trim();
    final wardNurse = (raw['wardNurseHeadComment'] as String?)?.trim();
    final hospitalNurse = (raw['hospitalNurseHeadComment'] as String?)?.trim();
    final hasComments = [
      mentor,
      headDept,
      wardNurse,
      hospitalNurse,
    ].any((c) => c != null && c.isNotEmpty);

    final scored = requiresScoring || scores.isNotEmpty || total != null;
    final gradeColor = _gradeColor(grade);

    return ListView(
      padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.xl),
      children: [
        Padding(
          padding: AppSpacing.pageH,
          child: AppCard(
            accentColor: AppColors.success,
            gradient: AppGradients.tint(AppColors.success),
            borderRadius: AppRadius.brCard,
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppIconBadge(
                      icon: Icons.badge_outlined,
                      color: AppColors.success,
                      size: 46,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: AppTypography.style(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w800,
                              height: 1.2,
                            ),
                          ),
                          if (code != null && code.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              code,
                              style: AppTypography.style(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                          if (position != null && position.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              position,
                              style: AppTypography.style(
                                fontSize: 12.5,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (status != null && status!.isNotEmpty)
                      StatusChip(
                        label: _statusLabel(status!),
                        color: _statusColor(status!),
                        dense: true,
                      ),
                    StatusChip(
                      label: 'Mẫu $formLabel',
                      color: AppColors.info,
                      dense: true,
                      showDot: false,
                    ),
                    if (officialDate != null)
                      StatusChip(
                        label: 'Ngày ${AppFormat.date(officialDate)}',
                        color: AppColors.textSecondary,
                        dense: true,
                        showDot: false,
                      ),
                  ],
                ),
                if (stageLabel != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.1),
                      borderRadius: AppRadius.brSm,
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
                            'Đang chờ bạn duyệt: $stageLabel',
                            style: AppTypography.style(
                              fontSize: 12,
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
        const SizedBox(height: 10),
        Padding(
          padding: AppSpacing.pageH,
          child: _Section(
            title: 'Thông tin nhân viên',
            icon: Icons.person_outline_rounded,
            child: Column(
              children: [
                _KV(label: 'Họ tên', value: name),
                if (code != null) _KV(label: 'Mã nhân viên', value: code),
                if (department != null && department.isNotEmpty)
                  _KV(label: 'Phòng ban', value: department),
                if (position != null && position.isNotEmpty)
                  _KV(label: 'Vị trí', value: position),
                _KV(
                  label: 'Trạng thái hiện tại',
                  value: employeeStatusLabel(
                    raw['employeeStatus']?.toString(),
                  ),
                ),
                _KV(label: 'Mẫu đơn', value: formLabel),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: AppSpacing.pageH,
          child: _Section(
            title: 'Nội dung đề nghị',
            icon: Icons.description_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (officialDate != null)
                  _KV(
                    label: 'Ngày lên chính thức',
                    value: AppFormat.date(officialDate),
                  ),
                if (requester != null && requester.isNotEmpty)
                  _KV(label: 'Người lập đơn', value: requester),
                if (createdAt != null)
                  _KV(
                    label: 'Ngày gửi',
                    value: AppFormat.dateTime(createdAt),
                  ),
                if (reason != null && reason.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Lý do / nội dung',
                    style: AppTypography.style(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      borderRadius: AppRadius.brSm,
                    ),
                    child: Text(
                      reason,
                      style: AppTypography.style(
                        fontSize: 13.5,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (scored) ...[
          const SizedBox(height: 10),
          Padding(
            padding: AppSpacing.pageH,
            child: _Section(
              title: 'Phiếu đánh giá năng lực',
              icon: Icons.fact_check_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: AppRadius.brMd,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          gradeColor,
                          gradeColor.withValues(alpha: 0.78),
                        ],
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.16),
                            borderRadius: AppRadius.brSm,
                          ),
                          child: const Icon(
                            Icons.military_tech_outlined,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'TỔNG KẾT ĐÁNH GIÁ',
                                style: AppTypography.style(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white.withValues(alpha: 0.85),
                                  letterSpacing: 0.4,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: total != null
                                          ? AppFormat.compactNumber(total)
                                          : '—',
                                      style: AppTypography.style(
                                        fontSize: 26,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                        height: 1.1,
                                      ),
                                    ),
                                    TextSpan(
                                      text:
                                          ' / ${maxScore != null ? AppFormat.compactNumber(maxScore) : '—'} điểm',
                                      style: AppTypography.style(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white.withValues(
                                          alpha: 0.85,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.16),
                            borderRadius: AppRadius.brSm,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.22),
                            ),
                          ),
                          child: Text(
                            grade == null || grade.isEmpty
                                ? 'Chưa xếp loại'
                                : 'Xếp loại $grade',
                            style: AppTypography.style(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (scores.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    for (final e in scores.entries) ...[
                      _ScoreRow(
                        label: _scoreLabels[e.key] ?? e.key,
                        score: e.value.toDouble(),
                        max: criterionMax(formType, e.key).toDouble(),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                  if (hasComments) ...[
                    Text(
                      'Nhận xét chuyên môn',
                      style: AppTypography.style(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (mentor != null && mentor.isNotEmpty)
                      _CommentBox(
                        label: 'Ý kiến người hướng dẫn',
                        value: mentor,
                      ),
                    if (headDept != null && headDept.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _CommentBox(
                        label: formType == 'STAFF'
                            ? 'Đánh giá Trưởng khoa/phòng'
                            : 'Đánh giá Trưởng khoa',
                        value: headDept,
                      ),
                    ],
                    if (wardNurse != null && wardNurse.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _CommentBox(
                        label: 'Ý kiến ĐD trưởng khoa',
                        value: wardNurse,
                      ),
                    ],
                    if (hospitalNurse != null && hospitalNurse.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _CommentBox(
                        label: 'Ý kiến Trưởng phòng ĐD',
                        value: hospitalNurse,
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ],
        if (hrProposal != null && hrProposal.isNotEmpty) ...[
          const SizedBox(height: 10),
          Padding(
            padding: AppSpacing.pageH,
            child: _Section(
              title: 'Đề xuất HCNS',
              icon: Icons.handshake_outlined,
              child: _KV(
                label: 'Phương án',
                value: _hrProposalLabels[hrProposal] ?? hrProposal,
              ),
            ),
          ),
        ],
        if (bottom != null) ...[
          const SizedBox(height: 10),
          bottom!,
        ],
      ],
    );
  }

  static Color _gradeColor(String? grade) {
    final g = (grade ?? '').toLowerCase();
    if (g.contains('xuất sắc') || g.contains('giỏi')) return const Color(0xFF15803D);
    if (g.contains('khá')) return const Color(0xFF0F766E);
    if (g.contains('trung bình')) return AppColors.warning;
    if (g.contains('yếu') || g.contains('kém')) return AppColors.error;
    return AppColors.success;
  }

  static String _statusLabel(String status) {
    const labels = <String, String>{
      'PENDING_NURSING_HEAD': 'Chờ Trưởng phòng Điều dưỡng',
      'NURSING_HEAD_REJECTED': 'Trưởng phòng ĐD từ chối',
      'PENDING_HR': 'Chờ HCNS duyệt',
      'PENDING_DIRECTOR': 'Chờ Giám đốc duyệt',
      'HR_REJECTED': 'HCNS từ chối',
      'HR_EXTEND_PROBATION': 'HCNS đề xuất gia hạn thử việc',
      'HR_STOP_COOPERATION': 'HCNS đề xuất ngừng hợp tác',
      'DIRECTOR_REJECTED': 'Giám đốc từ chối',
      'APPROVED': 'Đã duyệt — chờ ngày lên chính thức',
      'APPLIED': 'Đã lên chính thức',
      'CANCELLED': 'Đã huỷ',
    };
    return labels[status.toUpperCase()] ?? status;
  }

  static Color _statusColor(String status) {
    final s = status.toUpperCase();
    if (s == 'APPLIED' || s == 'APPROVED') return AppColors.success;
    if (s.contains('REJECT') || s.contains('STOP') || s == 'CANCELLED') {
      return AppColors.error;
    }
    if (s.contains('PENDING') || s.contains('EXTEND')) return AppColors.warning;
    return AppColors.textSecondary;
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.brCard,
        border: Border.all(color: AppColors.borderSoft),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 17, color: AppColors.success),
              const SizedBox(width: 8),
              Text(
                title,
                style: AppTypography.style(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _KV extends StatelessWidget {
  const _KV({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(
              label,
              style: AppTypography.style(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textTertiary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: AppTypography.style(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreRow extends StatelessWidget {
  const _ScoreRow({
    required this.label,
    required this.score,
    required this.max,
  });

  final String label;
  final double score;
  final double max;

  @override
  Widget build(BuildContext context) {
    final ratio = max <= 0 ? 0.0 : (score / max).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: AppTypography.style(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              '${AppFormat.compactNumber(score)} / ${AppFormat.compactNumber(max)}',
              style: AppTypography.style(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: AppRadius.brPill,
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 6,
            backgroundColor: AppColors.primary.withValues(alpha: 0.08),
            valueColor: const AlwaysStoppedAnimation(Color(0xFF0F766E)),
          ),
        ),
      ],
    );
  }
}

class _CommentBox extends StatelessWidget {
  const _CommentBox({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.05),
        borderRadius: AppRadius.brSm,
        border: Border.all(color: AppColors.success.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: AppTypography.style(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTypography.style(
              fontSize: 13,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
