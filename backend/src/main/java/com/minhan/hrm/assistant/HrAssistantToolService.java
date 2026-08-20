package com.minhan.hrm.assistant;

import com.fasterxml.jackson.databind.JsonNode;
import com.minhan.hrm.attendance.LeaveEntitlement;
import com.minhan.hrm.dto.employee.EmployeeSummaryDto;
import com.minhan.hrm.entity.AttendanceRequestStatus;
import com.minhan.hrm.entity.AttendanceRequestType;
import com.minhan.hrm.entity.Employee;
import com.minhan.hrm.entity.UserAccount;
import com.minhan.hrm.entity.UserRole;
import com.minhan.hrm.exception.ApiException;
import com.minhan.hrm.service.AttendanceService;
import com.minhan.hrm.service.AttendanceShiftScheduleService;
import com.minhan.hrm.service.AttendanceWorkRequestService;
import com.minhan.hrm.service.EmployeeService;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.YearMonth;
import java.time.format.DateTimeParseException;
import java.util.ArrayList;
import java.util.EnumSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;

@Service
@RequiredArgsConstructor
public class HrAssistantToolService {

    private static final Set<AttendanceRequestStatus> PENDING = EnumSet.of(
            AttendanceRequestStatus.PENDING_HEAD,
            AttendanceRequestStatus.PENDING_HR,
            AttendanceRequestStatus.PENDING_DIRECTOR);
    private static final Set<UserRole> CAN_SEARCH_EMPLOYEE = EnumSet.of(
            UserRole.ADMIN, UserRole.HR, UserRole.HR2, UserRole.HEAD_HR, UserRole.DIRECTOR, UserRole.HEAD_DEPARTMENT);
    private static final Set<UserRole> CAN_SEARCH_LEAVE = EnumSet.of(
            UserRole.ADMIN, UserRole.HR, UserRole.HEAD_DEPARTMENT, UserRole.HEAD_HR);

    private enum DataDomain {
        ATTENDANCE,
        LEAVE
    }

    private final EmployeeService employeeService;
    private final AttendanceService attendanceService;
    private final AttendanceShiftScheduleService shiftScheduleService;
    private final AttendanceWorkRequestService workRequestService;

    public Map<String, Object> execute(String toolName, JsonNode args) {
        return switch (toolName) {
            case "get_leave_balance" -> leaveBalance(args);
            case "get_missing_attendance" -> missingAttendance(args);
            case "explain_attendance_day" -> explainAttendanceDay(args);
            case "get_attendance_machine_logs" -> attendanceMachineLogs(args);
            case "get_latest_deployment_request" -> latestDeploymentRequest();
            case "get_week_schedule" -> weekSchedule(args);
            case "get_pending_leave_requests" -> pendingLeaveRequests();
            case "get_leave_policy" -> leavePolicy();
            case "get_forgot_punch_guidance" -> forgotPunchGuidance();
            case "get_usage_guidance" -> usageGuidance(text(args, "topic"));
            default -> throw new ApiException(HttpStatus.BAD_REQUEST, "Công cụ trợ lý không được hỗ trợ");
        };
    }

    private Map<String, Object> leaveBalance(JsonNode args) {
        Integer year = integer(args, "year");
        String employeeQuery = text(args, "employee_query");
        Employee self = employeeService.requireLinkedEmployee();
        Employee target = resolveTarget(employeeQuery, DataDomain.LEAVE);
        Map<String, Object> raw = target.getId().equals(self.getId())
                ? workRequestService.myLeaveBalance(year)
                : workRequestService.employeeLeaveBalance(target.getId(), year);
        return okWithTarget(target, select(raw, "year", "yearsOfService", "entitlementDays", "usedDays",
                "pendingDays", "remainingDays", "overLimit", "warning"));
    }

