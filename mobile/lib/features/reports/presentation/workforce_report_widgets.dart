import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/tinted_card_backdrop.dart';
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

/// Tiêu đề section: ô icon đặc + tiêu đề + huy hiệu số lượng + gợi ý bên phải.
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
          TintedIconTile(icon: icon, color: color, size: 30),
          const SizedBox(width: 10),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.style(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                      color: AppColors.textPrimary,
                      height: AppTypography.uppercaseHeight,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  constraints: const BoxConstraints(minWidth: 24),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.10),
                    borderRadius: AppRadius.brPill,
                    border: Border.all(color: color.withValues(alpha: 0.18)),
                  ),
                  child: Text(
                    AppFormat.number(count),
                    textAlign: TextAlign.center,
                    style: AppTypography.display(
                      fontSize: 12,
                      color: Color.lerp(color, AppColors.textPrimary, 0.3)!,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (action != null)
            action!
          else if (trailing != null)
            Container(
              padding: const EdgeInsets.fromLTRB(7, 3, 9, 3),
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.8),
                borderRadius: AppRadius.brPill,
                border: Border.all(color: AppColors.borderSoft),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.touch_app_outlined,
                    size: 13,
                    color: AppColors.textTertiary,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      trailing!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.style(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                        height: AppTypography.uppercaseHeight,
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

/// Thẻ nhóm danh sách — nền pha teal rất nhẹ, viền mảnh, bóng mềm, divider
/// thụt lề.
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
        gradient: TintedCardBackdrop.gradient(AppColors.primary),
        borderRadius: AppRadius.brLg,
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.10)),
        boxShadow: AppShadows.card,
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
                  child: Divider(
                    height: 1,
                    thickness: 1,
                    color: AppColors.primary.withValues(alpha: 0.08),
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

/// Hàng chức vụ: huy hiệu thứ hạng + tên + số (font hiển thị) + % + thanh tỉ lệ.
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
    final ink = Color.lerp(color, AppColors.textPrimary, 0.25)!;
    final share = total <= 0 ? 0.0 : (count / total).clamp(0.0, 1.0);
    final pct = (share * 100).round();

    final body = Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 13),
      child: Row(
        children: [
          // Huy hiệu thứ hạng: số thứ tự trong ô bo cùng sắc chức vụ.
          AnimatedContainer(
            duration: AppDurations.fast,
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: AppRadius.brControl,
              gradient: selected
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color.lerp(color, Colors.white, 0.12)!, color],
                    )
                  : null,
              color: selected ? null : color.withValues(alpha: 0.10),
              border: Border.all(
                color: color.withValues(alpha: selected ? 0 : 0.2),
              ),
              boxShadow: selected ? AppShadows.tinted(color) : null,
            ),
            child: selected
                ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
                : Text(
                    '${index + 1}',
                    style: AppTypography.display(fontSize: 14, color: ink),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.style(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.15,
                          height: AppTypography.uppercaseHeight,
                          color: selected
                              ? AppColors.primaryDark
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      AppFormat.number(count),
                      style: AppTypography.display(
                        fontSize: 18,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.10),
                        borderRadius: AppRadius.brPill,
                      ),
                      child: Text(
                        '$pct%',
                        style: AppTypography.style(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: ink,
                          tabular: true,
                          height: AppTypography.uppercaseHeight,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Rãnh nhạt + vệt chuyển sắc, mọc dần khi hàng xuất hiện.
                Container(
                  height: 7,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.10),
                    borderRadius: AppRadius.brPill,
                  ),
                  alignment: Alignment.centerLeft,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: share),
                    duration: AppDurations.slow,
                    curve: Curves.easeOutCubic,
                    builder: (context, v, _) => FractionallySizedBox(
                      heightFactor: 1,
                      widthFactor: v <= 0 ? 0 : v.clamp(0.03, 1.0),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: AppRadius.brPill,
                          gradient: LinearGradient(
                            colors: [
                              Color.lerp(color, Colors.white, 0.3)!,
                              color,
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: color.withValues(alpha: 0.35),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 10),
            TintedChevron(accent: color),
          ],
        ],
      ),
    );

    if (onTap == null) return body;
    return Semantics(
      button: true,
      selected: selected,
      label: '$label, $count người, $pct%',
      excludeSemantics: true,
      child: Material(
        color: selected ? color.withValues(alpha: 0.07) : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          splashColor: color.withValues(alpha: 0.10),
          highlightColor: color.withValues(alpha: 0.05),
          child: body,
        ),
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
    final position = row.positionTitle.trim();
    final code = row.employeeCode.trim();

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StatusRingAvatar(name: row.fullName, color: statusColor),
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
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.25,
                        height: AppTypography.uppercaseHeight,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (position.isNotEmpty || code.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text.rich(
                        TextSpan(
                          children: [
                            if (position.isNotEmpty)
                              TextSpan(
                                text: position,
                                style: AppTypography.style(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                            if (position.isNotEmpty && code.isNotEmpty)
                              const TextSpan(text: '   '),
                            if (code.isNotEmpty) ...[
                              const WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                child: Padding(
                                  padding: EdgeInsets.only(right: 3),
                                  child: Icon(
                                    Icons.tag_rounded,
                                    size: 12,
                                    color: AppColors.textTertiary,
                                  ),
                                ),
                              ),
                              TextSpan(
                                text: code,
                                style: AppTypography.style(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textTertiary,
                                  tabular: true,
                                ),
                              ),
                            ],
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.style(
                          height: AppTypography.uppercaseHeight,
                        ),
                      ),
                    ],
                    if (showDepartment && row.departmentName.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(
                            Icons.apartment_rounded,
                            size: 13,
                            color: AppColors.textTertiary,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              row.departmentName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.style(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary,
                                height: AppTypography.uppercaseHeight,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _PersonTag(
                          label: daily
                              ? row.attendanceStatusLabel
                              : row.employeeStatusLabel,
                          color: statusColor,
                          dot: true,
                        ),
                        if (row.categoryLabel.isNotEmpty)
                          _PersonTag(
                            label: row.categoryLabel,
                            color: AppColors.primary,
                            icon: Icons.badge_outlined,
                          ),
                        if (daily && row.lateMinutes > 0)
                          _PersonTag(
                            label: 'Muộn ${row.lateMinutes}’',
                            color: AppColors.warning,
                            icon: Icons.schedule_rounded,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (daily) ...[const SizedBox(height: 10), _PunchBar(row: row)],
        ],
      ),
    );
  }
}

/// Avatar với viền chuyển sắc theo trạng thái, khe trắng mảnh và chấm trạng thái.
class _StatusRingAvatar extends StatelessWidget {
  const _StatusRingAvatar({required this.name, required this.color});

  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 50,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withValues(alpha: 0.6),
                  color.withValues(alpha: 0.12),
                ],
              ),
            ),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surface,
              ),
              child: AppAvatar(name: name, size: 42, showShadow: false),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.surface, width: 2.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Nhãn gọn: chấm hoặc icon + chữ trên nền pha nhạt, viền mảnh cùng sắc.
