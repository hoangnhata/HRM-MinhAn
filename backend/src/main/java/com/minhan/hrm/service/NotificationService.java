package com.minhan.hrm.service;

import com.minhan.hrm.dto.notification.NotificationDto;
import com.minhan.hrm.entity.AttendanceRequestStatus;
import com.minhan.hrm.entity.AttendanceRequestType;
import com.minhan.hrm.entity.AttendanceWorkRequest;
import com.minhan.hrm.entity.DepartmentTransferRequest;
import com.minhan.hrm.entity.Employee;
import com.minhan.hrm.entity.EmployeeStatus;
import com.minhan.hrm.entity.MainDutyAuthorizationRequest;
import com.minhan.hrm.entity.MainDutyAuthorizationStatus;
import com.minhan.hrm.entity.MainDutyFormType;
import com.minhan.hrm.entity.Notification;
import com.minhan.hrm.entity.NotificationCategory;
import com.minhan.hrm.entity.NursingEvaluation;
import com.minhan.hrm.entity.ProbationConversionRequest;
import com.minhan.hrm.entity.ProbationConversionStatus;
import com.minhan.hrm.entity.SeminarProposalRequest;
import com.minhan.hrm.entity.ShiftConfigChangeRequest;
import com.minhan.hrm.entity.TrainingProposalRequest;
import com.minhan.hrm.entity.UserAccount;
import com.minhan.hrm.entity.UserRole;
import com.minhan.hrm.entity.YoungChildRequest;
import com.minhan.hrm.exception.ApiException;
import com.minhan.hrm.exception.ResourceNotFoundException;
import com.minhan.hrm.repository.NotificationRepository;
import com.minhan.hrm.repository.AttendanceWorkRequestRepository;
import com.minhan.hrm.repository.UserAccountRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
@RequiredArgsConstructor
public class NotificationService {

    private final NotificationRepository notificationRepository;
    private final AttendanceWorkRequestRepository attendanceWorkRequestRepository;
    private final EmployeeService employeeService;
    private final UserAccountRepository userAccountRepository;
    private final ObjectProvider<PushNotificationService> pushNotificationService;

    @Transactional(readOnly = true)
    public List<NotificationDto> listMine() {
        UserAccount u = employeeService.currentUser();
        return notificationRepository.findByUserOrderByCreatedAtDesc(u).stream()
                .filter(n -> isVisibleNotification(u, n))
                .map(this::toDto)
                .toList();
    }

    @Transactional(readOnly = true)
    public long countUnread() {
        UserAccount u = employeeService.currentUser();
        return notificationRepository.findByUserOrderByCreatedAtDesc(u).stream()
                .filter(n -> !n.isOpened())
                .filter(n -> isVisibleNotification(u, n))
                .count();
    }

    /**
     * HEAD_NURSING chỉ thấy thông báo cá nhân (liên quan bản thân) hoặc liên quan nhân sự khối ĐD.
     */
    private boolean isVisibleNotification(UserAccount caller, Notification n) {
        if (caller == null || caller.getRole() != UserRole.HEAD_NURSING) {
            return true;
        }
        Employee related = n.getRelatedEmployee();
        if (related == null) {
            return true;
        }
        return employeeService.matchesNursingBlockScope(caller, related);
    }

    @Transactional
    public void markRead(Long id) {
        UserAccount u = employeeService.currentUser();
        Notification n = notificationRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy thông báo"));
        if (!n.getUser().getId().equals(u.getId())) {
            throw new ApiException(HttpStatus.FORBIDDEN, "Không phải thông báo của bạn");
        }
        n.setOpened(true);
        notificationRepository.save(n);
    }

    @Transactional
    public void markAllRead() {
        UserAccount user = employeeService.currentUser();
        List<Notification> unread = notificationRepository.findByUserOrderByCreatedAtDesc(user).stream()
                .filter(notification -> !notification.isOpened())
                .toList();
        unread.forEach(notification -> notification.setOpened(true));
        notificationRepository.saveAll(unread);
    }

    @Transactional
    public void notifySalaryGradeIncrease(
            UserAccount targetUser, Employee related, int oldGrade, int newGrade, String yearsRange) {
        String msg = String.format(
                "Bạn đã được nâng từ Bậc %d lên Bậc %d (%s) kể từ kỳ lương này. Xem chi tiết tại mục Lương.",
                oldGrade > 0 ? oldGrade : newGrade - 1,
                newGrade,
                yearsRange);
        Notification n = Notification.builder()
                .user(targetUser)
                .category(NotificationCategory.SALARY_ADJUSTMENT)
                .title("Thông báo nâng bậc lương")
                .message(msg)
                .opened(false)
                .relatedEmployee(related)
                .build();
        persistAndPush(n);
    }

    @Transactional
    public void notifySalaryReview(UserAccount targetUser, Employee related, String extraMessage) {
        String msg = "Đến kỳ xem xét nâng lương." + (extraMessage != null ? " " + extraMessage : "");
        Notification n = Notification.builder()
                .user(targetUser)
                .category(NotificationCategory.SALARY_REVIEW)
                .title("Nhắc lịch xét nâng lương")
                .message(msg)
                .opened(false)
                .relatedEmployee(related)
                .build();
        persistAndPush(n);
    }

    @Transactional
    public void createAdhoc(UserAccount targetUser, NotificationCategory category, String title, String message,
                            Employee related) {
        Notification n = Notification.builder()
                .user(targetUser)
                .category(category != null ? category : NotificationCategory.INTERNAL)
                .title(title)
                .message(message)
                .opened(false)
                .relatedEmployee(related)
                .build();
        persistAndPush(n);
    }

    @Transactional
    public void notifyPayrollFinalized(UserAccount targetUser, Employee related, int periodYear, int periodMonth) {
        String msg = String.format(
                "Bảng lương kỳ %02d/%d đã được chốt. Vui lòng xem tại mục Lương (chỉ hiển thị trên tài khoản của bạn).",
                periodMonth, periodYear);
        Notification n = Notification.builder()
                .user(targetUser)
                .category(NotificationCategory.PAYROLL)
                .title("Bảng lương đã chốt")
                .message(msg)
                .opened(false)
                .relatedEmployee(related)
                .build();
        persistAndPush(n);
    }

    @Transactional
    public void notifyAttendancePeriod(UserAccount targetUser, Employee related, int year, int month) {
        String msg = String.format(
                "Bảng công tháng %02d/%d đã cập nhật. Vui lòng xem tại mục Công.",
                month, year);
        Notification n = Notification.builder()
                .user(targetUser)
                .category(NotificationCategory.ATTENDANCE)
                .title("Thông báo bảng công")
                .message(msg)
                .opened(false)
                .relatedEmployee(related)
                .build();
        persistAndPush(n);
    }

    @Transactional
    public void notifyAttendanceRequestPending(UserAccount targetUser, AttendanceWorkRequest req, String stage) {
        String typeLabel = switch (req.getRequestType()) {
            case EXPLANATION -> "giải trình công";
            case UPDATE -> "cập nhật công";
            case LEAVE -> "nghỉ phép";
            case UNPAID_LEAVE -> "nghỉ không lương";
            case BUSINESS_TRIP -> "công tác";
            case DEPLOYMENT -> "điều động";
        };
        String datePart = (req.getRequestType() == AttendanceRequestType.LEAVE
                || req.getRequestType() == AttendanceRequestType.UNPAID_LEAVE
                || req.getRequestType() == AttendanceRequestType.BUSINESS_TRIP)
                && req.getEndDate() != null
                ? req.getWorkDate() + " → " + req.getEndDate()
                : String.valueOf(req.getWorkDate());
        String msg = String.format(
                "%s — %s %s chờ duyệt (%s).",
                req.getEmployee().getFullName(),
                typeLabel,
                datePart,
                "HEAD".equals(stage) ? "Lãnh đạo"
                        : "NURSING_HEAD".equals(stage) ? "Trưởng phòng Điều dưỡng"
                        : "DIRECTOR".equals(stage) ? "Giám đốc" : "HCNS");
        Notification n = Notification.builder()
                .user(targetUser)
                .category(NotificationCategory.ATTENDANCE)
                .title(req.getRequestType() == AttendanceRequestType.DEPLOYMENT
                        ? "Điều động chờ duyệt"
                        : "Đơn công chờ duyệt")
                .message(msg)
                .opened(false)
                .relatedEmployee(req.getEmployee())
                .relatedRequestId(req.getId())
                .build();
        persistAndPush(n);
    }