    private Map<String, Object> missingAttendance(JsonNode args) {
        LocalDate today = LocalDate.now();
        LocalDate from = date(args, "from", YearMonth.from(today).atDay(1));
        LocalDate to = date(args, "to", today);
        validateRange(from, to, 62);
        Employee target = resolveTarget(text(args, "employee_query"), DataDomain.ATTENDANCE);
        List<Map<String, Object>> records = attendanceService.listRange(target.getId(), from, to);
        List<Map<String, Object>> missing = records.stream()
                .filter(this::isMissingAttendance)
                .map(row -> select(row, "workDate", "checkIn", "checkOut", "morningCheckIn", "morningCheckOut",
                        "afternoonCheckIn", "afternoonCheckOut", "forgotShifts", "status", "totalWorkUnits", "note"))
                .toList();
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("from", from.toString());
        data.put("to", to.toString());
        data.put("recordsAvailable", records.size());
        data.put("missingCount", missing.size());
        data.put("missingDays", missing);
        data.put("dataNote", records.isEmpty()
                ? "Không có bản ghi công trong khoảng này; không được suy đoán ngày thiếu."
                : "Chỉ liệt kê ngày hệ thống có bản ghi thể hiện thiếu/quên chấm hoặc vắng.");
        return okWithTarget(target, data);
    }

    private boolean isMissingAttendance(Map<String, Object> row) {
        String forgot = String.valueOf(row.getOrDefault("forgotShifts", "")).trim();
        String status = String.valueOf(row.getOrDefault("status", "")).trim();
        Object units = row.get("totalWorkUnits");
        boolean zeroUnits = units instanceof BigDecimal bd && bd.compareTo(BigDecimal.ZERO) == 0;
        return !forgot.isBlank() || "ABSENT".equalsIgnoreCase(status) || zeroUnits;
    }

    private Map<String, Object> explainAttendanceDay(JsonNode args) {
        LocalDate workDate = requiredDate(args, "date");
        Employee target = resolveTarget(text(args, "employee_query"), DataDomain.ATTENDANCE);
        List<Map<String, Object>> records = attendanceService.listRange(target.getId(), workDate, workDate);
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("date", workDate.toString());
        data.put("dataAvailable", !records.isEmpty());
        if (records.isEmpty()) {
            data.put("dataNote", "Hệ thống chưa có bản ghi công cho ngày này; không đủ dữ liệu để kết luận nguyên nhân.");
        } else {
            data.put("attendance", select(records.get(0), "workDate", "punchTimes", "checkIn", "checkOut",
                    "morningCheckIn", "morningCheckOut", "afternoonCheckIn", "afternoonCheckOut",
                    "morningWorkUnits", "afternoonWorkUnits", "overtimeWorkUnits", "totalWorkUnits",
                    "lateMinutes", "lateMinutesExempt", "forgotShifts", "status", "note"));
        }
        return okWithTarget(target, data);
    }

    private Map<String, Object> attendanceMachineLogs(JsonNode args) {
        LocalDate workDate = requiredDate(args, "date");
        Employee target = resolveTarget(text(args, "employee_query"), DataDomain.ATTENDANCE);
        List<Map<String, Object>> records = attendanceService.listRange(target.getId(), workDate, workDate);
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("date", workDate.toString());
        data.put("source", "Log máy chấm đang lưu và hiển thị trong chi tiết công HRM");
        if (records.isEmpty()) {
            data.put("dataAvailable", false);
            data.put("logCount", 0);
            data.put("machineLogs", List.of());
            data.put("dataNote", "Không có bản ghi công/log máy chấm cho nhân viên trong ngày này.");
            return okWithTarget(target, data);
        }

        Map<String, Object> row = records.get(0);
        Object rawPunches = row.get("punchTimes");
        List<?> punches = rawPunches instanceof List<?> list ? list : List.of();
        data.put("dataAvailable", true);
        data.put("logCount", punches.size());
        data.put("machineLogs", punches);
        data.put("inferredShiftTimes", select(row,
                "morningCheckIn", "morningCheckOut", "afternoonCheckIn", "afternoonCheckOut"));
        data.put("attendanceResult", select(row,
                "morningWorkUnits", "afternoonWorkUnits", "overtimeWorkUnits", "totalWorkUnits",
                "lateMinutes", "forgotShifts", "status"));
        data.put("dataNote", punches.isEmpty()
                ? "Có bản ghi công nhưng không có giờ log máy chấm được lưu. Không được tự suy đoán giờ."
                : "Phải liệt kê đủ tất cả log theo đúng thứ tự; giờ ca sáng/chiều là kết quả hệ thống suy ra từ các log này.");
        return okWithTarget(target, data);
    }