class _PersonTag extends StatelessWidget {
  const _PersonTag({
    required this.label,
    required this.color,
    this.dot = false,
    this.icon,
  });

  final String label;
  final Color color;
  final bool dot;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    // Chữ đậm hơn nền một bậc để đủ tương phản trên nền pha 8%.
    final ink = Color.lerp(color, AppColors.textPrimary, 0.25)!;
    return Container(
      padding: const EdgeInsets.fromLTRB(7, 3, 9, 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: AppRadius.brChip,
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot)
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(right: 5),
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            )
          else if (icon != null)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(icon, size: 12, color: ink),
            ),
          Text(
            label,
            style: AppTypography.style(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              height: AppTypography.uppercaseHeight,
              color: ink,
            ),
          ),
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
          Container(width: 1, height: 26, color: AppColors.divider),
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
    'à': 'a',
    'á': 'a',
    'ạ': 'a',
    'ả': 'a',
    'ã': 'a',
    'â': 'a',
    'ầ': 'a',
    'ấ': 'a',
    'ậ': 'a',
    'ẩ': 'a',
    'ẫ': 'a',
    'ă': 'a',
    'ằ': 'a',
    'ắ': 'a',
    'ặ': 'a',
    'ẳ': 'a',
    'ẵ': 'a',
    'è': 'e',
    'é': 'e',
    'ẹ': 'e',
    'ẻ': 'e',
    'ẽ': 'e',
    'ê': 'e',
    'ề': 'e',
    'ế': 'e',
    'ệ': 'e',
    'ể': 'e',
    'ễ': 'e',
    'ì': 'i',
    'í': 'i',
    'ị': 'i',
    'ỉ': 'i',
    'ĩ': 'i',
    'ò': 'o',
    'ó': 'o',
    'ọ': 'o',
    'ỏ': 'o',
    'õ': 'o',
    'ô': 'o',
    'ồ': 'o',
    'ố': 'o',
    'ộ': 'o',
    'ổ': 'o',
    'ỗ': 'o',
    'ơ': 'o',
    'ờ': 'o',
    'ớ': 'o',
    'ợ': 'o',
    'ở': 'o',
    'ỡ': 'o',
    'ù': 'u',
    'ú': 'u',
    'ụ': 'u',
    'ủ': 'u',
    'ũ': 'u',
    'ư': 'u',
    'ừ': 'u',
    'ứ': 'u',
    'ự': 'u',
    'ử': 'u',
    'ữ': 'u',
    'ỳ': 'y',
    'ý': 'y',
    'ỵ': 'y',
    'ỷ': 'y',
    'ỹ': 'y',
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