    @Transactional
    public void notifyAttendanceRequestResult(UserAccount targetUser, AttendanceWorkRequest req, boolean approved) {
        String typeLabel = switch (req.getRequestType()) {
            case EXPLANATION -> "Giải trình công";
            case UPDATE -> "Cập nhật công";
            case LEAVE -> "Nghỉ phép";
            case UNPAID_LEAVE -> "Nghỉ không lương";
            case BUSINESS_TRIP -> "Công tác";
            case DEPLOYMENT -> "Điều động";
        };
        String datePart = (req.getRequestType() == AttendanceRequestType.LEAVE
                || req.getRequestType() == AttendanceRequestType.UNPAID_LEAVE
                || req.getRequestType() == AttendanceRequestType.BUSINESS_TRIP)
                && req.getEndDate() != null
                ? req.getWorkDate() + " → " + req.getEndDate()
                : String.valueOf(req.getWorkDate());
        String msg = approved
                ? String.format("%s %s đã được duyệt.", typeLabel, datePart)
                : String.format("%s %s không được duyệt.", typeLabel, datePart);
        Notification n = Notification.builder()
                .user(targetUser)
                .category(NotificationCategory.ATTENDANCE)
                .title(req.getRequestType() == AttendanceRequestType.DEPLOYMENT
                        ? (approved ? "Điều động đã duyệt" : "Điều động bị từ chối")
                        : (approved ? "Đơn công đã duyệt" : "Đơn công bị từ chối"))
                .message(msg)
                .opened(false)
                .relatedEmployee(req.getEmployee())
                .relatedRequestId(req.getId())
                .build();
        persistAndPush(n);
    }

    @Transactional
    public void notifyAttendanceRequestWithdrawn(AttendanceWorkRequest req, AttendanceRequestStatus previousStatus) {
        String typeLabel = switch (req.getRequestType()) {
            case EXPLANATION -> "giải trình công";
            case UPDATE -> "cập nhật công";
            case LEAVE -> "nghỉ phép";
            case UNPAID_LEAVE -> "nghỉ không lương";
            case BUSINESS_TRIP -> "công tác";
            case DEPLOYMENT -> "điều động";
        };
        String datePart = (req.getRequestType() == AttendanceRequestType.LEAVE
                || req.getRequestType() == AttendanceRequestType.UNPAID_LEAVE
                || req.getRequestType() == AttendanceRequestType.BUSINESS_TRIP)
                && req.getEndDate() != null
                ? req.getWorkDate() + " → " + req.getEndDate()
                : String.valueOf(req.getWorkDate());
        String msg = String.format(
                "%s đã thu hồi đơn %s %s.",
                req.getEmployee().getFullName(),
                typeLabel,
                datePart);
        List<UserAccount> recipients;
        if (previousStatus == AttendanceRequestStatus.PENDING_DIRECTOR) {
            recipients = userAccountRepository.findByDirectorApprovalEnabledTrueAndEnabledTrue();
        } else if (previousStatus == AttendanceRequestStatus.PENDING_HR) {
            recipients = userAccountRepository.findByRoleIn(List.of(UserRole.ADMIN, UserRole.HR2, UserRole.HEAD_HR));
        } else if (previousStatus == AttendanceRequestStatus.PENDING_NURSING_HEAD) {
            recipients = userAccountRepository.findByRoleIn(List.of(UserRole.ADMIN, UserRole.HEAD_NURSING));
        } else {
            recipients = userAccountRepository.findByRoleIn(List.of(UserRole.ADMIN, UserRole.HEAD_DEPARTMENT, UserRole.HEAD_HR));
        }
        recipients.stream()
                .filter(u -> {
                    if (previousStatus == AttendanceRequestStatus.PENDING_HEAD) {
                        return employeeService.shouldReceiveHeadPendingNotification(u, req.getEmployee());
                    }
                    if (previousStatus == AttendanceRequestStatus.PENDING_NURSING_HEAD) {
                        return employeeService.shouldReceiveNursingHeadPendingNotification(u, req.getEmployee());
                    }
                    return true;
                })
                .forEach(u -> {
            Notification n = Notification.builder()
                    .user(u)
                    .category(NotificationCategory.ATTENDANCE)
                    .title(req.getRequestType() == AttendanceRequestType.DEPLOYMENT
                            ? "Điều động đã thu hồi"
                            : "Đơn công đã thu hồi")
                    .message(msg)
                    .opened(false)
                    .relatedEmployee(req.getEmployee())
                    .build();
            persistAndPush(n);
        });
    }

    @Transactional
    public void notifyStaffDeployment(UserAccount targetUser, AttendanceWorkRequest req, String creatorName) {
        if (targetUser == null) {
            return;
        }
        String timePart;
        if (req.getRequestedAfternoonStart() != null && req.getRequestedAfternoonEnd() != null
                && req.getRequestedStart() != null && req.getRequestedEnd() != null) {
            timePart = req.getRequestedStart() + "–" + req.getRequestedEnd()
                    + " · " + req.getRequestedAfternoonStart() + "–" + req.getRequestedAfternoonEnd();
        } else if (req.getRequestedStart() != null && req.getRequestedEnd() != null) {
            timePart = req.getRequestedStart() + "–" + req.getRequestedEnd();
        } else {
            timePart = "";
        }
        String msg = String.format(
                "Bạn được điều động ngày %s%s. Nội dung: %s. Hệ số công ×1,5. Người tạo: %s.",
                req.getWorkDate(),
                timePart.isBlank() ? "" : " (" + timePart + ")",
                req.getReason() != null ? req.getReason() : "—",
                creatorName != null && !creatorName.isBlank() ? creatorName : "Lãnh đạo");
        Notification n = Notification.builder()
                .user(targetUser)
                .category(NotificationCategory.ATTENDANCE)
                .title("Thông báo điều động")
                .message(msg)
                .opened(false)
                .relatedEmployee(req.getEmployee())
                .relatedRequestId(req.getId())
                .build();
        persistAndPush(n);
    }

    @Transactional
    public void notifyDepartmentTransferPending(UserAccount targetUser, DepartmentTransferRequest req) {
        String msg = String.format(
                "%s đề nghị chuyển %s từ «%s» sang «%s», hiệu lực %s. Vui lòng duyệt tại mục Đơn.",
                req.getRequestedBy() != null ? req.getRequestedBy().getUsername() : "HCNS",
                req.getEmployee().getFullName(),
                req.getFromDepartment().getName(),
                req.getToDepartment().getName(),
                req.getEffectiveDate());
        Notification n = Notification.builder()
                .user(targetUser)
                .category(NotificationCategory.DEPARTMENT_TRANSFER)
                .title("Luân chuyển chờ Giám đốc duyệt")
                .message(msg)
                .opened(false)
                .relatedEmployee(req.getEmployee())
                .relatedRequestId(req.getId())
                .build();
        persistAndPush(n);
    }

