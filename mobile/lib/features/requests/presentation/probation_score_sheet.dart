import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';

class ProbationCriterion {
  const ProbationCriterion({
    required this.code,
    required this.label,
    required this.maxScore,
    this.detail,
  });

  final String code;
  final String label;
  final int maxScore;
  final String? detail;
}

/// Mẫu phiếu đồng bộ backend `ProbationEvaluationHelper` / web.
class ProbationScoreCatalog {
  static const doctor = <ProbationCriterion>[
    ProbationCriterion(
      code: 'knowledge',
      label: 'Kiến thức chuyên môn',
      maxScore: 5,
      detail:
          'Hiểu phác đồ điều trị, hướng dẫn BYT; nhận định, chẩn đoán ban đầu đúng; biết chỉ định cận lâm sàng hợp lý; hiểu được cơ bản về các thuốc thường dùng tại khoa phòng',
    ),
    ProbationCriterion(
      code: 'clinical',
      label: 'Kỹ năng lâm sàng & thực hành',
      maxScore: 5,
      detail:
          'Thăm khám, khai thác bệnh sử, biết đọc kết quả cận lâm sàng; thực hiện thủ thuật cơ bản (nếu có)',
    ),
    ProbationCriterion(
      code: 'admin',
      label: 'Nghiệp vụ hành chính',
      maxScore: 5,
      detail: 'Hoàn thiện hồ sơ bệnh án, kê đơn, báo cáo theo quy định',
    ),
    ProbationCriterion(
      code: 'attitude',
      label: 'Thái độ - đạo đức',
      maxScore: 5,
      detail:
          'Tôn trọng, cảm thông với bệnh nhân; trung thực, cầu thị, không giấu sai sót; tuân thủ quy định BV, quy chế chuyên môn; hợp tác tốt với đồng nghiệp',
    ),
    ProbationCriterion(
      code: 'learning',
      label: 'Học tập & phát triển',
      maxScore: 5,
      detail:
          'Tham gia CME, đào tạo nội bộ; chủ động cập nhật kiến thức, tiếp thu góp ý, tinh thần cầu tiến',
    ),
    ProbationCriterion(
      code: 'effectiveness',
      label: 'Hiệu quả công việc',
      maxScore: 5,
      detail:
          'Hoàn thành trực & công việc được giao; hạn chế sai sót, đảm bảo an toàn người bệnh; được NB và người nhà hài lòng',
    ),
  ];

  static const nurse = <ProbationCriterion>[
    ProbationCriterion(
      code: 'knowledge',
      label: 'Kiến thức chuyên môn',
      maxScore: 30,
      detail:
          'Nắm quy trình chăm sóc 5 bước; hiểu quy định an toàn người bệnh, KSNK; hiểu thuốc thường dùng và phản ứng phụ cơ bản; nắm kiến thức sơ cứu, cấp cứu ban đầu; nắm được phác đồ xử trí phản vệ, cấp cứu ban đầu',
    ),
    ProbationCriterion(
      code: 'practice',
      label: 'Kỹ năng thực hành',
      maxScore: 40,
      detail:
          'Thực hiện đúng các quy trình điều dưỡng cơ bản: đo sinh hiệu, ghi hồ sơ đầy đủ; thực hiện y lệnh chính xác; kỹ thuật cơ bản: tiêm truyền, thay băng, đặt sonde; sử dụng, bảo quản trang thiết bị y tế',
    ),
    ProbationCriterion(
      code: 'attitude',
      label: 'Thái độ - đạo đức',
      maxScore: 20,
      detail:
          'Tôn trọng, giao tiếp tốt với NB & thân nhân; tuân thủ quy chế chuyên môn, nội quy BV; tinh thần học hỏi, trung thực, không che giấu sai sót',
    ),
    ProbationCriterion(
      code: 'teamwork',
      label: 'Phối hợp & học tập',
      maxScore: 10,
      detail:
          'Hợp tác với đồng nghiệp, hỗ trợ kịp thời; chủ động xin ý kiến khi gặp tình huống khó; tham gia đào tạo nội bộ',
    ),
  ];

