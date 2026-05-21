package com.minhan.hrm.service;

import com.minhan.hrm.dto.notification.NotificationDto;
import com.minhan.hrm.entity.Employee;
import com.minhan.hrm.entity.InternalAnnouncement;
import com.minhan.hrm.entity.Notification;
import com.minhan.hrm.entity.NotificationCategory;
import com.minhan.hrm.entity.UserAccount;
import com.minhan.hrm.exception.ApiException;
import com.minhan.hrm.exception.ResourceNotFoundException;
import com.minhan.hrm.repository.InternalAnnouncementRepository;
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
    private final InternalAnnouncementRepository internalAnnouncementRepository;

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
                "Bảng lương kỳ %02d/%d đã được chốt. Vui lòng xem tại mục Công & Lương (chỉ hiển thị trên tài khoản của bạn).",
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

    /**
     * Gửi thông báo app cho mọi tài khoản đang bật (trừ người đăng) khi có thông báo toàn viện mới.
     */
    @Transactional
    public void notifyAllUsersAboutNewAnnouncement(Long announcementId, Long authorUserId) {
        InternalAnnouncement ann = internalAnnouncementRepository.findById(announcementId)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy thông báo"));
        String body = ann.getBody();
        String preview = body.length() > 280 ? body.substring(0, 280) + "…" : body;
        String title = "Thông báo toàn viện: " + ann.getTitle();
        for (UserAccount u : userAccountRepository.findAll()) {
            if (!u.isEnabled()) {
                continue;
            }
            if (authorUserId != null && u.getId().equals(authorUserId)) {
                continue;
            }
            Notification n = Notification.builder()
                    .user(u)
                    .category(NotificationCategory.ANNOUNCEMENT)
                    .title(title)
                    .message(preview)
                    .opened(false)
                    .relatedAnnouncement(ann)
                    .build();
            notificationRepository.save(n);
        }
    }

    @Transactional
    public void notifyAttendancePeriod(UserAccount targetUser, Employee related, int year, int month) {
        String msg = String.format(
                "Bảng công tháng %02d/%d đã cập nhật. Vui lòng xem tại mục Công & Lương.", month, year);
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
                .build();
    }

    private static boolean isSensitiveCategory(NotificationCategory c) {
        return c == NotificationCategory.PAYROLL
                || c == NotificationCategory.ATTENDANCE
                || c == NotificationCategory.SALARY_ADJUSTMENT;
    }
}
