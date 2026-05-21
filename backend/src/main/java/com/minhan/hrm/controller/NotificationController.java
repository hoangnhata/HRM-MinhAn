package com.minhan.hrm.controller;

import com.minhan.hrm.dto.notification.AdhocNotificationRequest;
import com.minhan.hrm.dto.notification.NotificationDto;
import com.minhan.hrm.entity.Employee;
import com.minhan.hrm.entity.UserAccount;
import com.minhan.hrm.exception.ResourceNotFoundException;
import com.minhan.hrm.repository.UserAccountRepository;
import com.minhan.hrm.service.EmployeeService;
import com.minhan.hrm.service.NotificationService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/v1/notifications")
@RequiredArgsConstructor
@SecurityRequirement(name = "bearerAuth")
@Tag(name = "Notifications", description = "Thông báo lương & nội bộ")
public class NotificationController {

    private final NotificationService notificationService;
    private final UserAccountRepository userAccountRepository;
    private final EmployeeService employeeService;

    @GetMapping
    @Operation(summary = "Thông báo của tôi")
    public List<NotificationDto> mine() {
        return notificationService.listMine();
    }

    @GetMapping("/unread-count")
    @Operation(summary = "Số thông báo chưa đọc")
    public Map<String, Long> unread() {
        return Map.of("count", notificationService.countUnread());
    }

    @PatchMapping("/{id}/read")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @Operation(summary = "Đánh dấu đã đọc")
    public void markRead(@PathVariable Long id) {
        notificationService.markRead(id);
    }

    @PostMapping("/adhoc")
    @ResponseStatus(HttpStatus.CREATED)
    @PreAuthorize("hasRole('ADMIN')")
    @Operation(summary = "Gửi thông báo đột xuất tới user")
    public void adhoc(@Valid @RequestBody AdhocNotificationRequest req) {
        UserAccount target = userAccountRepository.findById(req.getTargetUserId())
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy user đích"));
        Employee related = null;
        if (req.getRelatedEmployeeId() != null) {
            related = employeeService.requireEmployeeEntity(req.getRelatedEmployeeId());
        }
        notificationService.createAdhoc(target, req.getCategory(), req.getTitle(), req.getMessage(), related);
    }
}