    private Map<String, Object> latestDeploymentRequest() {
        Map<String, Object> latest = workRequestService.myRequests().stream()
                .filter(row -> AttendanceRequestType.DEPLOYMENT.name().equals(row.get("requestType")))
                .findFirst()
                .map(row -> select(row, "requestType", "workDate", "endDate", "requestedStart", "requestedEnd",
                        "shiftScope", "status", "headComment", "hrComment", "directorComment", "createdAt"))
                .orElse(null);
        return Map.of("ok", true, "found", latest != null, "request", latest != null ? latest : Map.of());
    }

    private Map<String, Object> weekSchedule(JsonNode args) {
        LocalDate reference = date(args, "week_reference", LocalDate.now());
        LocalDate monday = reference.with(DayOfWeek.MONDAY);
        Employee target = resolveTarget(text(args, "employee_query"), DataDomain.ATTENDANCE);
        employeeService.assertCanAccessEmployee(target);
        List<Map<String, Object>> days = new ArrayList<>();
        for (int i = 0; i < 7; i++) {
            LocalDate day = monday.plusDays(i);
            Map<String, Object> raw = shiftScheduleService.infoForDate(day, target.getId());
            Map<String, Object> schedule = select(raw, "referenceDate", "seasonLabel", "morningStart", "morningEnd",
                    "afternoonStart", "afternoonEnd", "continuousStart", "continuousEnd", "continuousShift",
                    "continuousLabel", "youngChild", "youngChildLabel", "effectiveDayHours");
            schedule.put("dayOfWeek", day.getDayOfWeek().name());
            days.add(schedule);
        }
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("weekStart", monday.toString());
        data.put("weekEnd", monday.plusDays(6).toString());
        data.put("days", days);
        return okWithTarget(target, data);
    }

    private Map<String, Object> pendingLeaveRequests() {
        List<Map<String, Object>> requests = workRequestService.myRequests().stream()
                .filter(row -> AttendanceRequestType.LEAVE.name().equals(row.get("requestType")))
                .filter(row -> {
                    try {
                        return PENDING.contains(AttendanceRequestStatus.valueOf(String.valueOf(row.get("status"))));
                    } catch (IllegalArgumentException ex) {
                        return false;
                    }
                })
                .map(row -> select(row, "requestType", "workDate", "endDate", "leaveDays", "status", "createdAt"))
                .toList();
        return Map.of("ok", true, "count", requests.size(), "requests", requests);
    }

    private Map<String, Object> leavePolicy() {
        return Map.of(
                "ok", true,
                "source", "Quy tắc đang được cấu hình trong phần mềm HRM",
                "baseDaysPerYear", LeaveEntitlement.BASE_DAYS,
                "seniorityRule", "Cứ đủ 5 năm thâm niên được cộng 1 ngày phép/năm.",
                "countingRule", "Phần mềm hiện tính số ngày trong khoảng nghỉ theo ngày lịch, gồm cả cuối tuần.",
                "warning", "Nếu cần căn cứ pháp lý hoặc quy chế nội bộ đầy đủ, liên hệ Phòng Hành chính - Nhân sự.");
    }

    private Map<String, Object> forgotPunchGuidance() {
        return Map.of(
                "ok", true,
                "steps", List.of(
                        "Vào Công & đơn → Đơn.",
                        "Chọn Tạo đơn → Cập nhật công.",
                        "Chọn đúng ngày, ca bị thiếu và điền giờ chấm thực tế đề nghị bổ sung.",
                        "Nhập lý do, gửi đơn và theo dõi trạng thái duyệt trong danh sách đơn."),
                "note", "Chỉ gửi một đơn đúng với ngày/ca bị thiếu; HR và các cấp duyệt sẽ quyết định công và khoản phạt theo quy định.");
    }

