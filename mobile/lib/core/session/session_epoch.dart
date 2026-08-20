import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../router/shell_tab.dart';

/// Tăng mỗi lần đăng xuất / đăng nhập thành công để buộc các provider
/// dữ liệu theo user tạo lại (tránh hiện data nick cũ khi đổi tài khoản).
final sessionEpochProvider = StateProvider<int>((ref) => 0);

void bumpSessionEpoch(Ref ref) {
  ref.read(sessionEpochProvider.notifier).update((value) => value + 1);
  // Về tab Trang chủ để IndexedStack không giữ UI nick cũ đang mở.
  ref.read(shellTabProvider.notifier).state = AppShellTab.home;
}
