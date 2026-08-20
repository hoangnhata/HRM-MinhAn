import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/user_role.dart';

/// Kieu du lieu cua o nhap them khi duyet.
enum ApprovalFieldType { text, money, yesNo }

/// Mot o nhap bat buoc/tuy chon ma backend doi hoi khi DUYET (khong ap dung
/// khi tu choi). Vi du: HCNS duyet dao tao phai nhap tien ho tro hang thang.
class ApprovalField {
  const ApprovalField({
    required this.key,
    required this.label,
    this.hint,
    this.type = ApprovalFieldType.text,
    this.required = true,
    this.yesLabel = 'Có',
    this.noLabel = 'Không',
  });

  final String key;
  final String label;
  final String? hint;
  final ApprovalFieldType type;
  final bool required;
  final String yesLabel;
  final String noLabel;
}

/// Mot buoc duyet cua quy trinh — anh xa endpoint "pending-x" toi endpoint
/// review tuong ung, kem vai tro duoc phep goi (tranh goi endpoint 403).
class RequestReviewStage {
  const RequestReviewStage({
    required this.label,
    required this.pendingPath,
    required this.reviewSlug,
    required this.roles,
    this.approveFields = const [],
  });

  final String label;
  final String pendingPath;
  final String reviewSlug;
  final Set<UserRole> roles;

  /// Thong tin bo sung phai gui kem khi duyet o buoc nay.
  final List<ApprovalField> approveFields;
}

/// Cau hinh mot loai don tu "khac" (ngoai Cong & Danh gia da co man rieng).
/// Thiet ke generic de 1 bo man hinh dung chung cho ca 7 loai don.
class RequestTypeConfig {
  const RequestTypeConfig({
    required this.key,
    required this.label,
    required this.shortLabel,
    required this.icon,
    required this.basePath,
    required this.stages,
    this.description = '',
    this.color = AppColors.primary,
    this.historyPath = 'history',
    this.relatedPath = 'related-to-me',
    this.cancelPath = 'cancel',
    this.canCancelRoles = const {UserRole.admin, UserRole.headDepartment},
    this.listViewerRoles = const {},
    this.canCreateRoles = const {},
    this.fieldLabels = const {},
  });

  final String key;
  final String label;
  final String shortLabel;
  final IconData icon;
  final String basePath;

  /// Mô tả ngắn hiển thị ở trang danh mục đơn từ.
  final String description;

  /// Màu nhận diện của loại đơn — giúp phân biệt nhanh trong danh sách.
  final Color color;
  final List<RequestReviewStage> stages;
  final String historyPath;
  final String relatedPath;
  final String cancelPath;
  final Set<UserRole> canCancelRoles;

  /// Role được xem shell quản lý (tab Đơn của tôi / Chờ duyệt) dù không duyệt
  /// — khớp web `canView*` (vd. Trưởng khoa xem phiếu đào tạo mình lập).
  final Set<UserRole> listViewerRoles;

  /// Role được lập phiếu mới (chọn NV rồi điền form) — khớp quyền trên web.
  final Set<UserRole> canCreateRoles;

  /// Anh xa ten field (JSON) -> nhan tieng Viet de hien thi man chi tiet.
  final Map<String, String> fieldLabels;

  List<RequestReviewStage> stagesFor(UserRole role) =>
      stages.where((s) => s.roles.contains(role)).toList();

  bool canReview(UserRole role) => stagesFor(role).isNotEmpty;

  bool canCreate(UserRole role) => canCreateRoles.contains(role);

  /// Mở UI giống đơn công/điều động (2 tab), không chỉ danh sách nhân viên.
  bool canUseManagerShell(UserRole role) =>
      canReview(role) || listViewerRoles.contains(role);

