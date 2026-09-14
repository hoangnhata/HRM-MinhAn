import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/status_chip.dart';
import '../../../shared/models/workforce_report.dart';

/// Màu ổn định cho từng thứ hạng chức vụ — dùng chung giữa thanh phân bổ ở
/// thẻ tổng quan và danh sách chức vụ để người dùng nhận diện nhất quán.
Color workforceRoleColor(int index) =>
    AppColors.chartPalette[index % AppColors.chartPalette.length];

/// Viết tắt tên khoa/phòng (bỏ tiền tố "Khoa", "Phòng", "Ban", "Tổ"…).
String workforceDeptInitials(String name) {
  const skip = {'khoa', 'phong', 'ban', 'to', 'trung', 'tam', 'bo', 'phan'};
  final words = name
      .trim()
      .split(RegExp(r'[\s\-_/]+'))
      .where((w) => w.isNotEmpty)
      .toList();
  if (words.isEmpty) return '?';
  final significant = [
    for (final w in words)
      if (!skip.contains(foldVi(w))) w,
  ];
  final source = significant.isEmpty ? words : significant;
  final buf = StringBuffer();
  for (final w in source.take(2)) {
    buf.write(w.characters.first.toUpperCase());
  }
  return buf.toString();
}

/// Tiêu đề section: icon nhỏ + tiêu đề + số lượng + chú thích bên phải.
class WorkforceSectionTitle extends StatelessWidget {
  const WorkforceSectionTitle({
    super.key,
    required this.title,
    required this.count,
    required this.icon,
    this.trailing,
    this.color = AppColors.primary,
    this.action,
  });

  final String title;
  final int count;
  final IconData icon;
  final String? trailing;
  final Color color;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: AppRadius.brXs,
            ),
            child: Icon(icon, size: 15, color: color),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Flexible(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.style(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '$count',
                  style: AppTypography.style(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textTertiary,
                    tabular: true,
                  ),
                ),
              ],
            ),
          ),
          if (action != null)
            action!
          else if (trailing != null)
            Text(
              trailing!,
              style: AppTypography.style(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                tabular: true,
              ),
            ),
        ],
      ),
    );
  }
}

/// Thẻ nhóm danh sách — nền trắng, viền mảnh, bóng nhẹ, divider thụt lề.
class WorkforceGroupCard extends StatelessWidget {
  const WorkforceGroupCard({
    super.key,
    required this.children,
    this.dividerIndent = 16,
  });

  final List<Widget> children;
  final double dividerIndent;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.brCard,
        border: Border.all(color: AppColors.borderSoft),
        boxShadow: AppShadows.soft,
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0)
                Padding(
                  padding: EdgeInsets.only(left: dividerIndent),
                  child: const Divider(
                    height: 1,
                    thickness: 1,
                    color: AppColors.divider,
                  ),
                ),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}

/// Huy hiệu chữ viết tắt (thay icon lặp lại trong danh sách khoa/phòng).
class WorkforceInitialsBadge extends StatelessWidget {
  const WorkforceInitialsBadge({
    super.key,
    required this.text,
    required this.color,
    this.size = 42,
  });

  final String text;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.16),
            color.withValues(alpha: 0.07),
          ],
        ),
        borderRadius: BorderRadius.circular(size * 0.31),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: AppTypography.style(
          fontSize: size * 0.31,
          fontWeight: FontWeight.w800,
          color: Color.lerp(color, AppColors.textPrimary, 0.25),
          letterSpacing: -0.2,
        ),
      ),
    );
  }
}

/// Hàng chức vụ: chấm màu theo thứ hạng + số + % + thanh tỉ lệ.
class WorkforceRoleTile extends StatelessWidget {
  const WorkforceRoleTile({
    super.key,
    required this.index,
    required this.label,
    required this.count,
    required this.total,
    this.selected = false,
    this.onTap,
  });

  final int index;
  final String label;
  final int count;
  final int total;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = workforceRoleColor(index);
    final share = total <= 0 ? 0.0 : (count / total).clamp(0.0, 1.0);
    final pct = (share * 100).round();