    @Transactional
    public void notifyDepartmentTransferResult(DepartmentTransferRequest req, boolean approved) {
        UserAccount requester = req.getRequestedBy();
        String msgForRequester = approved
                ? String.format(
                        "Giám đốc đã duyệt luân chuyển %s → «%s». Hệ thống chuyển phòng ban vào ngày %s.",
                        req.getEmployee().getFullName(),
                        req.getToDepartment().getName(),
                        req.getEffectiveDate())
                : String.format(
                        "Giám đốc từ chối luân chuyển %s → «%s».",
                        req.getEmployee().getFullName(),
                        req.getToDepartment().getName());
        if (requester != null) {
            saveNotification(
                    requester,
                    NotificationCategory.DEPARTMENT_TRANSFER,
                    approved ? "Luân chuyển đã duyệt" : "Luân chuyển bị từ chối",
                    msgForRequester,
                    req.getEmployee(),
                    req.getId());
        }
        String msgForEmployee = approved
                ? String.format(
                        "Giám đốc đã duyệt luân chuyển bạn sang «%s», hiệu lực từ ngày %s.",
                        req.getToDepartment().getName(),
                        req.getEffectiveDate())
                : String.format(
                        "Giám đốc đã từ chối đề nghị luân chuyển bạn sang «%s».",
                        req.getToDepartment().getName());
        notifyEmployee(
                req.getEmployee(),
                requester,
                NotificationCategory.DEPARTMENT_TRANSFER,
                approved ? "Luân chuyển đã được duyệt" : "Luân chuyển bị từ chối",
                msgForEmployee,
                req.getId());
    }

    @Transactional
    public void notifyDepartmentTransferSubmittedToEmployee(DepartmentTransferRequest req) {
        String requester = req.getRequestedBy() != null ? req.getRequestedBy().getUsername() : "HCNS";
        notifyEmployee(
                req.getEmployee(),
                req.getRequestedBy(),
                NotificationCategory.DEPARTMENT_TRANSFER,
                "Đề nghị luân chuyển phòng ban",
                String.format(
                        "%s đã lập đề nghị luân chuyển bạn từ «%s» sang «%s», hiệu lực %s — đang chờ Giám đốc duyệt.",
                        requester,
                        req.getFromDepartment() != null ? req.getFromDepartment().getName() : "—",
                        req.getToDepartment().getName(),
                        req.getEffectiveDate()),
                req.getId());
    }

    @Transactional
    public void notifyDepartmentTransferApplied(DepartmentTransferRequest req) {
        notifyEmployee(
                req.getEmployee(),
                null,
                NotificationCategory.DEPARTMENT_TRANSFER,
                "Đã luân chuyển phòng ban",
                String.format(
                        "Từ hôm nay bạn thuộc «%s» theo quyết định luân chuyển (hiệu lực %s).",
                        req.getToDepartment().getName(),
                        req.getEffectiveDate()),
                req.getId());
        if (req.getRequestedBy() != null) {
            saveNotification(
                    req.getRequestedBy(),
                    NotificationCategory.DEPARTMENT_TRANSFER,
                    "Đã áp dụng luân chuyển",
                    String.format(
                            "Đã chuyển %s sang «%s» theo ngày hiệu lực %s.",
                            req.getEmployee().getFullName(),
                            req.getToDepartment().getName(),
                            req.getEffectiveDate()),
                    req.getEmployee());
        }
    }

    @Transactional
    public void notifyProbationConversionPendingNursingHead(UserAccount targetUser, ProbationConversionRequest req) {
        String msg = String.format(
                "%s đề nghị chuyển %s (%s) lên chính thức từ ngày %s. Vui lòng duyệt tại mục Đơn.",
                req.getRequestedBy() != null ? req.getRequestedBy().getUsername() : "Trưởng",
                req.getEmployee().getFullName(),
                req.getEmployee().getStatus() == EmployeeStatus.INTERN ? "thực tập" : "thử việc",
                req.getOfficialDate());
        Notification n = Notification.builder()
                .user(targetUser)
                .category(NotificationCategory.PROBATION_CONVERSION)
                .title("Chuyển chính thức chờ Trưởng phòng Điều dưỡng duyệt")
                .message(msg)
                .opened(false)
                .relatedEmployee(req.getEmployee())
                .relatedRequestId(req.getId())
                .build();
        persistAndPush(n);
    }

    @Transactional
    public void notifyProbationConversionPendingHr(UserAccount targetUser, ProbationConversionRequest req) {
        String msg = String.format(
                "%s đề nghị chuyển %s (%s) lên chính thức từ ngày %s. Vui lòng duyệt tại mục Đơn.",
                req.getRequestedBy() != null ? req.getRequestedBy().getUsername() : "Trưởng",
                req.getEmployee().getFullName(),
                req.getEmployee().getStatus() == EmployeeStatus.INTERN ? "thực tập" : "thử việc",
                req.getOfficialDate());
        Notification n = Notification.builder()
                .user(targetUser)
                .category(NotificationCategory.PROBATION_CONVERSION)
                .title("Chuyển chính thức chờ HCNS duyệt")
                .message(msg)
                .opened(false)
                .relatedEmployee(req.getEmployee())
                .relatedRequestId(req.getId())
                .build();
        persistAndPush(n);
    }

    @Transactional
    public void notifyProbationConversionPendingDirector(UserAccount targetUser, ProbationConversionRequest req) {
        String msg = String.format(
                "HCNS đã duyệt đề nghị chuyển %s lên chính thức từ ngày %s. Vui lòng duyệt tại mục Đơn.",
                req.getEmployee().getFullName(),
                req.getOfficialDate());
        Notification n = Notification.builder()
                .user(targetUser)
                .category(NotificationCategory.PROBATION_CONVERSION)
                .title("Chuyển chính thức chờ Giám đốc duyệt")
                .message(msg)
                .opened(false)
                .relatedEmployee(req.getEmployee())
                .relatedRequestId(req.getId())
                .build();
        persistAndPush(n);
    }

    @Transactional
    public void notifyProbationConversionForwardedToDirector(ProbationConversionRequest req) {
        if (req.getRequestedBy() == null) {
            return;
        }
        Notification n = Notification.builder()
                .user(req.getRequestedBy())
                .category(NotificationCategory.PROBATION_CONVERSION)
                .title("Đơn chuyển chính thức đã gửi Giám đốc")
                .message(String.format(
                        "HCNS đã duyệt đề nghị chuyển %s lên chính thức — đang chờ Giám đốc.",
                        req.getEmployee().getFullName()))
                .opened(false)
                .relatedEmployee(req.getEmployee())
                .relatedRequestId(req.getId())
                .build();
        persistAndPush(n);
    }

    @Transactional
    public void notifyProbationConversionResult(ProbationConversionRequest req, boolean approved, String byRole) {
        UserAccount requester = req.getRequestedBy();
        String msgForRequester = approved
                ? String.format(
                        "%s đã duyệt chuyển %s lên chính thức. Hệ thống áp dụng vào ngày %s.",
                        byRole,
                        req.getEmployee().getFullName(),
                        req.getOfficialDate())
                : String.format(
                        "%s từ chối đề nghị chuyển %s lên chính thức.",
                        byRole,
                        req.getEmployee().getFullName());
        if (requester != null) {
            saveNotification(
                    requester,
                    NotificationCategory.PROBATION_CONVERSION,
                    approved ? "Chuyển chính thức đã duyệt" : "Chuyển chính thức bị từ chối",
                    msgForRequester,
                    req.getEmployee());
        }
        String msgForEmployee = approved
                ? String.format(
                        "%s đã duyệt chuyển bạn lên chính thức từ ngày %s.",
                        byRole,
                        req.getOfficialDate())
                : String.format("%s đã từ chối đề nghị chuyển bạn lên chính thức.", byRole);
        notifyEmployee(
                req.getEmployee(),
                requester,
                NotificationCategory.PROBATION_CONVERSION,
                approved ? "Đơn chuyển chính thức đã duyệt" : "Đơn chuyển chính thức bị từ chối",
                msgForEmployee,
                req.getId());
    }