    private Map<String, Object> usageGuidance(String topic) {
        String normalized = topic == null ? "" : topic.toLowerCase(Locale.ROOT);
        UserRole role = employeeService.currentUser().getRole();
        boolean canManageDepartment = role == UserRole.ADMIN || (role != null && role.isHeadDepartment());

        if (normalized.contains("điều động") && (normalized.contains("hàng loạt") || normalized.contains("nhiều"))) {
            if (!canManageDepartment) {
                return guidanceResult(role, "Điều động hàng loạt", false,
                        List.of(),
                        List.of("Chức năng này chỉ dành cho ADMIN hoặc Trưởng khoa/phòng, Điều dưỡng trưởng."));
            }
            String navigation = role == UserRole.ADMIN
                    ? "Công & đơn → Công → Bổ sung hàng loạt → Điều động hàng loạt"
                    : "Công & đơn → Công → Điều động hàng loạt";
            return guidanceResult(role, "Điều động hàng loạt", true,
                    List.of(
                            navigation + ".",
                            "Chọn ngày điều động và khoa/phòng. Hệ thống chỉ tải nhân viên đang làm việc trong phạm vi được quyền quản lý.",
                            "Tìm rồi tick các nhân viên cần điều động; có thể dùng Chọn tất cả.",
                            "Tại Gán nhanh cho đã tick, chọn Ngoài ca hoặc Trong ca, chọn buổi và nhập đúng khung giờ; bấm Áp dụng cho đã tick.",
                            "Kiểm tra và chỉnh riêng hình thức/giờ của từng nhân viên nếu cần.",
                            "Nhập Nội dung điều động dùng chung rồi bấm Gửi điều động cho ... nhân viên; xem kết quả thành công/thất bại từng người."),
                    List.of(
                            "Điều động trong ca có thể chọn ca sáng, ca chiều hoặc cả ngày; được phép chọn một phần giờ nằm trong ca chính.",
                            "Điều động ngoài ca không được trùng giờ ca chính và có thể qua đêm.",
                            "Mỗi nhân viên tạo một đơn riêng, chuyển HCNS rồi Giám đốc duyệt."));
        }
        if (normalized.contains("điều động")) {
            if (!canManageDepartment) {
                return guidanceResult(role, "Lập đơn điều động cho một nhân viên", false,
                        List.of(),
                        List.of("Nhân viên không tự tạo đơn điều động. Chức năng này dành cho ADMIN hoặc Trưởng khoa/phòng, Điều dưỡng trưởng trong phạm vi quản lý."));
            }
            return guidanceResult(role, "Lập đơn điều động cho một nhân viên", true,
                    List.of(
                            "Vào Công & đơn → Công. Không vào màn Đơn → Tạo đơn.",
                            "Chọn đúng khoa/phòng, nhân viên và tháng cần xem.",
                            "Tại dòng ngày cần điều động, ở cột Thao tác bấm biểu tượng hai mũi tên có nhãn Điều động.",
                            "Chọn Trong ca hoặc Ngoài ca. Nếu Trong ca, chọn Ca sáng, Ca chiều hoặc Cả ngày và chỉnh khung giờ nằm trong ca chính; nếu Ngoài ca, nhập giờ bắt đầu/kết thúc không trùng ca chính.",
                            "Nhập Nội dung điều động, kiểm tra phần công ×1,5 rồi bấm Gửi HCNS duyệt."),
                    List.of(
                            "Luồng duyệt: Trưởng khoa/Điều dưỡng trưởng lập → HCNS duyệt → Giám đốc duyệt.",
                            "Điều động trong ca chỉ áp dụng công ×1,5 khi có đủ giờ chấm vào/ra phù hợp.",
                            "Chỉ được chọn nhân viên trong khoa/phòng hoặc bộ phận được phân quyền."));
        }
        if ((normalized.contains("bổ sung") || normalized.contains("công trực") || normalized.contains("quang trung"))
                && (normalized.contains("hàng loạt") || normalized.contains("nhiều"))) {
            if (!canManageDepartment) {
                return guidanceResult(role, "Bổ sung công hàng loạt", false, List.of(),
                        List.of("Chức năng này chỉ dành cho ADMIN hoặc Trưởng khoa/phòng, Điều dưỡng trưởng."));
            }
            String navigation = role == UserRole.ADMIN
                    ? "Công & đơn → Công → Bổ sung hàng loạt → Công trực / Quang Trung"
                    : "Công & đơn → Công → Bổ sung hàng loạt";
            return guidanceResult(role, "Bổ sung công hàng loạt", true,
                    List.of(
                            navigation + ".",
                            "Chọn ngày và khoa/phòng, sau đó chọn các nhân viên cần bổ sung.",
                            "Chọn đúng loại bổ sung và nhập thông tin áp dụng; kiểm tra lại từng nhân viên.",
                            "Gửi và xem kết quả xử lý của từng người."),
                    List.of("Trưởng khoa/phòng và Điều dưỡng trưởng chỉ thao tác trong phạm vi đơn vị được quản lý."));
        }
        if (normalized.contains("thông tầm") || normalized.contains("gắn ca")) {
            if (!canManageDepartment) {
                return guidanceResult(role, "Gắn ca thông tầm", false, List.of(),
                        List.of("Chức năng này chỉ dành cho ADMIN hoặc Trưởng khoa/phòng, Điều dưỡng trưởng."));
            }
            return guidanceResult(role, "Gắn ca thông tầm theo ngày", true,
                    List.of(
                            "Vào Công & đơn → Công, chọn nhân viên và tháng cần xếp ca.",
                            "Tại khối Lịch làm việc hiện tại, bấm cấu hình Ca thông tầm theo ngày.",
                            "Chọn một ca thông tầm đã cấu hình, sau đó bấm từng ngày để gắn hoặc bỏ ca. Có thể dùng Gắn cả tháng theo ca đang chọn.",
                            "Muốn đổi khung giờ của một ngày, chọn ca khác rồi bấm lại ngày đó.",
                            "Kiểm tra số ngày đã chọn và bấm Lưu."),
                    List.of(
                            "Ngày không được chọn vẫn là ca bình thường.",
                            "Nếu chưa có ca thông tầm, cần tạo khung giờ trong Danh mục ca thông tầm trước khi gắn ngày."));
        }
        if (normalized.contains("nuôi con nhỏ")) {
            if (!canManageDepartment) {
                return guidanceResult(role, "Đề xuất chế độ nuôi con nhỏ", false, List.of(),
                        List.of("Nhân viên không tự lập đề xuất này; chức năng hiện dành cho ADMIN hoặc Trưởng khoa/phòng, Điều dưỡng trưởng."));
            }
            return guidanceResult(role, "Đề xuất chế độ nuôi con nhỏ", true,
                    List.of(
                            "Vào Công & đơn → Công, chọn nhân viên và tháng cần áp dụng.",
                            "Trong khối Lịch làm việc hiện tại, tìm mục Nuôi con nhỏ của nhân viên.",
                            "Bấm Tạo đơn áp dụng; nếu chế độ đang bật thì chọn thao tác tạo đề xuất dừng.",
                            "Chọn thời gian áp dụng, nhập lý do đề xuất và bấm Gửi đề xuất."),
                    List.of(
                            "Đề xuất được chuyển HCNS duyệt; khi đang chờ, màn hình hiển thị Đã gửi đề xuất.",
                            "Chế độ giảm 1 giờ/ngày, thời gian áp dụng tối đa 1 năm theo thông tin trên biểu mẫu."));
        }
        if (normalized.contains("đào tạo") || normalized.contains("hội thảo") || normalized.contains("đề xuất")) {
            if (!canManageDepartment) {
                return guidanceResult(role, "Lập phiếu đề xuất nhân sự", false, List.of(),
                        List.of("Các nút lập đề xuất đào tạo, hội thảo và chuyển chính thức hiện dành cho ADMIN hoặc Trưởng khoa/phòng, Điều dưỡng trưởng."));
            }
            return guidanceResult(role, "Lập phiếu đề xuất đào tạo hoặc hội thảo", true,
                    List.of(
                            "Vào Tổ chức → Nhân viên → Chính thức; riêng chuyển thử việc lên chính thức vào Thử việc / Thực tập.",
                            "Tìm nhân viên cần đề xuất. Tại cột Thao tác, bấm biểu tượng Đề xuất đào tạo hoặc Đề xuất hội thảo tương ứng.",
                            "Kiểm tra thông tin nhân viên và khoa/phòng đề xuất; nhập đầy đủ tên khóa học/hội thảo, địa điểm, thời gian, lý do và các thông tin chi phí/mục tiêu nếu biểu mẫu yêu cầu.",
                            "Xác nhận đầy đủ các cam kết bắt buộc rồi bấm Gửi phiếu."),
                    List.of(
                            "Phiếu đào tạo được gửi chờ HCNS duyệt.",
                            "Phiếu hội thảo được gửi theo luồng duyệt hiển thị trên biểu mẫu."));
        }
        if (normalized.contains("chấm") || normalized.contains("công")) {
            return guidanceResult(role, "Công và chấm công", true,
                    List.of("Vào Công & đơn → Công của tôi để xem từng ngày.",
                            "Nếu thiếu ca, vào Công & đơn → Đơn → Tạo đơn → Cập nhật công."), List.of());
        }
        if (normalized.contains("đơn") || normalized.contains("phép")) {
            return guidanceResult(role, "Tạo và theo dõi đơn cá nhân", true,
                    List.of("Vào Công & đơn → Đơn.",
                            "Bấm Tạo đơn và chọn loại đơn cá nhân được hiển thị.",
                            "Theo dõi trạng thái và ý kiến duyệt trong danh sách hoặc chi tiết đơn."),
                    List.of("Đơn điều động không tạo theo đường dẫn này; hãy hỏi riêng “cách lập đơn điều động”."));
        }
        if (normalized.contains("lương")) {
            return Map.of("ok", true, "topic", "Thông tin lương",
                    "guidance", "Vào Lương → Thông tin lương của tôi hoặc Thang bảng lương của tôi. Dữ liệu lương chỉ hiển thị theo quyền tài khoản.");
        }
        if (normalized.contains("hồ sơ") || normalized.contains("cá nhân") || normalized.contains("thông tin")) {
            return Map.of("ok", true, "topic", "Hồ sơ cá nhân",
                    "guidance", "Mở menu tài khoản ở góc trên bên phải → Trang cá nhân. Tại đây bạn có thể xem thông tin liên hệ, khoa/phòng, vai trò và mở hồ sơ nhân viên chi tiết. Chỉ các trường được cấp quyền mới có thể chỉnh sửa.");
        }
        if (normalized.contains("mật khẩu") || normalized.contains("tài khoản")) {
            return Map.of("ok", true, "topic", "Tài khoản và mật khẩu",
                    "guidance", "Mở menu tài khoản ở góc trên bên phải → Trang cá nhân → Đổi mật khẩu. Nhập mật khẩu hiện tại, mật khẩu mới và xác nhận mật khẩu mới rồi chọn Đổi mật khẩu. Không cung cấp mật khẩu cho trợ lý hoặc người khác.");
        }
        if (normalized.contains("chữ ký")) {
            return Map.of("ok", true, "topic", "Chữ ký số",
                    "guidance", "Chữ ký số xuất hiện trong chi tiết đơn sau khi cấp duyệt ký. Nhấn trực tiếp vào ảnh chữ ký để phóng to; trợ lý chỉ hướng dẫn và không thể ký hoặc thay đổi chữ ký thay bạn.");
        }
        if (normalized.contains("đánh giá") || normalized.contains("xếp loại")) {
            return Map.of("ok", true, "topic", "Đánh giá và xếp loại",
                    "guidance", "Vào Công & đơn → Đánh giá & Xếp loại. Chọn đúng kỳ đánh giá để xem nội dung, tiến độ và kết quả theo quyền của tài khoản.");
        }
        if (normalized.contains("lịch") || normalized.contains("ca")) {
            return Map.of("ok", true, "topic", "Lịch và ca làm việc",
                    "guidance", "Vào Công & đơn → Công của tôi, chọn tháng cần xem rồi mở từng ngày để kiểm tra ca, giờ chấm và công được tính. Bạn cũng có thể hỏi trợ lý về lịch làm việc của tuần cụ thể.");
        }
        return Map.of("ok", true, "topic", "Hướng dẫn HRM",
                "guidance", "Hãy nêu rõ chức năng HRM bạn muốn dùng, ví dụ: xem công, tạo đơn nghỉ phép, quên chấm công, điều động hàng loạt, gắn ca thông tầm, hồ sơ cá nhân, chữ ký số, đánh giá xếp loại hoặc thông tin lương.");
    }