  static const List<RequestTypeConfig> all = [
    RequestTypeConfig(
      key: 'young-child',
      label: 'Chế độ nuôi con nhỏ',
      shortLabel: 'Nuôi con nhỏ',
      icon: Icons.child_care_outlined,
      basePath: '/young-child-requests',
      description: 'Đăng ký giảm giờ làm cho nhân viên nuôi con dưới 12 tháng.',
      color: AppColors.info,
      canCancelRoles: {UserRole.admin, UserRole.headDepartment},
      listViewerRoles: {UserRole.headDepartment},
      canCreateRoles: {UserRole.admin, UserRole.headDepartment},
      stages: [
        RequestReviewStage(
          label: 'HCNS',
          pendingPath: 'pending',
          reviewSlug: 'hr-review',
          roles: {UserRole.admin, UserRole.hr, UserRole.hr2},
        ),
      ],
      fieldLabels: {
        'startDate': 'Từ ngày',
        'endDate': 'Đến ngày',
        'enabled': 'Áp dụng chế độ',
        'reason': 'Lý do',
      },
    ),
    RequestTypeConfig(
      key: 'department-transfer',
      label: 'Luân chuyển phòng ban',
      shortLabel: 'Luân chuyển',
      icon: Icons.compare_arrows_outlined,
      basePath: '/department-transfers',
      description: 'Điều chuyển nhân viên sang khoa/phòng khác kèm chức danh mới.',
      color: AppColors.primary,
      canCancelRoles: {UserRole.admin, UserRole.hr},
      listViewerRoles: {UserRole.hr},
      canCreateRoles: {UserRole.admin, UserRole.hr},
      stages: [
        RequestReviewStage(label: 'Giám đốc', pendingPath: 'pending', reviewSlug: 'director-review', roles: {UserRole.admin, UserRole.director}),
      ],
      fieldLabels: {
        'toDepartmentName': 'Chuyển đến phòng ban',
        'toPositionTitle': 'Chức danh mới',
        'effectiveDate': 'Ngày hiệu lực',
        'reason': 'Lý do',
      },
    ),
    RequestTypeConfig(
      key: 'probation-conversion',
      label: 'Chuyển chính thức',
      shortLabel: 'Lên chính thức',
      icon: Icons.badge_outlined,
      basePath: '/probation-conversions',
      description: 'Đề nghị ký hợp đồng chính thức sau thời gian thử việc.',
      color: AppColors.success,
      canCancelRoles: {UserRole.admin, UserRole.headDepartment},
      listViewerRoles: {UserRole.headDepartment},
      canCreateRoles: {UserRole.admin, UserRole.headDepartment},
      stages: [
        RequestReviewStage(label: 'Trưởng phòng ĐD', pendingPath: 'pending-nursing-head', reviewSlug: 'nursing-head-review', roles: {UserRole.admin, UserRole.headNursing}),
        RequestReviewStage(label: 'HCNS', pendingPath: 'pending-hr', reviewSlug: 'hr-review', roles: {UserRole.admin, UserRole.hr, UserRole.hr2}),
        RequestReviewStage(label: 'Giám đốc', pendingPath: 'pending-director', reviewSlug: 'director-review', roles: {UserRole.admin, UserRole.director}),
      ],
      fieldLabels: {
        'officialDate': 'Ngày chính thức',
        'formType': 'Loại hồ sơ',
        'reason': 'Lý do',
        'mentorComment': 'Nhận xét người hướng dẫn',
        'headDeptComment': 'Nhận xét Trưởng khoa/phòng',
      },
    ),
    RequestTypeConfig(
      key: 'main-duty-authorization',
      label: 'Chuyển trực chính',
      shortLabel: 'Trực chính',
      icon: Icons.verified_user_outlined,
      basePath: '/main-duty-authorizations',
      description: 'Xin công nhận đủ điều kiện trực chính sau thời gian trực kèm.',
      color: AppColors.secondaryDark,
      canCancelRoles: {UserRole.admin, UserRole.headDepartment},
      listViewerRoles: {UserRole.headDepartment},
      canCreateRoles: {UserRole.admin, UserRole.headDepartment},
      stages: [
        RequestReviewStage(label: 'Trưởng khoa/phòng', pendingPath: 'pending-head', reviewSlug: 'head-review', roles: {UserRole.admin, UserRole.headDepartment}),
        RequestReviewStage(label: 'Trưởng phòng ĐD', pendingPath: 'pending-nursing-head', reviewSlug: 'nursing-head-review', roles: {UserRole.admin, UserRole.headNursing}),
        RequestReviewStage(label: 'HCNS', pendingPath: 'pending-hr', reviewSlug: 'hr-review', roles: {UserRole.admin, UserRole.hr, UserRole.hr2}),
        RequestReviewStage(label: 'Giám đốc', pendingPath: 'pending-director', reviewSlug: 'director-review', roles: {UserRole.admin, UserRole.director}),
      ],
      fieldLabels: {
        'accompanyingFrom': 'Trực kèm từ',
        'accompanyingTo': 'Trực kèm đến',
        'effectiveFrom': 'Trực chính từ',
        'phone': 'Điện thoại',
        'address': 'Địa chỉ',
        'gender': 'Giới tính',
        'degree': 'Trình độ',
        'reason': 'Lý do',
      },
    ),
    RequestTypeConfig(
      key: 'training-proposal',
      label: 'Đề xuất đào tạo',
      shortLabel: 'Đào tạo',
      icon: Icons.school_outlined,
      basePath: '/training-proposals',
      description: 'Đề xuất cử cán bộ nhân viên tham gia khóa đào tạo.',
      color: AppColors.warning,
      canCancelRoles: {UserRole.admin, UserRole.headDepartment, UserRole.headNursing},
      listViewerRoles: {UserRole.headDepartment, UserRole.headNursing},
      canCreateRoles: {UserRole.admin, UserRole.headDepartment, UserRole.headNursing},
      stages: [
        RequestReviewStage(
          label: 'HCNS',
          pendingPath: 'pending-hr',
          reviewSlug: 'hr-review',
          roles: {UserRole.admin, UserRole.hr, UserRole.hr2},
          // Backend chặn duyệt nếu thiếu hai thông tin này.
          approveFields: [
            ApprovalField(
              key: 'monthlySupport',
              label: 'Tiền hỗ trợ hàng tháng',
              hint: 'VD: 2.000.000 đ/tháng',
              type: ApprovalFieldType.money,
            ),
            ApprovalField(
              key: 'postCourseCommitment',
              label: 'Cam kết sau khóa học',
              hint: 'VD: 24 tháng',
            ),
          ],
        ),
        RequestReviewStage(label: 'Giám đốc', pendingPath: 'pending-director', reviewSlug: 'director-review', roles: {UserRole.admin, UserRole.director}),
      ],
      fieldLabels: {
        'proposingDepartment': 'Phòng ban đề xuất',
        'courseName': 'Tên khóa học',
        'monthlySupport': 'Tiền hỗ trợ hàng tháng',
        'postCourseCommitment': 'Cam kết sau khóa học',
        'location': 'Địa điểm',
        'plannedPeriod': 'Thời gian dự kiến',
        'tuitionFee': 'Học phí',
        'trainingGoal': 'Mục tiêu đào tạo',
        'reason': 'Lý do',
      },
    ),
    RequestTypeConfig(
      key: 'seminar-proposal',
      label: 'Đề xuất hội thảo',
      shortLabel: 'Hội thảo',
      icon: Icons.groups_outlined,
      basePath: '/seminar-proposals',
      description: 'Đề xuất cử cán bộ nhân viên tham dự hội thảo chuyên môn.',
      color: Color(0xFF7C3AED),
      canCancelRoles: {UserRole.admin, UserRole.headDepartment, UserRole.headNursing},
      listViewerRoles: {UserRole.headDepartment, UserRole.headNursing},
      canCreateRoles: {UserRole.admin, UserRole.headDepartment, UserRole.headNursing},
      stages: [
        RequestReviewStage(
          label: 'Giám đốc',
          pendingPath: 'pending-director',
          reviewSlug: 'director-review',
          roles: {UserRole.admin, UserRole.director},
          // Giám đốc phải quyết định có tính công hay không khi duyệt.
          approveFields: [
            ApprovalField(
              key: 'withPay',
              label: 'Tính công cho ngày hội thảo',
              type: ApprovalFieldType.yesNo,
              yesLabel: 'Có công',
              noLabel: 'Không công',
            ),
            ApprovalField(
              key: 'supportAmount',
              label: 'Tiền hỗ trợ (nếu có)',
              hint: 'VD: 500.000 đ',
              type: ApprovalFieldType.money,
              required: false,
            ),
          ],
        ),
      ],
      fieldLabels: {
        'proposingDepartment': 'Phòng ban đề xuất',
        'seminarName': 'Tên hội thảo',
        'location': 'Địa điểm',
        'startDate': 'Từ ngày',
        'endDate': 'Đến ngày',
        'attendanceScope': 'Phạm vi tham dự',
        'withPay': 'Tính công',
        'supportAmount': 'Tiền hỗ trợ',
        'reason': 'Lý do',
      },
    ),
    RequestTypeConfig(
      key: 'shift-config-change',
      label: 'Thay đổi giờ ca',
      shortLabel: 'Đổi giờ ca',
      icon: Icons.schedule_outlined,
      basePath: '/shift-config-change-requests',
      description: 'Xin điều chỉnh giờ vào/ra ca theo mùa cho khoa phòng.',
      color: Color(0xFFDB2777),
      canCancelRoles: {UserRole.admin, UserRole.headDepartment},
      listViewerRoles: {UserRole.headDepartment},
      canCreateRoles: {UserRole.admin, UserRole.headDepartment},
      stages: [
        RequestReviewStage(
          label: 'HCNS',
          pendingPath: 'pending',
          reviewSlug: 'hr-review',
          roles: {UserRole.admin, UserRole.hr, UserRole.hr2},
        ),
      ],
      fieldLabels: {
        'season': 'Mùa áp dụng',
        'morningStart': 'Sáng bắt đầu',
        'morningEnd': 'Sáng kết thúc',
        'afternoonStart': 'Chiều bắt đầu',
        'afternoonEnd': 'Chiều kết thúc',
        'reason': 'Lý do',
      },
    ),
  ];

  static RequestTypeConfig byKey(String key) => all.firstWhere((c) => c.key == key);
}