    @Transactional
    public void notifyProbationConversionSubmittedToEmployee(ProbationConversionRequest req) {
        String requester = req.getRequestedBy() != null ? req.getRequestedBy().getUsername() : "Trưởng khoa";
        String statusLabel = req.getEmployee().getStatus() == EmployeeStatus.INTERN ? "thực tập" : "thử việc";
        String pendingStep = req.getStatus() == ProbationConversionStatus.PENDING_NURSING_HEAD
                ? "đang chờ Trưởng phòng Điều dưỡng duyệt"
                : "đang chờ HCNS duyệt";
        notifyEmployee(
                req.getEmployee(),
                req.getRequestedBy(),
                NotificationCategory.PROBATION_CONVERSION,
                "Đơn chuyển chính thức",
                String.format(
                        "%s đã lập đơn đề nghị chuyển bạn (%s) lên chính thức từ ngày %s — %s.",
                        requester,
                        statusLabel,
                        req.getOfficialDate(),
                        pendingStep),
                req.getId());
    }

    @Transactional
    public void notifyTrainingProposalCompleted(TrainingProposalRequest req) {
        String period = req.getPlannedPeriod() != null ? req.getPlannedPeriod() : "";
        notifyEmployee(
                req.getEmployee(),
                null,
                NotificationCategory.TRAINING_PROPOSAL,
                "Đã hoàn thành đào tạo",
                String.format(
                        "Khoá đào tạo «%s»%s đã kết thúc. Trạng thái đi đào tạo đã được gỡ trên hệ thống.",
                        req.getCourseName(),
                        period.isBlank() ? "" : " (" + period + ")"),
                req.getId());
        if (req.getRequestedBy() != null) {
            saveNotification(
                    req.getRequestedBy(),
                    NotificationCategory.TRAINING_PROPOSAL,
                    "Đào tạo đã hoàn thành",
                    String.format(
                            "%s đã hoàn thành khoá đào tạo «%s».",
                            req.getEmployee().getFullName(),
                            req.getCourseName()),
                    req.getEmployee());
        }
    }

    @Transactional
    public void notifySeminarProposalCompleted(SeminarProposalRequest req) {
        notifyEmployee(
                req.getEmployee(),
                null,
                NotificationCategory.SEMINAR_PROPOSAL,
                "Đã hoàn thành hội thảo",
                String.format(
                        "Hội thảo «%s» đã kết thúc. Trạng thái tham gia hội thảo đã được gỡ trên hệ thống.",
                        req.getSeminarName()),
                req.getId());
        if (req.getRequestedBy() != null) {
            saveNotification(
                    req.getRequestedBy(),
                    NotificationCategory.SEMINAR_PROPOSAL,
                    "Hội thảo đã hoàn thành",
                    String.format(
                            "%s đã hoàn thành tham gia hội thảo «%s».",
                            req.getEmployee().getFullName(),
                            req.getSeminarName()),
                    req.getEmployee());
        }
    }

    @Transactional
    public void notifyProbationConversionApplied(ProbationConversionRequest req) {
        String msg = String.format(
                "Từ hôm nay (%s) bạn đã chính thức trên hệ thống. Chúc mừng!",
                req.getOfficialDate());
        notifyEmployee(
                req.getEmployee(),
                null,
                NotificationCategory.PROBATION_CONVERSION,
                "Đã lên chính thức",
                msg,
                req.getId());
        if (req.getRequestedBy() != null) {
            saveNotification(
                    req.getRequestedBy(),
                    NotificationCategory.PROBATION_CONVERSION,
                    "Đã áp dụng chuyển chính thức",
                    String.format(
                            "Đã chuyển %s lên chính thức theo ngày %s.",
                            req.getEmployee().getFullName(),
                            req.getOfficialDate()),
                    req.getEmployee());
        }
    }

    @Transactional
    public void notifyYoungChildRequestPending(UserAccount targetUser, YoungChildRequest req) {
        String action = req.isEnabled() ? "bật" : "tắt";
        String msg = String.format(
                "%s đề xuất %s chế độ nuôi con nhỏ cho %s · từ %s đến %s. Vui lòng duyệt tại mục Đơn.",
                req.getRequestedBy() != null ? req.getRequestedBy().getUsername() : "Trưởng",
                action,
                req.getEmployee().getFullName(),
                req.getStartDate(),
                req.getEndDate());
        Notification n = Notification.builder()
                .user(targetUser)
                .category(NotificationCategory.YOUNG_CHILD)
                .title("Nuôi con nhỏ chờ HCNS duyệt")
                .message(msg)
                .opened(false)
                .relatedEmployee(req.getEmployee())
                .relatedRequestId(req.getId())
                .build();
        persistAndPush(n);
    }

    @Transactional
    public void notifyYoungChildRequestResult(YoungChildRequest req, boolean approved) {
        UserAccount requester = req.getRequestedBy();
        String action = req.isEnabled() ? "bật" : "tắt";
        String msgForRequester = approved
                ? String.format(
                        "HCNS đã duyệt đề xuất %s nuôi con nhỏ cho %s · từ %s đến %s.",
                        action,
                        req.getEmployee().getFullName(),
                        req.getStartDate(),
                        req.getEndDate())
                : String.format(
                        "HCNS từ chối đề xuất %s nuôi con nhỏ cho %s · từ %s đến %s.",
                        action,
                        req.getEmployee().getFullName(),
                        req.getStartDate(),
                        req.getEndDate());
        if (requester != null) {
            saveNotification(
                    requester,
                    NotificationCategory.YOUNG_CHILD,
                    approved ? "Nuôi con nhỏ đã duyệt" : "Nuôi con nhỏ bị từ chối",
                    msgForRequester,
                    req.getEmployee(),
                    req.getId());
        }
        String msgForEmployee = approved
                ? String.format(
                        "HCNS đã duyệt %s chế độ nuôi con nhỏ cho bạn · từ %s đến %s.",
                        action,
                        req.getStartDate(),
                        req.getEndDate())
                : String.format(
                        "HCNS đã từ chối đề xuất %s chế độ nuôi con nhỏ cho bạn · từ %s đến %s.",
                        action,
                        req.getStartDate(),
                        req.getEndDate());
        notifyEmployee(
                req.getEmployee(),
                requester,
                NotificationCategory.YOUNG_CHILD,
                approved ? "Chế độ nuôi con nhỏ đã duyệt" : "Chế độ nuôi con nhỏ bị từ chối",
                msgForEmployee,
                req.getId());
    }

    @Transactional
    public void notifyYoungChildRequestSubmittedToEmployee(YoungChildRequest req) {
        String requester = req.getRequestedBy() != null ? req.getRequestedBy().getUsername() : "Trưởng khoa";
        String action = req.isEnabled() ? "bật" : "tắt";
        notifyEmployee(
                req.getEmployee(),
                req.getRequestedBy(),
                NotificationCategory.YOUNG_CHILD,
                "Đề xuất nuôi con nhỏ",
                String.format(
                        "%s đã đề xuất %s chế độ nuôi con nhỏ cho bạn · từ %s đến %s — đang chờ HCNS duyệt.",
                        requester,
                        action,
                        req.getStartDate(),
                        req.getEndDate()),
                req.getId());
    }

