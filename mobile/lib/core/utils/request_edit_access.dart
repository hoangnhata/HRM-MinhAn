import 'user_role.dart';

bool isPendingRequestStatus(String? status) =>
    status != null && status.toUpperCase().startsWith('PENDING');

bool canEditOwnPendingRequest(
  Map<String, dynamic> row, {
  String? username,
  UserRole role = UserRole.unknown,
}) {
  if (!isPendingRequestStatus(row['status'] as String?)) return false;
  if (role == UserRole.admin) return true;
  final owner = (row['requestedByUsername'] as String?)?.trim();
  final me = username?.trim();
  return owner != null && owner.isNotEmpty && me != null && me == owner;
}
