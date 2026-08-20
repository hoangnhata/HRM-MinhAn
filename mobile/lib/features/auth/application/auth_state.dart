import '../../../core/utils/user_role.dart';
import '../../../shared/models/current_user.dart';

enum AuthStatus {
  /// Dang kiem tra session da luu (splash).
  bootstrapping,
  unauthenticated,
  /// Da dang nhap nhung backend yeu cau doi mat khau truoc.
  mustChangePassword,
  /// Da dang nhap nhung backend yeu cau thiet lap chu ky truoc.
  mustSetSignature,
  authenticated,
}

class AuthState {
  const AuthState({
    this.status = AuthStatus.bootstrapping,
    this.role = UserRole.unknown,
    this.userId,
    this.employeeId,
    this.fullName,
    this.currentUser,
    this.errorMessage,
  });

  final AuthStatus status;
  final UserRole role;
  final int? userId;
  final int? employeeId;
  final String? fullName;
  final CurrentUser? currentUser;
  final String? errorMessage;

  bool get isAuthenticated =>
      status == AuthStatus.authenticated ||
      status == AuthStatus.mustChangePassword ||
      status == AuthStatus.mustSetSignature;

  AuthState copyWith({
    AuthStatus? status,
    UserRole? role,
    int? userId,
    int? employeeId,
    String? fullName,
    CurrentUser? currentUser,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      role: role ?? this.role,
      userId: userId ?? this.userId,
      employeeId: employeeId ?? this.employeeId,
      fullName: fullName ?? this.fullName,
      currentUser: currentUser ?? this.currentUser,
      errorMessage: errorMessage,
    );
  }
}