    @Transactional
    public void notifyShiftConfigChangePending(UserAccount targetUser, ShiftConfigChangeRequest req) {
        String msg = String.format(
                "%s đề xuất chỉnh ca sáng/chiều (%s) cho %s · sáng %s–%s, chiều %s–%s. Vui lòng duyệt tại mục Đơn.",
                req.getRequestedBy() != null ? req.getRequestedBy().getUsername() : "Trưởng",
                ShiftConfigChangeRequestService.seasonLabel(req.getSeason()),
                req.getEmployee().getFullName(),
                req.getMorningStart(),
                req.getMorningEnd(),
                req.getAfternoonStart(),
                req.getAfternoonEnd());
        Notification n = Notification.builder()
                .user(targetUser)
                .category(NotificationCategory.SHIFT_CONFIG_CHANGE)
                .title("Chỉnh ca sáng/chiều chờ HCNS duyệt")
                .message(msg)
                .opened(false)
                .relatedEmployee(req.getEmployee())
                .relatedRequestId(req.getId())
                .build();
        persistAndPush(n);
    }

    @Transactional
    public void notifyShiftConfigChangeResult(ShiftConfigChangeRequest req, boolean approved) {
        UserAccount requester = req.getRequestedBy();
        String season = ShiftConfigChangeRequestService.seasonLabel(req.getSeason());
        String msgForRequester = approved
                ? String.format(
                        "HCNS đã duyệt đề xuất chỉnh ca sáng/chiều (%s) cho %s · sáng %s–%s, chiều %s–%s.",
                        season,
                        req.getEmployee().getFullName(),
                        req.getMorningStart(),
                        req.getMorningEnd(),
                        req.getAfternoonStart(),
                        req.getAfternoonEnd())
                : String.format(
                        "HCNS từ chối đề xuất chỉnh ca sáng/chiều (%s) cho %s.",
                        season,
                        req.getEmployee().getFullName());
        if (requester != null) {
            saveNotification(
                    requester,
                    NotificationCategory.SHIFT_CONFIG_CHANGE,
                    approved ? "Chỉnh ca đã duyệt" : "Chỉnh ca bị từ chối",
                    msgForRequester,
                    req.getEmployee(),
                    req.getId());
        }
        String msgForEmployee = approved
                ? String.format(
                        "HCNS đã duyệt cấu hình ca sáng/chiều (%s) của bạn · sáng %s–%s, chiều %s–%s.",
                        season,
                        req.getMorningStart(),
                        req.getMorningEnd(),
                        req.getAfternoonStart(),
                        req.getAfternoonEnd())
                : String.format(
                        "Đề xuất chỉnh ca sáng/chiều (%s) của bạn đã bị từ chối.",
                        season);
        notifyEmployee(
                req.getEmployee(),
                req.getRequestedBy(),
                NotificationCategory.SHIFT_CONFIG_CHANGE,
                approved ? "Ca làm việc đã cập nhật" : "Đề xuất chỉnh ca bị từ chối",
                msgForEmployee,
                req.getId());
    }

    @Transactional
    public void notifyShiftConfigChangeSubmittedToEmployee(ShiftConfigChangeRequest req) {
        String requester = req.getRequestedBy() != null ? req.getRequestedBy().getUsername() : "Trưởng khoa";
        String season = ShiftConfigChangeRequestService.seasonLabel(req.getSeason());
        notifyEmployee(
                req.getEmployee(),
                req.getRequestedBy(),
                NotificationCategory.SHIFT_CONFIG_CHANGE,
                "Đề xuất chỉnh ca sáng/chiều",
                String.format(
                        "%s đã đề xuất chỉnh ca sáng/chiều (%s) cho bạn · sáng %s–%s, chiều %s–%s — đang chờ HCNS duyệt.",
                        requester,
                        season,
                        req.getMorningStart(),
                        req.getMorningEnd(),
                        req.getAfternoonStart(),
                        req.getAfternoonEnd()),
                req.getId());
    }

    @Transactional
    public void notifyTrainingProposalPendingHr(UserAccount targetUser, TrainingProposalRequest req) {
        String msg = String.format(
                "%s đề xuất cử %s đi đào tạo «%s». Vui lòng duyệt tại mục Đơn.",
                req.getRequestedBy() != null ? req.getRequestedBy().getUsername() : "Trưởng",
                req.getEmployee().getFullName(),
                req.getCourseName());
        Notification n = Notification.builder()
                .user(targetUser)
                .category(NotificationCategory.TRAINING_PROPOSAL)
                .title("Đề xuất đào tạo chờ HCNS duyệt")
                .message(msg)
                .opened(false)
                .relatedEmployee(req.getEmployee())
                .relatedRequestId(req.getId())
                .build();
        persistAndPush(n);
    }

    @Transactional
    public void notifyTrainingProposalPendingDirector(UserAccount targetUser, TrainingProposalRequest req) {
        String msg = String.format(
                "HCNS đã duyệt đề xuất cử %s đi đào tạo «%s». Vui lòng duyệt tại mục Đơn.",
                req.getEmployee().getFullName(),
                req.getCourseName());
        Notification n = Notification.builder()
                .user(targetUser)
                .category(NotificationCategory.TRAINING_PROPOSAL)
                .title("Đề xuất đào tạo chờ Giám đốc duyệt")
                .message(msg)
                .opened(false)
                .relatedEmployee(req.getEmployee())
                .relatedRequestId(req.getId())
                .build();
        persistAndPush(n);
    }

    @Transactional
    public void notifyTrainingProposalForwardedToDirector(TrainingProposalRequest req) {
        if (req.getRequestedBy() == null) {
            return;
        }
        Notification n = Notification.builder()
                .user(req.getRequestedBy())
                .category(NotificationCategory.TRAINING_PROPOSAL)
                .title("Đề xuất đào tạo đã gửi Giám đốc")
                .message(String.format(
                        "HCNS đã duyệt đề xuất cử %s đi đào tạo «%s» — đang chờ Giám đốc.",
                        req.getEmployee().getFullName(),
                        req.getCourseName()))
                .opened(false)
                .relatedEmployee(req.getEmployee())
                .relatedRequestId(req.getId())
                .build();
        persistAndPush(n);
    }

    @Transactional
    public void notifyTrainingProposalResult(TrainingProposalRequest req, boolean approved, String byRole) {
        UserAccount requester = req.getRequestedBy();
        String msgForRequester = approved
                ? String.format(
                        "%s đã duyệt đề xuất cử %s đi đào tạo «%s».",
                        byRole,
                        req.getEmployee().getFullName(),
                        req.getCourseName())
                : String.format(
                        "%s từ chối đề xuất cử %s đi đào tạo «%s».",
                        byRole,
                        req.getEmployee().getFullName(),
                        req.getCourseName());
        if (requester != null) {
            saveNotification(
                    requester,
                    NotificationCategory.TRAINING_PROPOSAL,
                    approved ? "Đề xuất đào tạo đã duyệt" : "Đề xuất đào tạo bị từ chối",
                    msgForRequester,
                    req.getEmployee());
        }
        String msgForEmployee = approved
                ? String.format("%s đã duyệt đề xuất cử bạn đi đào tạo «%s».", byRole, req.getCourseName())
                : String.format("%s đã từ chối đề xuất cử bạn đi đào tạo «%s».", byRole, req.getCourseName());
        notifyEmployee(
                req.getEmployee(),
                requester,
                NotificationCategory.TRAINING_PROPOSAL,
                approved ? "Đề xuất đào tạo đã duyệt" : "Đề xuất đào tạo bị từ chối",
                msgForEmployee,
                req.getId());
    }

    @Transactional
    public void notifyTrainingProposalSubmittedToEmployee(TrainingProposalRequest req) {
        String requester = req.getRequestedBy() != null ? req.getRequestedBy().getUsername() : "Trưởng khoa";
        notifyEmployee(
                req.getEmployee(),
                req.getRequestedBy(),
                NotificationCategory.TRAINING_PROPOSAL,
                "Bạn được đề xuất đi đào tạo",
                String.format(
                        "%s đã lập phiếu đề xuất cử bạn đi đào tạo «%s» — đang chờ HCNS duyệt.",
                        requester,
                        req.getCourseName()),
                req.getId());
    }

