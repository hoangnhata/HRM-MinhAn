package com.minhan.hrm.controller;

import com.minhan.hrm.dto.attendance.AttendanceNotifyRequest;
import com.minhan.hrm.dto.attendance.AttendanceRequest;
import com.minhan.hrm.service.AttendanceService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/v1/attendance")
@RequiredArgsConstructor
@SecurityRequirement(name = "bearerAuth")
@Tag(name = "Attendance", description = "Bảng công")
public class AttendanceController {

    private final AttendanceService attendanceService;

    @GetMapping("/employees/{employeeId}")
    @Operation(summary = "Bảng công theo khoảng ngày")
    public List<Map<String, Object>> range(
            @PathVariable Long employeeId,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to) {
        return attendanceService.listRange(employeeId, from, to);
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    @PreAuthorize("hasRole('ADMIN')")
    @Operation(summary = "Ghi nhận / cập nhật công (ADMIN)")
    public Map<String, Object> upsert(@Valid @RequestBody AttendanceRequest request) {
        return attendanceService.upsert(request);
    }

    @PostMapping("/notify-month")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @PreAuthorize("hasRole('ADMIN')")
    @Operation(summary = "Gửi thông báo bảng công cho nhân viên (sau khi cập nhật kỳ)")
    public void notifyMonth(@Valid @RequestBody AttendanceNotifyRequest request) {
        attendanceService.notifyEmployeeAboutMonth(request.getEmployeeId(), request.getYear(), request.getMonth());
    }
}