  static const staff = <ProbationCriterion>[
    ProbationCriterion(
      code: 'knowledge',
      label: 'Kiến thức chuyên môn',
      maxScore: 30,
      detail:
          'Hiểu các quy định, quy trình nội bộ liên quan đến công việc được giao; có kiến thức cơ bản về hoạt động kinh doanh dịch vụ y tế và chăm sóc khách hàng; hiểu nguyên tắc giao tiếp, tư vấn và làm việc với khách hàng/đối tác trong môi trường bệnh viện; nắm được các quy định chung về đạo đức nghề nghiệp, bảo mật thông tin và hình ảnh bệnh viện',
    ),
    ProbationCriterion(
      code: 'practice',
      label: 'Kỹ năng thực hành',
      maxScore: 40,
      detail:
          'Kỹ năng giao tiếp, tư vấn dịch vụ y tế cho khách hàng/đối tác; kỹ năng xây dựng, duy trì và phát triển mối quan hệ với đối tác (doanh nghiệp, bảo hiểm, phòng khám, cộng đồng); thực hiện công việc đúng quy trình, đúng kế hoạch được giao; kỹ năng tin học văn phòng; phối hợp triển khai các hoạt động truyền thông - marketing bệnh viện',
    ),
    ProbationCriterion(
      code: 'attitude',
      label: 'Thái độ - đạo đức',
      maxScore: 20,
      detail:
          'Thái độ chuẩn mực, lịch sự, tôn trọng người bệnh, khách hàng và đối tác; tuân thủ quy định bệnh viện, quy tắc ứng xử và bảo mật thông tin y tế; có ý thức trách nhiệm, chủ động trong công việc; giữ hình ảnh, uy tín và thương hiệu bệnh viện',
    ),
    ProbationCriterion(
      code: 'teamwork',
      label: 'Phối hợp & học tập',
      maxScore: 10,
      detail:
          'Hợp tác với đồng nghiệp, hỗ trợ kịp thời; chủ động học hỏi kiến thức y tế, dịch vụ mới, chính sách mới; tiếp thu góp ý, cải thiện hiệu quả công việc; tham gia đầy đủ các chương trình đào tạo nội bộ',
    ),
  ];

  static List<ProbationCriterion> of(String formType) {
    return switch (formType.toUpperCase()) {
      'DOCTOR' => doctor,
      'NURSE' => nurse,
      _ => staff,
    };
  }

  static int maxScoreOf(String formType) =>
      formType.toUpperCase() == 'DOCTOR' ? 30 : 100;

  static String formTypeLabel(String formType) => switch (formType.toUpperCase()) {
        'DOCTOR' => 'Bác sĩ',
        'NURSE' => 'Điều dưỡng',
        _ => 'Nhân viên',
      };

  static String gradeLabel(String formType, int total) {
    if (formType.toUpperCase() == 'DOCTOR') {
      if (total >= 27) return 'Tốt';
      if (total >= 21) return 'Khá';
      if (total >= 15) return 'Đạt yêu cầu';
      return 'Không đạt';
    }
    if (total >= 90) return 'Xuất sắc';
    if (total >= 75) return 'Khá';
    if (total >= 60) return 'Đạt yêu cầu';
    return 'Chưa đạt';
  }

  static String scaleHint(String formType) {
    if (formType.toUpperCase() == 'DOCTOR') {
      return 'Thang /30 · Tốt ≥27 · Khá ≥21 · Đạt ≥15';
    }
    return 'Thang /100 · Xuất sắc ≥90 · Khá ≥75 · Đạt ≥60';
  }

  static Color gradeColor(String grade) {
    if (grade == 'Tốt' || grade == 'Xuất sắc') return AppColors.success;
    if (grade == 'Khá' || grade == 'Đạt yêu cầu') return AppColors.info;
    return AppColors.warning;
  }