    private Map<String, Object> guidanceResult(
            UserRole role,
            String topic,
            boolean availableForRole,
            List<String> steps,
            List<String> notes) {
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("ok", true);
        result.put("source", "Giao diện và phân quyền hiện tại của HRM Minh An");
        result.put("currentRole", role.name());
        result.put("topic", topic);
        result.put("availableForCurrentRole", availableForRole);
        result.put("steps", steps);
        result.put("notes", notes);
        return result;
    }

    private Employee resolveTarget(String query, DataDomain domain) {
        Employee self = employeeService.requireLinkedEmployee();
        String q = query == null ? "" : query.trim();
        if (q.isBlank() || isSelfReference(q)) {
            return self;
        }
        UserAccount caller = employeeService.currentUser();
        Set<UserRole> allowedRoles = domain == DataDomain.LEAVE ? CAN_SEARCH_LEAVE : CAN_SEARCH_EMPLOYEE;
        if (!allowedRoles.contains(caller.getRole())) {
            String message = EmployeeService.isHr2Role(caller) && domain == DataDomain.LEAVE
                    ? "HCNS2 chỉ được tra cứu công toàn viện; hạn mức phép chỉ xem cho chính mình"
                    : "Vai trò của bạn chỉ được hỏi dữ liệu này cho chính mình";
            throw new ApiException(HttpStatus.FORBIDDEN, message);
        }
        Page<EmployeeSummaryDto> matches = employeeService.listForCaller(
                PageRequest.of(0, 10), q, null, null, null, null, null);
        List<EmployeeSummaryDto> content = matches.getContent();
        if (content.isEmpty()) {
            throw new ApiException(HttpStatus.NOT_FOUND, "Không tìm thấy nhân viên trong phạm vi bạn được xem");
        }
        EmployeeSummaryDto selected = content.stream()
                .filter(e -> q.equalsIgnoreCase(e.getEmployeeCode()) || q.equalsIgnoreCase(e.getFullName()))
                .findFirst()
                .orElse(content.size() == 1 ? content.get(0) : null);
        if (selected == null) {
            throw new ApiException(HttpStatus.BAD_REQUEST,
                    "Có nhiều nhân viên phù hợp; vui lòng hỏi bằng họ tên đầy đủ hoặc mã nhân viên");
        }
        Employee target = employeeService.requireEmployeeEntity(selected.getId());
        // HCNS2 chỉ được bỏ qua phạm vi hồ sơ đối với miền công/chấm công.
        // Đây là quyền đọc; mọi API cập nhật vẫn có @PreAuthorize/phân quyền riêng.
        if (!(EmployeeService.isHr2Role(caller) && domain == DataDomain.ATTENDANCE)) {
            employeeService.assertCanAccessEmployee(target);
        }
        return target;
    }