    @Transactional
    public void notifyMainDutyPendingHead(UserAccount targetUser, MainDutyAuthorizationRequest req) {
        String msg = String.format(
                "%s lập đơn trực chính (%s) cho %s. Vui lòng duyệt tại mục Đơn.",
                req.getRequestedBy() != null ? req.getRequestedBy().getUsername() : "Nhân viên",
                formTypeLabel(req.getFormType()),
                req.getEmployee().getFullName());
        Notification n = Notification.builder()
                .user(targetUser)
                .category(NotificationCategory.MAIN_DUTY_AUTHORIZATION)
                .title("Đơn trực chính chờ Trưởng khoa duyệt")
                .message(msg)
                .opened(false)
                .relatedEmployee(req.getEmployee())
                .relatedRequestId(req.getId())
                .build();
        persistAndPush(n);
    }

    @Transactional
    public void notifyMainDutyPendingNursingHead(UserAccount targetUser, MainDutyAuthorizationRequest req) {
        String msg = String.format(
                "Đơn trực chính (%s) của %s chờ Trưởng phòng Điều dưỡng duyệt. Vui lòng xử lý tại mục Đơn.",
                formTypeLabel(req.getFormType()),
                req.getEmployee().getFullName());
        Notification n = Notification.builder()
                .user(targetUser)
                .category(NotificationCategory.MAIN_DUTY_AUTHORIZATION)
                .title("Đơn trực chính chờ Trưởng phòng Điều dưỡng duyệt")
                .message(msg)
                .opened(false)
                .relatedEmployee(req.getEmployee())
                .relatedRequestId(req.getId())
                .build();
        persistAndPush(n);
    }

    @Transactional
    public void notifyMainDutyPendingHr(UserAccount targetUser, MainDutyAuthorizationRequest req) {
        String msg = String.format(
                "Đơn trực chính (%s) của %s chờ HCNS duyệt. Vui lòng xử lý tại mục Đơn.",
                formTypeLabel(req.getFormType()),
                req.getEmployee().getFullName());
        Notification n = Notification.builder()
                .user(targetUser)
                .category(NotificationCategory.MAIN_DUTY_AUTHORIZATION)
                .title("Đơn trực chính chờ HCNS duyệt")
                .message(msg)
                .opened(false)
                .relatedEmployee(req.getEmployee())
                .relatedRequestId(req.getId())
                .build();
        persistAndPush(n);
    }

    @Transactional
    public void notifyMainDutyPendingDirector(UserAccount targetUser, MainDutyAuthorizationRequest req) {
        String msg = String.format(
                "Đơn trực chính (%s) của %s chờ Giám đốc duyệt. Vui lòng xử lý tại mục Đơn.",
                formTypeLabel(req.getFormType()),
                req.getEmployee().getFullName());
        Notification n = Notification.builder()
                .user(targetUser)
                .category(NotificationCategory.MAIN_DUTY_AUTHORIZATION)
                .title("Đơn trực chính chờ Giám đốc duyệt")
                .message(msg)
                .opened(false)
                .relatedEmployee(req.getEmployee())
                .relatedRequestId(req.getId())
                .build();
        persistAndPush(n);
    }

    @Transactional
    public void notifyMainDutyForwarded(MainDutyAuthorizationRequest req) {
        if (req.getRequestedBy() == null) {
            return;
        }
        Notification n = Notification.builder()
                .user(req.getRequestedBy())
                .category(NotificationCategory.MAIN_DUTY_AUTHORIZATION)
                .title("Đơn trực chính đã gửi Giám đốc")
                .message(String.format(
                        "Đơn trực chính (%s) của %s đã gửi Giám đốc — đang chờ duyệt.",
                        formTypeLabel(req.getFormType()),
                        req.getEmployee().getFullName()))
                .opened(false)
                .relatedEmployee(req.getEmployee())
                .relatedRequestId(req.getId())
                .build();
        persistAndPush(n);
    }

    @Transactional
    public void notifyMainDutyResult(MainDutyAuthorizationRequest req, boolean approved, String byRole) {
        UserAccount requester = req.getRequestedBy();
        String msgForRequester = approved
                ? String.format(
                        "%s đã duyệt đơn trực chính (%s) của %s — được phép chọn các ca trực chính.",
                        byRole,
                        formTypeLabel(req.getFormType()),
                        req.getEmployee().getFullName())
                : String.format(
                        "%s từ chối đơn trực chính (%s) của %s.",
                        byRole,
                        formTypeLabel(req.getFormType()),
                        req.getEmployee().getFullName());
        if (requester != null) {
            saveNotification(
                    requester,
                    NotificationCategory.MAIN_DUTY_AUTHORIZATION,
                    approved ? "Đơn trực chính đã duyệt" : "Đơn trực chính bị từ chối",
                    msgForRequester,
                    req.getEmployee());
        }
        String msgForEmployee = approved
                ? String.format(
                        "%s đã duyệt đơn trực chính của bạn — từ ngày %s bạn được chọn các ca trực chính.",
                        byRole,
                        req.getEffectiveFrom())
                : String.format("%s đã từ chối đơn trực chính của bạn.", byRole);
                notifyEmployee(
                req.getEmployee(),
                requester,
                NotificationCategory.MAIN_DUTY_AUTHORIZATION,
                approved ? "Đơn trực chính đã duyệt" : "Đơn trực chính bị từ chối",
                msgForEmployee,
                req.getId());
    }

    @Transactional
    public void notifyNursingEvaluationPendingNursingHead(UserAccount targetUser, NursingEvaluation eval) {
        Notification n = Notification.builder()
                .user(targetUser)
                .category(NotificationCategory.NURSING_EVALUATION)
                .title("Phiếu đánh giá chờ Trưởng phòng Điều dưỡng duyệt")
                .message(String.format(
                        "Phiếu đánh giá tháng %02d/%d của %s (%s) đang chờ Trưởng phòng Điều dưỡng duyệt ký.",
                        eval.getPeriodMonth(),
                        eval.getPeriodYear(),
                        eval.getEmployee().getFullName(),
                        eval.getEmployee().getDepartment() != null
                                ? eval.getEmployee().getDepartment().getName()
                                : ""))
                .opened(false)
                .relatedEmployee(eval.getEmployee())
                .relatedRequestId(eval.getId())
                .build();
        persistAndPush(n);
    }

    @Transactional
    public void notifyNursingEvaluationPendingHr(UserAccount targetUser, NursingEvaluation eval) {
        Notification n = Notification.builder()
                .user(targetUser)
                .category(NotificationCategory.NURSING_EVALUATION)
                .title("Phiếu đánh giá chờ HCNS duyệt")
                .message(String.format(
                        "Phiếu đánh giá tháng %02d/%d của %s đang chờ HCNS duyệt.",
                        eval.getPeriodMonth(),
                        eval.getPeriodYear(),
                        eval.getEmployee().getFullName()))
                .opened(false)
                .relatedEmployee(eval.getEmployee())
                .relatedRequestId(eval.getId())
                .build();
        persistAndPush(n);
    }

    @Transactional
    public void notifyNursingEvaluationPendingDirector(UserAccount targetUser, NursingEvaluation eval) {
        Notification n = Notification.builder()
                .user(targetUser)
                .category(NotificationCategory.NURSING_EVALUATION)
                .title("Phiếu đánh giá chờ Giám đốc duyệt")
                .message(String.format(
                        "Phiếu đánh giá tháng %02d/%d của %s đang chờ Giám đốc duyệt.",
                        eval.getPeriodMonth(),
                        eval.getPeriodYear(),
                        eval.getEmployee().getFullName()))
                .opened(false)
                .relatedEmployee(eval.getEmployee())
                .relatedRequestId(eval.getId())
                .build();
        persistAndPush(n);
    }