  static List<ProbationCriterion> fromApi(dynamic raw, String formType) {
    final parsed = <ProbationCriterion>[];
    if (raw is List) {
      for (final row in raw) {
        if (row is! Map) continue;
        final map = Map<String, dynamic>.from(row);
        final code = (map['code'] ?? '').toString().trim();
        if (code.isEmpty) continue;
        parsed.add(
          ProbationCriterion(
            code: code,
            label: (map['label'] ?? code).toString(),
            maxScore: (map['maxScore'] as num?)?.toInt() ??
                (map['max_score'] as num?)?.toInt() ??
                0,
            detail: (map['detail'] as String?)?.trim(),
          ),
        );
      }
    }
    if (parsed.isEmpty) return of(formType);
    return parsed;
  }
}

class ProbationScoreSheet extends StatelessWidget {
  const ProbationScoreSheet({
    super.key,
    required this.accent,
    required this.formType,
    required this.formLabel,
    required this.maxScore,
    required this.criteria,
    required this.scores,
    required this.onChanged,
  });

  final Color accent;
  final String formType;
  final String formLabel;
  final int maxScore;
  final List<ProbationCriterion> criteria;
  final Map<String, int> scores;
  final void Function(String code, int value) onChanged;

  int get _total =>
      criteria.fold(0, (sum, c) => sum + (scores[c.code] ?? 0));

