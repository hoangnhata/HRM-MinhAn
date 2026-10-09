import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';
import 'search_field.dart';

/// Kết quả chọn phạm vi: [cleared] = chọn "toàn khối", ngược lại là [id].
class DepartmentPick {
  const DepartmentPick.all() : id = null, cleared = true;
  const DepartmentPick.department(int this.id) : cleared = false;

  final int? id;
  final bool cleared;
}

/// Sheet chọn khoa/phòng dùng chung cho các màn báo cáo.
///
/// [items] là cặp (id, tên). Trả `null` khi đóng sheet không chọn.
Future<DepartmentPick?> showDepartmentPickerSheet(
  BuildContext context, {
  required List<(int, String)> items,
  int? selectedId,
  String title = 'Lọc theo khoa/phòng',
  String? subtitle,
  String allLabel = 'Toàn khối',
  String allDescription = 'Tổng hợp tất cả khoa/phòng',
}) {
  return showModalBottomSheet<DepartmentPick>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    // Sheet tự vẽ thanh kéo — tắt thanh mặc định để không bị trùng.
    showDragHandle: false,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: AppRadius.brSheetTop),
    builder: (_) => _DepartmentPickerSheet(
      items: items,
      selectedId: selectedId,
      title: title,
      subtitle: subtitle ?? '${items.length} khoa/phòng',
      allLabel: allLabel,
      allDescription: allDescription,
    ),
  );
}

class _DepartmentPickerSheet extends StatefulWidget {
  const _DepartmentPickerSheet({
    required this.items,
    required this.selectedId,
    required this.title,
    required this.subtitle,
    required this.allLabel,
    required this.allDescription,
  });

  final List<(int, String)> items;
  final int? selectedId;
  final String title;
  final String subtitle;
  final String allLabel;
  final String allDescription;

  @override
  State<_DepartmentPickerSheet> createState() => _DepartmentPickerSheetState();
}

