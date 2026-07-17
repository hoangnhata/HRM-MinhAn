package com.minhan.hrm.service;

import com.minhan.hrm.dto.notification.NotificationDto;
import com.minhan.hrm.entity.AttendanceRequestStatus;
import com.minhan.hrm.entity.AttendanceRequestType;
import com.minhan.hrm.entity.AttendanceWorkRequest;
import com.minhan.hrm.entity.DepartmentTransferRequest;
import com.minhan.hrm.entity.Employee;
import com.minhan.hrm.entity.EmployeeStatus;
import com.minhan.hrm.entity.Notification;
import com.minhan.hrm.entity.NotificationCategory;
import com.minhan.hrm.entity.ProbationConversionRequest;
import com.minhan.hrm.entity.UserAccount;
import com.minhan.hrm.entity.UserRole;
import com.minhan.hrm.entity.YoungChildRequest;
import com.minhan.hrm.exception.ApiException;
import com.minhan.hrm.exception.ResourceNotFoundException;
import com.minhan.hrm.repository.NotificationRepository;
import com.minhan.hrm.repository.UserAccountRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
@RequiredArgsConstructor
public class NotificationService {

    private final NotificationRepository notificationRepository;
    private final EmployeeService employeeService;
    private final UserAccountRepository userAccountRepository;

    @Transactional(readOnly = true)
    public List<NotificationDto> listMine() {
        UserAccount u = employeeService.currentUser();
        return notificationRepository.findByUserOrderByCreatedAtDesc(u).stream()
                .map(this::toDto)
                .toList();
    }