    @Transactional
    public void notifyNursingEvaluationResult(NursingEvaluation eval, boolean approved, String byRole) {
        UserAccount requester = eval.getEvaluator();
        if (requester != null) {
            String title = approved ? "Phiếu đánh giá đã duyệt" : "Phiếu đánh giá bị từ chối";
            String msg = approved
                    ? String.format("%s đã duyệt phiếu đánh giá tháng %02d/%d của %s.",
                            byRole, eval.getPeriodMonth(), eval.getPeriodYear(), eval.getEmployee().getFullName())
                    : String.format("%s từ chối phiếu đánh giá tháng %02d/%d của %s.",
                            byRole, eval.getPeriodMonth(), eval.getPeriodYear(), eval.getEmployee().getFullName());
            Notification n = Notification.builder()
                    .user(requester)
                    .category(NotificationCategory.NURSING_EVALUATION)
                    .title(title)
                    .message(msg)
                    .opened(false)
                    .relatedEmployee(eval.getEmployee())
                    .relatedRequestId(eval.getId())
                    .build();
            persistAndPush(n);
        }
        if (approved) {
            notifyEmployee(
                    eval.getEmployee(),
                    requester,
                    NotificationCategory.NURSING_EVALUATION,
                    "Kết quả đánh giá xếp loại",
                    String.format(
                            "Phiếu đánh giá tháng %02d/%d đã được duyệt. Điểm: %s · Xếp loại: %s. Bạn có thể xem chi tiết tại Đánh giá & xếp loại.",
                            eval.getPeriodMonth(),
                            eval.getPeriodYear(),
                            eval.getTotalScore() != null ? eval.getTotalScore().toPlainString() : "—",
                            eval.getOverallGrade() != null ? eval.getOverallGrade() : "—"),
                    eval.getId());
        }
    }

    @Transactional
    public void notifyMainDutySubmittedToEmployee(MainDutyAuthorizationRequest req) {
        String requester = req.getRequestedBy() != null ? req.getRequestedBy().getUsername() : "Trưởng khoa";
        String pendingStep = switch (req.getStatus()) {
            case PENDING_NURSING_HEAD -> "đang chờ Trưởng phòng Điều dưỡng duyệt";
            case PENDING_HR -> "đang chờ HCNS duyệt";
            case PENDING_DIRECTOR -> "đang chờ Giám đốc duyệt";
            default -> "đang chờ Trưởng khoa duyệt";
        };
        notifyEmployee(
                req.getEmployee(),
                req.getRequestedBy(),
                NotificationCategory.MAIN_DUTY_AUTHORIZATION,
                "Đơn được trực chính",
                String.format(
                        "%s đã lập đơn trực chính (%s) cho bạn — %s.",
                        requester,
                        formTypeLabel(req.getFormType()),
                        pendingStep),
                req.getId());
    }

    private static String formTypeLabel(MainDutyFormType formType) {
        if (formType == null) {
            return "CBNV";
        }
        return switch (formType) {
            case DOCTOR -> "Bác sĩ";
            case NURSE -> "Điều dưỡng";
        };
    }

    @Transactional
    public void notifySeminarProposalPendingHr(UserAccount targetUser, SeminarProposalRequest req) {
        String msg = String.format(
                "%s đề xuất cử %s đi hội thảo «%s». Vui lòng duyệt (có công / không công) tại mục Đơn.",
                req.getRequestedBy() != null ? req.getRequestedBy().getUsername() : "Trưởng",
                req.getEmployee().getFullName(),
                req.getSeminarName());
        Notification n = Notification.builder()
                .user(targetUser)
                .category(NotificationCategory.SEMINAR_PROPOSAL)
                .title("Đề xuất hội thảo chờ HCNS duyệt")
                .message(msg)
                .opened(false)
                .relatedEmployee(req.getEmployee())
                .relatedRequestId(req.getId())
                .build();
        persistAndPush(n);
    }

    @Transactional
    public void notifySeminarProposalPendingDirector(UserAccount targetUser, SeminarProposalRequest req) {
        String msg = String.format(
                "%s đề xuất cử %s đi hội thảo «%s». Vui lòng duyệt (có công / không công) tại mục Đơn.",
                req.getRequestedBy() != null ? req.getRequestedBy().getUsername() : "Trưởng",
                req.getEmployee().getFullName(),
                req.getSeminarName());
        Notification n = Notification.builder()
                .user(targetUser)
                .category(NotificationCategory.SEMINAR_PROPOSAL)
                .title("Đề xuất hội thảo chờ Giám đốc duyệt")
                .message(msg)
                .opened(false)
                .relatedEmployee(req.getEmployee())
                .relatedRequestId(req.getId())
                .build();
        persistAndPush(n);
    }

    @Transactional
    public void notifySeminarProposalForwardedToDirector(SeminarProposalRequest req) {
        if (req.getRequestedBy() == null) {
            return;
        }
        Notification n = Notification.builder()
                .user(req.getRequestedBy())
                .category(NotificationCategory.SEMINAR_PROPOSAL)
                .title("Đề xuất hội thảo đã gửi Giám đốc")
                .message(String.format(
                        "Đề xuất cử %s đi hội thảo «%s» đã gửi Giám đốc — đang chờ duyệt.",
                        req.getEmployee().getFullName(),
                        req.getSeminarName()))
                .opened(false)
                .relatedEmployee(req.getEmployee())
                .relatedRequestId(req.getId())
                .build();
        persistAndPush(n);
    }

    @Transactional
    public void notifySeminarProposalResult(SeminarProposalRequest req, boolean approved, String byRole) {
        UserAccount requester = req.getRequestedBy();
        String payNote = "";
        if (approved && req.getWithPay() != null) {
            payNote = Boolean.TRUE.equals(req.getWithPay()) ? " (có công)" : " (không công)";
        }
        if (approved && req.getSupportAmount() != null && !req.getSupportAmount().isBlank()) {
            payNote += " · tiền hỗ trợ " + req.getSupportAmount().trim();
        }
        String msgForRequester = approved
                ? String.format(
                        "%s đã duyệt đề xuất cử %s đi hội thảo «%s»%s.",
                        byRole,
                        req.getEmployee().getFullName(),
                        req.getSeminarName(),
                        payNote)
                : String.format(
                        "%s từ chối đề xuất cử %s đi hội thảo «%s».",
                        byRole,
                        req.getEmployee().getFullName(),
                        req.getSeminarName());
        if (requester != null) {
            saveNotification(
                    requester,
                    NotificationCategory.SEMINAR_PROPOSAL,
                    approved ? "Đề xuất hội thảo đã duyệt" : "Đề xuất hội thảo bị từ chối",
                    msgForRequester,
                    req.getEmployee());
        }
        String msgForEmployee = approved
                ? String.format(
                        "%s đã duyệt đề xuất cử bạn đi hội thảo «%s»%s.",
                        byRole,
                        req.getSeminarName(),
                        payNote)
                : String.format(
                        "%s đã từ chối đề xuất cử bạn đi hội thảo «%s».",
                        byRole,
                        req.getSeminarName());
        notifyEmployee(
                req.getEmployee(),
                requester,
                NotificationCategory.SEMINAR_PROPOSAL,
                approved ? "Đề xuất hội thảo đã duyệt" : "Đề xuất hội thảo bị từ chối",
                msgForEmployee,
                req.getId());
    }

    @Transactional
    public void notifySeminarProposalSubmittedToEmployee(SeminarProposalRequest req) {
        String requester = req.getRequestedBy() != null ? req.getRequestedBy().getUsername() : "Trưởng khoa";
        notifyEmployee(
                req.getEmployee(),
                req.getRequestedBy(),
                NotificationCategory.SEMINAR_PROPOSAL,
                "Bạn được đề xuất đi hội thảo",
                String.format(
                        "%s đã lập phiếu đề xuất cử bạn đi hội thảo «%s» — đang chờ Giám đốc duyệt.",
                        requester,
                        req.getSeminarName()),
                req.getId());
    }