  @override
  Widget build(BuildContext context) {
    final total = _total;
    final cap = maxScore <= 0 ? 1 : maxScore;
    final grade = ProbationScoreCatalog.gradeLabel(formType, total);
    final gradeColor = ProbationScoreCatalog.gradeColor(grade);
    final percent = (total / cap).clamp(0.0, 1.0);

    return AppCard(
      accentColor: accent,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: AppRadius.brSm,
                ),
                child: Icon(Icons.fact_check_outlined, size: 18, color: accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Phiếu đánh giá năng lực',
                      style: AppTypography.style(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Mẫu $formLabel · ${criteria.length} tiêu chí · kéo thanh hoặc nhập số',
                      style: AppTypography.style(
                        fontSize: 12,
                        height: 1.35,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            decoration: BoxDecoration(
              color: gradeColor.withValues(alpha: 0.08),
              borderRadius: AppRadius.brMd,
              border: Border.all(color: gradeColor.withValues(alpha: 0.28)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Kết quả dự kiến',
                        style: AppTypography.style(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: gradeColor,
                        borderRadius: AppRadius.brPill,
                      ),
                      child: Text(
                        grade,
                        style: AppTypography.style(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '$total / $maxScore',
                  style: AppTypography.style(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: gradeColor,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: AppRadius.brPill,
                  child: LinearProgressIndicator(
                    value: percent,
                    minHeight: 7,
                    backgroundColor: gradeColor.withValues(alpha: 0.14),
                    color: gradeColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  ProbationScoreCatalog.scaleHint(formType),
                  style: AppTypography.style(
                    fontSize: 11.5,
                    height: 1.3,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          for (final (i, c) in criteria.indexed) ...[
            if (i > 0) const SizedBox(height: 10),
            _CriterionTile(
              index: i + 1,
              criterion: c,
              value: scores[c.code] ?? 0,
              accent: accent,
              onChanged: (v) => onChanged(c.code, v),
            ),
          ],
        ],
      ),
    );
  }
}

class _CriterionTile extends StatefulWidget {
  const _CriterionTile({
    required this.index,
    required this.criterion,
    required this.value,
    required this.accent,
    required this.onChanged,
  });

  final int index;
  final ProbationCriterion criterion;
  final int value;
  final Color accent;
  final ValueChanged<int> onChanged;

  @override
  State<_CriterionTile> createState() => _CriterionTileState();
}

class _CriterionTileState extends State<_CriterionTile> {
  late final TextEditingController _controller;
  late final FocusNode _focus;
  bool _expanded = false;

  int get _max =>
      widget.criterion.maxScore <= 0 ? 1 : widget.criterion.maxScore;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '${widget.value}');
    _focus = FocusNode()..addListener(_onFocus);
  }

  @override
  void didUpdateWidget(covariant _CriterionTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && !_focus.hasFocus) {
      final next = '${widget.value}';
      if (_controller.text != next) _controller.text = next;
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocus() {
    if (_focus.hasFocus) {
      _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _controller.text.length,
      );
      return;
    }
    _commitText(_controller.text);
  }

  void _set(int raw) {
    final next = raw.clamp(0, _max);
    if (next == widget.value && _controller.text == '$next') return;
    _controller.text = '$next';
    widget.onChanged(next);
  }

  void _commitText(String raw) {
    final parsed = int.tryParse(raw.trim());
    _set(parsed ?? 0);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.criterion;
    final detail = (c.detail ?? '').trim();
    final longDetail = detail.length > 90;
    final value = widget.value.clamp(0, _max);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(11, 11, 11, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.brMd,
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: widget.accent.withValues(alpha: 0.12),
                  borderRadius: AppRadius.brSm,
                ),
                child: Text(
                  widget.index.toString().padLeft(2, '0'),
                  style: AppTypography.style(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: widget.accent,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.label,
                      style: AppTypography.style(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: widget.accent.withValues(alpha: 0.08),
                        borderRadius: AppRadius.brPill,
                      ),
                      child: Text(
                        'Tối đa ${c.maxScore}đ',
                        style: AppTypography.style(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: widget.accent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (detail.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              detail,
              maxLines: _expanded || !longDetail ? 12 : 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.style(
                fontSize: 12,
                height: 1.4,
                color: AppColors.textSecondary,
              ),
            ),
            if (longDetail)
              GestureDetector(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _expanded ? 'Thu gọn' : 'Xem đầy đủ',
                    style: AppTypography.style(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: widget.accent,
                    ),
                  ),
                ),
              ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              _StepButton(
                icon: Icons.remove_rounded,
                accent: widget.accent,
                enabled: value > 0,
                onTap: () => _set(value - 1),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 72,
                child: TextField(
                  controller: _controller,
                  focusNode: _focus,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(3),
                  ],
                  style: AppTypography.style(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    filled: true,
                    fillColor: AppColors.surfaceMuted,
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.brSm,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: AppRadius.brSm,
                      borderSide: const BorderSide(color: AppColors.borderSoft),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: AppRadius.brSm,
                      borderSide: BorderSide(color: widget.accent, width: 1.4),
                    ),
                  ),
                  onChanged: (raw) {
                    if (raw.isEmpty) return;
                    final n = int.tryParse(raw);
                    if (n == null) return;
                    if (n > _max) {
                      _set(_max);
                      return;
                    }
                    widget.onChanged(n.clamp(0, _max));
                  },
                  onSubmitted: _commitText,
                ),
              ),
              const SizedBox(width: 8),
              _StepButton(
                icon: Icons.add_rounded,
                accent: widget.accent,
                enabled: value < _max,
                onTap: () => _set(value + 1),
              ),
              const SizedBox(width: 8),
              Text(
                '/ ${c.maxScore}',
                style: AppTypography.style(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: widget.accent,
              thumbColor: widget.accent,
              overlayColor: widget.accent.withValues(alpha: 0.12),
              inactiveTrackColor: widget.accent.withValues(alpha: 0.16),
              trackHeight: 5,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            ),
            child: Slider(
              value: value.toDouble(),
              min: 0,
              max: _max.toDouble(),
              divisions: _max,
              label: '$value',
              onChanged: (v) => _set(v.round()),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.accent,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final Color accent;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: enabled
          ? accent.withValues(alpha: 0.12)
          : AppColors.surfaceMuted,
      borderRadius: AppRadius.brSm,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: AppRadius.brSm,
        child: SizedBox(
          width: 36,
          height: 40,
          child: Icon(
            icon,
            size: 18,
            color: enabled ? accent : AppColors.textTertiary,
          ),
        ),
      ),
    );
  }
}