    @Transactional(readOnly = true)
    public long countUnread() {
        UserAccount u = employeeService.currentUser();
        return notificationRepository.countByUserAndOpenedFalse(u);
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
        notificationRepository.save(n);
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
        notificationRepository.save(n);
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
        notificationRepository.save(n);
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
        notificationRepository.save(n);
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
        notificationRepository.save(n);
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
                "HEAD".equals(stage) ? "Lãnh đạo" : "HCNS");
        Notification n = Notification.builder()
                .user(targetUser)
                .category(NotificationCategory.ATTENDANCE)
                .title("Đơn công chờ duyệt")
                .message(msg)
                .opened(false)
                .relatedEmployee(req.getEmployee())
                .build();
        notificationRepository.save(n);
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
                .title(approved ? "Đơn công đã duyệt" : "Đơn công bị từ chối")
                .message(msg)
                .opened(false)
                .relatedEmployee(req.getEmployee())
                .build();
        notificationRepository.save(n);
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
        List<UserRole> roles = previousStatus == AttendanceRequestStatus.PENDING_HR
                ? List.of(UserRole.ADMIN, UserRole.HR)
                : List.of(UserRole.ADMIN, UserRole.HEAD_DEPARTMENT, UserRole.HEAD_NURSING);
        userAccountRepository.findByRoleIn(roles).forEach(u -> {
            Notification n = Notification.builder()
                    .user(u)
                    .category(NotificationCategory.ATTENDANCE)
                    .title("Đơn công đã thu hồi")
                    .message(msg)
                    .opened(false)
                    .relatedEmployee(req.getEmployee())
                    .build();
            notificationRepository.save(n);
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
                .build();
        notificationRepository.save(n);
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
                .build();
        notificationRepository.save(n);
    }

    @Transactional
    public void notifyDepartmentTransferResult(DepartmentTransferRequest req, boolean approved) {
        UserAccount requester = req.getRequestedBy();
        if (requester == null) {
            return;
        }
        String msg = approved
                ? String.format(
                        "Giám đốc đã duyệt luân chuyển %s → «%s». Hệ thống chuyển phòng ban vào ngày %s.",
                        req.getEmployee().getFullName(),
                        req.getToDepartment().getName(),
                        req.getEffectiveDate())
                : String.format(
                        "Giám đốc từ chối luân chuyển %s → «%s».",
                        req.getEmployee().getFullName(),
                        req.getToDepartment().getName());
        Notification n = Notification.builder()
                .user(requester)
                .category(NotificationCategory.DEPARTMENT_TRANSFER)
                .title(approved ? "Luân chuyển đã duyệt" : "Luân chuyển bị từ chối")
                .message(msg)
                .opened(false)
                .relatedEmployee(req.getEmployee())
                .build();
        notificationRepository.save(n);
    }

    @Transactional
    public void notifyDepartmentTransferApplied(DepartmentTransferRequest req) {
        String msg = String.format(
                "Từ ngày %s bạn được luân chuyển sang «%s».",
                req.getEffectiveDate(),
                req.getToDepartment().getName());
        if (req.getEmployee().getUser() != null) {
            Notification toEmp = Notification.builder()
                    .user(req.getEmployee().getUser())
                    .category(NotificationCategory.DEPARTMENT_TRANSFER)
                    .title("Đã luân chuyển phòng ban")
                    .message(msg)
                    .opened(false)
                    .relatedEmployee(req.getEmployee())
                    .build();
            notificationRepository.save(toEmp);
        }
        if (req.getRequestedBy() != null) {
            Notification toHr = Notification.builder()
                    .user(req.getRequestedBy())
                    .category(NotificationCategory.DEPARTMENT_TRANSFER)
                    .title("Đã áp dụng luân chuyển")
                    .message(String.format(
                            "Đã chuyển %s sang «%s» theo ngày hiệu lực %s.",
                            req.getEmployee().getFullName(),
                            req.getToDepartment().getName(),
                            req.getEffectiveDate()))
                    .opened(false)
                    .relatedEmployee(req.getEmployee())
                    .build();
            notificationRepository.save(toHr);
        }
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
                .build();
        notificationRepository.save(n);
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
                .build();
        notificationRepository.save(n);
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
                .build();
        notificationRepository.save(n);
    }

    @Transactional
    public void notifyProbationConversionResult(ProbationConversionRequest req, boolean approved, String byRole) {
        UserAccount requester = req.getRequestedBy();
        if (requester == null) {
            return;
        }
        String msg = approved
                ? String.format(
                        "%s đã duyệt chuyển %s lên chính thức. Hệ thống áp dụng vào ngày %s.",
                        byRole,
                        req.getEmployee().getFullName(),
                        req.getOfficialDate())
                : String.format(
                        "%s từ chối đề nghị chuyển %s lên chính thức.",
                        byRole,
                        req.getEmployee().getFullName());
        Notification n = Notification.builder()
                .user(requester)
                .category(NotificationCategory.PROBATION_CONVERSION)
                .title(approved ? "Chuyển chính thức đã duyệt" : "Chuyển chính thức bị từ chối")
                .message(msg)
                .opened(false)
                .relatedEmployee(req.getEmployee())
                .build();
        notificationRepository.save(n);
    }

    @Transactional
    public void notifyProbationConversionApplied(ProbationConversionRequest req) {
        String msg = String.format(
                "Từ ngày %s bạn được chuyển lên chính thức.",
                req.getOfficialDate());
        if (req.getEmployee().getUser() != null) {
            Notification toEmp = Notification.builder()
                    .user(req.getEmployee().getUser())
                    .category(NotificationCategory.PROBATION_CONVERSION)
                    .title("Đã lên chính thức")
                    .message(msg)
                    .opened(false)
                    .relatedEmployee(req.getEmployee())
                    .build();
            notificationRepository.save(toEmp);
        }
        if (req.getRequestedBy() != null) {
            Notification toRequester = Notification.builder()
                    .user(req.getRequestedBy())
                    .category(NotificationCategory.PROBATION_CONVERSION)
                    .title("Đã áp dụng chuyển chính thức")
                    .message(String.format(
                            "Đã chuyển %s lên chính thức theo ngày %s.",
                            req.getEmployee().getFullName(),
                            req.getOfficialDate()))
                    .opened(false)
                    .relatedEmployee(req.getEmployee())
                    .build();
            notificationRepository.save(toRequester);
        }
    }

    @Transactional
    public void notifyYoungChildRequestPending(UserAccount targetUser, YoungChildRequest req) {
        String action = req.isEnabled() ? "bật" : "tắt";
        String msg = String.format(
                "%s đề xuất %s chế độ nuôi con nhỏ cho %s · tháng %d/%d. Vui lòng duyệt tại mục Đơn.",
                req.getRequestedBy() != null ? req.getRequestedBy().getUsername() : "Trưởng",
                action,
                req.getEmployee().getFullName(),
                req.getPeriodMonth(),
                req.getPeriodYear());
        Notification n = Notification.builder()
                .user(targetUser)
                .category(NotificationCategory.YOUNG_CHILD)
                .title("Nuôi con nhỏ chờ HCNS duyệt")
                .message(msg)
                .opened(false)
                .relatedEmployee(req.getEmployee())
                .build();
        notificationRepository.save(n);
    }

    @Transactional
    public void notifyYoungChildRequestResult(YoungChildRequest req, boolean approved) {
        if (req.getRequestedBy() == null) {
            return;
        }
        String action = req.isEnabled() ? "bật" : "tắt";
        String msg = approved
                ? String.format(
                        "HCNS đã duyệt đề xuất %s nuôi con nhỏ cho %s · tháng %d/%d.",
                        action,
                        req.getEmployee().getFullName(),
                        req.getPeriodMonth(),
                        req.getPeriodYear())
                : String.format(
                        "HCNS từ chối đề xuất %s nuôi con nhỏ cho %s · tháng %d/%d.",
                        action,
                        req.getEmployee().getFullName(),
                        req.getPeriodMonth(),
                        req.getPeriodYear());
        Notification n = Notification.builder()
                .user(req.getRequestedBy())
                .category(NotificationCategory.YOUNG_CHILD)
                .title(approved ? "Nuôi con nhỏ đã duyệt" : "Nuôi con nhỏ bị từ chối")
                .message(msg)
                .opened(false)
                .relatedEmployee(req.getEmployee())
                .build();
        notificationRepository.save(n);
    }

    private NotificationDto toDto(Notification n) {
        return NotificationDto.builder()
                .id(n.getId())
                .category(n.getCategory())
                .title(n.getTitle())
                .message(n.getMessage())
                .read(n.isOpened())
                .createdAt(n.getCreatedAt())
                .relatedEmployeeId(n.getRelatedEmployee() != null ? n.getRelatedEmployee().getId() : null)
                .relatedAnnouncementId(
                        n.getRelatedAnnouncement() != null ? n.getRelatedAnnouncement().getId() : null)
                .sensitive(isSensitiveCategory(n.getCategory()))
                .actionPath(resolveActionPath(n))
                .build();
    }

    private static String resolveActionPath(Notification n) {
        if (n.getCategory() == null) {
            return "/";
        }
        return switch (n.getCategory()) {
            case ANNOUNCEMENT -> "/";
            case ATTENDANCE -> resolveAttendanceActionPath(n);
            case DEPARTMENT_TRANSFER -> {
                String title = n.getTitle() != null ? n.getTitle() : "";
                yield title.contains("chờ") ? "/requests?tab=transfers" : "/employees/official";
            }
            case PROBATION_CONVERSION -> {
                String title = n.getTitle() != null ? n.getTitle() : "";
                if (title.contains("chờ HCNS")) {
                    yield "/requests?tab=probation-conversions";
                }
                if (title.contains("chờ Giám đốc")) {
                    yield "/requests?tab=probation-conversions";
                }
                if (title.contains("lên chính thức") || title.contains("Áp dụng") || title.contains("Đã lên")) {
                    yield "/employees/official";
                }
                yield "/requests?tab=probation-conversions";
            }
            case YOUNG_CHILD -> "/requests?tab=young-child";
            case PAYROLL, SALARY_ADJUSTMENT, SALARY_REVIEW -> "/salary";
            case INTERNAL -> "/profile";
            case SYSTEM -> "/";
        };
    }

    private static String resolveAttendanceActionPath(Notification n) {
        String title = n.getTitle() != null ? n.getTitle() : "";
        if (title.contains("chờ duyệt")) {
            return "/requests?tab=approve";
        }
        if (title.contains("Đơn công") || title.contains("nghỉ phép") || title.contains("Nghỉ phép")
                || title.contains("không lương") || title.contains("Không lương")
                || title.contains("công tác") || title.contains("Công tác")
                || title.contains("điều động") || title.contains("Điều động")) {
            return title.contains("điều động") || title.contains("Điều động") ? "/work" : "/requests?tab=mine";
        }
        return "/work";
    }

    private static boolean isSensitiveCategory(NotificationCategory c) {
        return c == NotificationCategory.PAYROLL
                || c == NotificationCategory.ATTENDANCE
                || c == NotificationCategory.SALARY_ADJUSTMENT;
    }
}
