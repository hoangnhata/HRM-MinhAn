import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';

/// Cuộn tới widget đã gắn [GlobalKey] (card được khoanh từ thông báo).
///
/// [index] là chỉ số phần tử trong ListView (gồm cả banner/toolbar phía trên
/// card). ListView chỉ dựng item trong viewport nên khi key chưa gắn, ta đo
/// các item đang hiện rồi tiến từng đoạn — không nhảy một phát xuống cuối.
void scheduleScrollToHighlight(
  GlobalKey key, {
  ScrollController? controller,
  int? index,
}) {
  unawaited(_scrollToHighlight(key, controller: controller, index: index));
}

Future<void> _scrollToHighlight(
  GlobalKey key, {
  ScrollController? controller,
  int? index,
}) async {
  for (var attempt = 0; attempt < 40; attempt++) {
    if (attempt == 0) {
      await WidgetsBinding.instance.endOfFrame;
    } else {
      await Future<void>.delayed(
        Duration(milliseconds: attempt < 10 ? 40 : 70),
      );
    }

    final ctx = key.currentContext;
    if (ctx != null && ctx.mounted) {
      try {
        await Scrollable.ensureVisible(
          ctx,
          duration: attempt <= 1
              ? Duration.zero
              : const Duration(milliseconds: 360),
          curve: Curves.easeOutCubic,
          alignment: 0.12,
        );
      } catch (_) {}
      return;
    }

    final scroll = controller;
    if (scroll == null ||
        !scroll.hasClients ||
        index == null ||
        index < 0) {
      continue;
    }

    final position = scroll.position;
    if (!position.hasPixels) continue;

    final max = position.maxScrollExtent;
    if (max <= 0) continue;

    final viewport = position.viewportDimension;
    final range = _laidOutChildRange(scroll);
    if (range == null) continue;

    final (first, last, avgExtent) = range;
    if (index >= first && index <= last) {
      continue;
    }

    final steps = index > last ? index - last : first - index;
    var delta = (steps * avgExtent).clamp(48.0, viewport * 0.7);
    if (index < first) delta = -delta;

    final target = (scroll.offset + delta).clamp(0.0, max);
    if ((target - scroll.offset).abs() < 0.5) continue;

    try {
      if (attempt == 0) {
        scroll.jumpTo(target);
      } else {
        await scroll.animateTo(
          target,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
        );
      }
    } catch (_) {
      return;
    }
  }
}

(int first, int last, double avgExtent)? _laidOutChildRange(
  ScrollController scroll,
) {
  final sliver = _findSliverList(scroll);
  if (sliver == null) return null;
  final firstChild = sliver.firstChild;
  final lastChild = sliver.lastChild;
  if (firstChild == null || lastChild == null) return null;

  final first = sliver.indexOf(firstChild);
  final last = sliver.indexOf(lastChild);
  if (last < first) return null;

  var sum = 0.0;
  var count = 0;
  RenderBox? child = firstChild;
  while (child != null) {
    sum += sliver.constraints.axis == Axis.vertical
        ? child.size.height
        : child.size.width;
    count++;
    child = sliver.childAfter(child);
  }
  if (count == 0) return null;
  return (first, last, sum / count);
}

RenderSliverMultiBoxAdaptor? _findSliverList(ScrollController scroll) {
  final ctx = scroll.position.context.notificationContext;
  final root = ctx?.findRenderObject();
  if (root == null) return null;

  RenderSliverMultiBoxAdaptor? found;
  void visit(RenderObject node) {
    if (found != null) return;
    if (node is RenderSliverMultiBoxAdaptor) {
      found = node;
      return;
    }
    node.visitChildren(visit);
  }

  visit(root);
  return found;
}

/// Viền pulse “khoanh” nội dung khi mở từ thông báo hệ thống / inbox.
class HighlightPulse extends StatefulWidget {
  const HighlightPulse({
    super.key,
    required this.active,
    required this.child,
    this.color = AppColors.warning,
    this.duration = const Duration(milliseconds: 3200),
    this.borderRadius,
  });

  final bool active;
  final Widget child;
  final Color color;
  final Duration duration;
  final BorderRadius? borderRadius;

  @override
  State<HighlightPulse> createState() => _HighlightPulseState();
}

class _HighlightPulseState extends State<HighlightPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _show = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (widget.active) {
      _start();
    }
  }

  @override
  void didUpdateWidget(covariant HighlightPulse oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      _start();
    }
  }

  void _start() {
    setState(() => _show = true);
    _controller.repeat(reverse: true);
    Future<void>.delayed(widget.duration, () {
      if (!mounted) return;
      _controller.stop();
      _controller.value = 0;
      setState(() => _show = false);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_show) return widget.child;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_controller.value);
        final alpha = 0.55 + (0.4 * t);
        final width = 2.4 + (1.6 * t);
        final radius = widget.borderRadius ?? AppRadius.brCard;
        return Container(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: widget.color.withValues(alpha: alpha),
              width: width,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.22 + 0.14 * t),
                blurRadius: 10 + 6 * t,
                spreadRadius: 0.5,
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