    private void saveNotification(
            UserAccount user,
            NotificationCategory category,
            String title,
            String message,
            Employee relatedEmployee) {
        saveNotification(user, category, title, message, relatedEmployee, null);
    }

    private void saveNotification(
            UserAccount user,
            NotificationCategory category,
            String title,
            String message,
            Employee relatedEmployee,
            Long relatedRequestId) {
        persistAndPush(Notification.builder()
                .user(user)
                .category(category)
                .title(title)
                .message(message)
                .opened(false)
                .relatedEmployee(relatedEmployee)
                .relatedRequestId(relatedRequestId)
                .build());
    }

    private void persistAndPush(Notification n) {
        Notification saved = notificationRepository.save(n);
        PushNotificationService push = pushNotificationService.getIfAvailable();
        if (push != null && push.isReady() && saved.getUser() != null && saved.getUser().getId() != null) {
            push.sendAsync(saved.getUser().getId(), toDto(saved));
        }
    }

    /** Gửi thông báo cho tài khoản nhân viên; bỏ qua nếu trùng người lập đơn. */
    private void notifyEmployee(
            Employee employee,
            UserAccount excludeUser,
            NotificationCategory category,
            String title,
            String message) {
        notifyEmployee(employee, excludeUser, category, title, message, null);
    }

    private void notifyEmployee(
            Employee employee,
            UserAccount excludeUser,
            NotificationCategory category,
            String title,
            String message,
            Long relatedRequestId) {
        if (employee == null || employee.getUser() == null) {
            return;
        }
        UserAccount empUser = employee.getUser();
        if (excludeUser != null && empUser.getId().equals(excludeUser.getId())) {
            return;
        }
        saveNotification(empUser, category, title, message, employee, relatedRequestId);
    }

    private NotificationDto toDto(Notification n) {
        boolean deployment = isDeploymentNotification(n);
        return NotificationDto.builder()
                .id(n.getId())
                .category(n.getCategory())
                .title(deployment ? deploymentTitle(n.getTitle()) : n.getTitle())
                .message(n.getMessage())
                .read(n.isOpened())
                .createdAt(n.getCreatedAt())
                .relatedEmployeeId(n.getRelatedEmployee() != null ? n.getRelatedEmployee().getId() : null)
                .relatedAnnouncementId(
                        n.getRelatedAnnouncement() != null ? n.getRelatedAnnouncement().getId() : null)
                .relatedRequestId(n.getRelatedRequestId())
                .sensitive(isSensitiveCategory(n.getCategory()))
                .actionPath(resolveActionPath(n, deployment))
                .build();
    }

    private boolean isDeploymentNotification(Notification n) {
        if (n.getCategory() != NotificationCategory.ATTENDANCE || n.getRelatedRequestId() == null) {
            return false;
        }
        return attendanceWorkRequestRepository.findById(n.getRelatedRequestId())
                .map(request -> request.getRequestType() == AttendanceRequestType.DEPLOYMENT)
                .orElse(false);
    }

    private static String deploymentTitle(String title) {
        String value = title != null ? title : "";
        if (value.contains("chờ duyệt")) return "Điều động chờ duyệt";
        if (value.contains("đã duyệt")) return "Điều động đã duyệt";
        if (value.contains("bị từ chối")) return "Điều động bị từ chối";
        if (value.contains("đã thu hồi")) return "Điều động đã thu hồi";
        return value.isBlank() ? "Thông báo điều động" : value.replace("Đơn công", "Điều động");
    }

    private static String resolveActionPath(Notification n, boolean deployment) {
        if (n.getCategory() == null) {
            return "/";
        }
        UserRole role = n.getUser() != null ? n.getUser().getRole() : null;
        boolean employeeViewer = role == UserRole.EMPLOYEE;
        Long requestId = n.getRelatedRequestId();
        return switch (n.getCategory()) {
            case ANNOUNCEMENT -> "/";
            case ATTENDANCE -> resolveAttendanceActionPath(n, deployment);
            case DEPARTMENT_TRANSFER -> employeeViewer
                    ? mineRelatedPath("transfer", requestId)
                    : resolveDepartmentTransferActionPath(n, requestId);
            case PROBATION_CONVERSION -> employeeViewer
                    ? mineRelatedPath("probation", requestId)
                    : resolveProbationConversionActionPath(n, requestId);
            case YOUNG_CHILD -> employeeViewer
                    ? mineRelatedPath("young-child", requestId)
                    : approverPath("young-child", requestId);
            case TRAINING_PROPOSAL -> employeeViewer
                    ? mineRelatedPath("training", requestId)
                    : approverPath("training-proposals", requestId);
            case SEMINAR_PROPOSAL -> employeeViewer
                    ? mineRelatedPath("seminar", requestId)
                    : approverPath("seminar-proposals", requestId);
            case MAIN_DUTY_AUTHORIZATION -> employeeViewer
                    ? mineRelatedPath("main-duty", requestId)
                    : approverPath("main-duty", requestId);
            case NURSING_EVALUATION -> requestId != null
                    ? "/evaluations?id=" + requestId
                    : "/evaluations";
            case SHIFT_CONFIG_CHANGE -> employeeViewer
                    ? mineRelatedPath("shift-config", requestId)
                    : approverPath("shift-config", requestId);
            case PAYROLL, SALARY_ADJUSTMENT, SALARY_REVIEW -> "/salary";
            case INTERNAL -> "/profile";
            case SYSTEM -> "/";
        };
    }

    private static String resolveDepartmentTransferActionPath(Notification n, Long requestId) {
        String title = n.getTitle() != null ? n.getTitle() : "";
        if (title.contains("chờ")) {
            return approverPath("transfers", requestId);
        }
        return "/employees/official";
    }

    private static String resolveProbationConversionActionPath(Notification n, Long requestId) {
        String title = n.getTitle() != null ? n.getTitle() : "";
        if (title.contains("lên chính thức") || title.contains("Áp dụng") || title.contains("Đã lên")) {
            return "/employees/official";
        }
        return approverPath("probation-conversions", requestId);
    }

    private static String mineRelatedPath(String kind, Long requestId) {
        if (requestId != null) {
            return "/requests?tab=" + kind + "&id=" + requestId;
        }
        return "/requests?tab=" + kind;
    }

    private static String approverPath(String tab, Long requestId) {
        if (requestId != null) {
            return "/requests?tab=" + tab + "&open=" + requestId;
        }
        return "/requests?tab=" + tab;
    }

    private static String resolveAttendanceActionPath(Notification n, boolean deployment) {
        String title = n.getTitle() != null ? n.getTitle() : "";
        Long requestId = n.getRelatedRequestId();
        if (deployment || title.contains("điều động") || title.contains("Điều động")) {
            return requestId != null
                    ? "/requests?tab=deployments&id=" + requestId
                    : "/requests?tab=deployments";
        }
        if (title.contains("chờ duyệt")) {
            return requestId != null
                    ? "/requests?tab=approve&id=" + requestId
                    : "/requests?tab=approve";
        }
        if (title.contains("Đơn công") || title.contains("nghỉ phép") || title.contains("Nghỉ phép")
                || title.contains("không lương") || title.contains("Không lương")
                || title.contains("công tác") || title.contains("Công tác")) {
            return requestId != null
                    ? "/requests?tab=mine&id=" + requestId
                    : "/requests?tab=mine";
        }
        return requestId != null ? "/work?id=" + requestId : "/work";
    }

    private static boolean isSensitiveCategory(NotificationCategory c) {
        return c == NotificationCategory.PAYROLL
                || c == NotificationCategory.SALARY_ADJUSTMENT
                || c == NotificationCategory.SALARY_REVIEW;
    }
}
