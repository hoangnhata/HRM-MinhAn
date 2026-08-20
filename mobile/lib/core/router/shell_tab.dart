import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tab đang mở của khung bottom navigation.
enum AppShellTab { home, attendance, requests, salary, profile }

/// Alias tương thích — dùng [AppShellTab].
typedef ShellTab = AppShellTab;

final shellTabProvider = StateProvider<AppShellTab>((ref) => AppShellTab.home);