class _DepartmentPickerSheetState extends State<_DepartmentPickerSheet> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _pop(DepartmentPick pick) {
    HapticFeedback.selectionClick();
    Navigator.pop(context, pick);
  }

  @override
  Widget build(BuildContext context) {
    final q = _fold(_query);
    final visible = [
      for (final (i, item) in widget.items.indexed)
        if (q.isEmpty || _fold(item.$2).contains(q)) (i, item),
    ];
    final showSearch = widget.items.length > 8;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.78,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: const BoxDecoration(
                  color: AppColors.surfaceHighest,
                  borderRadius: AppRadius.brPill,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      gradient: AppGradients.brand,
                      borderRadius: AppRadius.brBase,
                      boxShadow: AppShadows.tinted(AppColors.primary),
                    ),
                    child: const Icon(
                      Icons.filter_list_rounded,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: AppTypography.style(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                            height: AppTypography.uppercaseHeight,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          widget.subtitle,
                          style: AppTypography.style(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            height: AppTypography.uppercaseHeight,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Đóng',
                    onPressed: () => Navigator.pop(context),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.surfaceMuted,
                      foregroundColor: AppColors.textSecondary,
                      shape: const CircleBorder(),
                    ),
                    icon: const Icon(Icons.close_rounded, size: 20),
                  ),
                ],
              ),
            ),
            if (showSearch)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: AppSearchField(
                  controller: _search,
                  hintText: 'Tìm khoa/phòng…',
                  dense: true,
                  borderRadius: AppRadius.brMd,
                  debounce: Duration.zero,
                  onChanged: (v) => setState(() => _query = v.trim()),
                ),
              ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  if (q.isEmpty) ...[
                    _AllScopeCard(
                      label: widget.allLabel,
                      description: widget.allDescription,
                      selected: widget.selectedId == null,
                      onTap: () => _pop(const DepartmentPick.all()),
                    ),
                    const SizedBox(height: 14),
                  ],
                  Padding(
                    padding: const EdgeInsets.only(left: 2, bottom: 6),
                    child: Text(
                      q.isEmpty
                          ? 'KHOA/PHÒNG · ${widget.items.length}'
                          : 'KẾT QUẢ · ${visible.length}',
                      style: AppTypography.uppercase(
                        fontSize: 10,
                        letterSpacing: 0.8,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
                  if (visible.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.search_off_rounded,
                            size: 32,
                            color: AppColors.textTertiary,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Không tìm thấy khoa/phòng phù hợp',
                            style: AppTypography.style(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: AppRadius.brLg,
                        border: Border.all(color: AppColors.borderSoft),
                        boxShadow: AppShadows.soft,
                      ),
                      child: ClipRRect(
                        borderRadius: AppRadius.brLg,
                        child: Column(
                          children: [
                            for (final (n, entry) in visible.indexed) ...[
                              if (n > 0)
                                const Divider(
                                  height: 1,
                                  indent: 60,
                                  color: AppColors.divider,
                                ),
                              _DepartmentRow(
                                name: entry.$2.$2,
                                color:
                                    AppColors.chartPalette[entry.$1 %
                                        AppColors.chartPalette.length],
                                selected: entry.$2.$1 == widget.selectedId,
                                onTap: () => _pop(
                                  DepartmentPick.department(entry.$2.$1),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lựa chọn "toàn khối" nổi bật ở đầu danh sách.
class _AllScopeCard extends StatelessWidget {
  const _AllScopeCard({
    required this.label,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: AppDurations.fast,
        decoration: BoxDecoration(
          gradient: AppGradients.tint(AppColors.primary),
          color: AppColors.surface,
          borderRadius: AppRadius.brLg,
          border: Border.all(
            color: AppColors.primary.withValues(alpha: selected ? 0.5 : 0.16),
            width: selected ? 1.5 : 1,
          ),
          boxShadow: selected
              ? AppShadows.tinted(AppColors.primary)
              : AppShadows.soft,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: AppRadius.brLg,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: AppGradients.brand,
                      borderRadius: AppRadius.brBase,
                      boxShadow: AppShadows.tinted(AppColors.primary),
                    ),
                    child: const Icon(
                      Icons.account_balance_rounded,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: AppTypography.style(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            height: AppTypography.uppercaseHeight,
                            color: AppColors.primaryDark,
                          ),
                        ),
                        Text(
                          description,
                          style: AppTypography.style(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            height: AppTypography.uppercaseHeight,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _Radio(selected: selected, color: AppColors.primary),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DepartmentRow extends StatelessWidget {
  const _DepartmentRow({
    required this.name,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ink = Color.lerp(color, AppColors.textPrimary, 0.25)!;
    return Semantics(
      button: true,
      selected: selected,
      label: name,
      excludeSemantics: true,
      child: Material(
        color: selected
            ? AppColors.primary.withValues(alpha: 0.07)
            : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        color.withValues(alpha: 0.18),
                        color.withValues(alpha: 0.07),
                      ],
                    ),
                    borderRadius: AppRadius.brControl,
                    border: Border.all(color: color.withValues(alpha: 0.18)),
                  ),
                  child: Text(
                    _initials(name),
                    style: AppTypography.style(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                      color: ink,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _pretty(name),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.style(
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      height: AppTypography.uppercaseHeight,
                      color: selected
                          ? AppColors.primaryDark
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _Radio(selected: selected, color: AppColors.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Vòng radio: rỗng → đĩa đặc có dấu ✓.
class _Radio extends StatelessWidget {
  const _Radio({required this.selected, required this.color});

  final bool selected;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppDurations.fast,
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? color : Colors.transparent,
        border: Border.all(
          color: selected ? color : AppColors.border,
          width: 2,
        ),
      ),
      child: selected
          ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
          : null,
    );
  }
}

const _skipWords = {'khoa', 'phong', 'ban', 'to', 'trung', 'tam', 'bo', 'phan'};

/// Viết tắt tên khoa (bỏ tiền tố "Khoa", "Phòng"…): "KHOA GÂY MÊ HỒI SỨC" → "GM".
String _initials(String name) {
  final words = name
      .trim()
      .split(RegExp(r'[\s\-_/]+'))
      .where((w) => w.isNotEmpty)
      .toList();
  if (words.isEmpty) return '?';
  final core = words.where((w) => !_skipWords.contains(_fold(w))).toList();
  final src = core.isEmpty ? words : core;
  return src.take(2).map((w) => w.characters.first.toUpperCase()).join();
}

/// Tên in hoa toàn bộ → viết hoa đầu chữ ("KHOA SẢN" → "Khoa Sản").
String _pretty(String raw) {
  final t = raw.trim();
  final letters = t.replaceAll(RegExp(r'[^A-Za-zÀ-ỹ]'), '');
  if (letters.isEmpty || letters != letters.toUpperCase()) return t;
  return t
      .toLowerCase()
      .split(' ')
      .map(
        (w) => w.isEmpty
            ? w
            : '${w.characters.first.toUpperCase()}${w.substring(w.characters.first.length)}',
      )
      .join(' ');
}

/// Bỏ dấu tiếng Việt + chữ thường để tìm kiếm không cần gõ dấu.
String _fold(String raw) {
  const groups = {
    'a': 'àáạảãâầấậẩẫăằắặẳẵ',
    'e': 'èéẹẻẽêềếệểễ',
    'i': 'ìíịỉĩ',
    'o': 'òóọỏõôồốộổỗơờớợởỡ',
    'u': 'ùúụủũưừứựửữ',
    'y': 'ỳýỵỷỹ',
    'd': 'đ',
  };
  final buf = StringBuffer();
  for (final ch in raw.toLowerCase().characters) {
    var out = ch;
    for (final e in groups.entries) {
      if (e.value.contains(ch)) {
        out = e.key;
        break;
      }
    }
    buf.write(out);
  }
  return buf.toString();
}