    final body = Padding(
      padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.35),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.style(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.15,
                    color: selected
                        ? AppColors.primaryDark
                        : AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                AppFormat.number(count),
                style: AppTypography.metric(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(
                width: 42,
                child: Text(
                  '$pct%',
                  textAlign: TextAlign.right,
                  style: AppTypography.style(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textTertiary,
                    tabular: true,
                  ),
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 6),
                AnimatedRotation(
                  turns: selected ? 0.25 : 0,
                  duration: AppDurations.fast,
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: selected ? AppColors.primary : AppColors.textTertiary,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 9),
          Padding(
            padding: const EdgeInsets.only(left: 20),
            child: ClipRRect(
              borderRadius: AppRadius.brPill,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: share),
                duration: AppDurations.slow,
                curve: Curves.easeOutCubic,
                builder: (context, v, _) => LinearProgressIndicator(
                  value: v,
                  minHeight: 5,
                  color: color,
                  backgroundColor: color.withValues(alpha: 0.1),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return body;
    return Semantics(
      button: true,
      selected: selected,
      label: '$label, $count người, $pct%',
      child: Material(
        color: selected
            ? AppColors.primary.withValues(alpha: 0.06)
            : Colors.transparent,
        child: InkWell(onTap: onTap, child: body),
      ),
    );
  }
}

/// Hàng nhân sự trong danh sách (kết quả tìm kiếm / chi tiết khoa).
class WorkforcePersonTile extends StatelessWidget {
  const WorkforcePersonTile({
    super.key,
    required this.row,
    required this.daily,
    this.showDepartment = true,
  });

  final WorkforceDetailRow row;
  final bool daily;
  final bool showDepartment;

  @override
  Widget build(BuildContext context) {
    final statusColor = daily
        ? (row.attendanceStatus == 'PRESENT'
            ? AppColors.success
            : AppColors.warning)
        : (row.employeeStatus == 'ACTIVE'
            ? AppColors.success
            : AppColors.warning);
    final meta = [
      if (row.employeeCode.isNotEmpty) row.employeeCode,
      if (row.positionTitle.isNotEmpty) row.positionTitle,
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppAvatar(name: row.fullName, size: 42, showShadow: false),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.style(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.15,
                        height: 1.25,
                      ),
                    ),
                    if (meta.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.style(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                          height: 1.3,
                        ),
                      ),
                    ],
                    if (showDepartment && row.departmentName.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(
                            Icons.apartment_rounded,
                            size: 12,
                            color: AppColors.textTertiary,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              row.departmentName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.style(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textTertiary,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 6,
                      runSpacing: 5,
                      children: [
                        StatusChip(
                          label: daily
                              ? row.attendanceStatusLabel
                              : row.employeeStatusLabel,
                          color: statusColor,
                          dense: true,
                        ),
                        if (row.categoryLabel.isNotEmpty)
                          StatusChip(
                            label: row.categoryLabel,
                            color: AppColors.primary,
                            dense: true,
                            showDot: false,
                          ),
                        if (daily && row.lateMinutes > 0)
                          StatusChip(
                            label: 'Muộn ${row.lateMinutes}’',
                            color: AppColors.warning,
                            dense: true,
                            showDot: false,
                            icon: Icons.schedule_rounded,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (daily) ...[
            const SizedBox(height: 10),
            _PunchBar(row: row),
          ],
        ],
      ),
    );
  }
}

class _PunchBar extends StatelessWidget {
  const _PunchBar({required this.row});
  final WorkforceDetailRow row;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: AppRadius.brBase,
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Row(
        children: [
          Expanded(
            child: _PunchCol(
              label: 'Vào',
              value: row.displayCheckIn,
              icon: Icons.login_rounded,
            ),
          ),
          Container(
            width: 1,
            height: 26,
            color: AppColors.divider,
          ),
          Expanded(
            child: _PunchCol(
              label: 'Ra',
              value: row.displayCheckOut,
              icon: Icons.logout_rounded,
              padLeft: 12,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: AppRadius.brPill,
            ),
            child: Text(
              '${AppFormat.workUnits(row.workUnits)} công',
              style: AppTypography.style(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: AppColors.primaryDark,
                tabular: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PunchCol extends StatelessWidget {
  const _PunchCol({
    required this.label,
    required this.value,
    required this.icon,
    this.padLeft = 0,
  });

  final String label;
  final String value;
  final IconData icon;
  final double padLeft;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: padLeft),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.textTertiary),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: AppTypography.style(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: AppColors.textTertiary,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: AppTypography.metric(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Bỏ dấu tiếng Việt + hạ chữ thường để tìm kiếm không phân biệt dấu.
String foldVi(String raw) {
  const map = {
    'à': 'a', 'á': 'a', 'ạ': 'a', 'ả': 'a', 'ã': 'a',
    'â': 'a', 'ầ': 'a', 'ấ': 'a', 'ậ': 'a', 'ẩ': 'a', 'ẫ': 'a',
    'ă': 'a', 'ằ': 'a', 'ắ': 'a', 'ặ': 'a', 'ẳ': 'a', 'ẵ': 'a',
    'è': 'e', 'é': 'e', 'ẹ': 'e', 'ẻ': 'e', 'ẽ': 'e',
    'ê': 'e', 'ề': 'e', 'ế': 'e', 'ệ': 'e', 'ể': 'e', 'ễ': 'e',
    'ì': 'i', 'í': 'i', 'ị': 'i', 'ỉ': 'i', 'ĩ': 'i',
    'ò': 'o', 'ó': 'o', 'ọ': 'o', 'ỏ': 'o', 'õ': 'o',
    'ô': 'o', 'ồ': 'o', 'ố': 'o', 'ộ': 'o', 'ổ': 'o', 'ỗ': 'o',
    'ơ': 'o', 'ờ': 'o', 'ớ': 'o', 'ợ': 'o', 'ở': 'o', 'ỡ': 'o',
    'ù': 'u', 'ú': 'u', 'ụ': 'u', 'ủ': 'u', 'ũ': 'u',
    'ư': 'u', 'ừ': 'u', 'ứ': 'u', 'ự': 'u', 'ử': 'u', 'ữ': 'u',
    'ỳ': 'y', 'ý': 'y', 'ỵ': 'y', 'ỷ': 'y', 'ỹ': 'y',
    'đ': 'd',
  };
  final lower = raw.toLowerCase();
  final buf = StringBuffer();
  for (final rune in lower.runes) {
    final ch = String.fromCharCode(rune);
    buf.write(map[ch] ?? ch);
  }
  return buf.toString();
}