    private boolean isSelfReference(String value) {
        String q = value.toLowerCase(Locale.ROOT);
        return Set.of("tôi", "mình", "bản thân", "của tôi", "của mình", "self", "me").contains(q);
    }

    private Map<String, Object> okWithTarget(Employee target, Map<String, Object> data) {
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("ok", true);
        out.put("employee", Map.of("fullName", target.getFullName()));
        out.putAll(data);
        return out;
    }

    private Map<String, Object> select(Map<String, Object> source, String... keys) {
        Map<String, Object> out = new LinkedHashMap<>();
        for (String key : keys) {
            if (source.containsKey(key)) {
                out.put(key, source.get(key));
            }
        }
        return out;
    }

    private String text(JsonNode args, String name) {
        JsonNode value = args != null ? args.get(name) : null;
        return value == null || value.isNull() ? "" : value.asText("").trim();
    }

    private Integer integer(JsonNode args, String name) {
        JsonNode value = args != null ? args.get(name) : null;
        return value == null || value.isNull() ? null : value.asInt();
    }

    private LocalDate date(JsonNode args, String name, LocalDate defaultValue) {
        String value = text(args, name);
        return value.isBlank() ? defaultValue : parseDate(value, name);
    }

    private LocalDate requiredDate(JsonNode args, String name) {
        String value = text(args, name);
        if (value.isBlank()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Thiếu ngày cần kiểm tra");
        }
        return parseDate(value, name);
    }

    private LocalDate parseDate(String value, String field) {
        try {
            return LocalDate.parse(value);
        } catch (DateTimeParseException ex) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Ngày " + field + " phải theo định dạng YYYY-MM-DD");
        }
    }

    private void validateRange(LocalDate from, LocalDate to, int maxDays) {
        if (to.isBefore(from)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Ngày kết thúc phải từ ngày bắt đầu trở đi");
        }
        if (from.plusDays(maxDays).isBefore(to)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Khoảng thời gian hỏi quá dài");
        }
    }
}
