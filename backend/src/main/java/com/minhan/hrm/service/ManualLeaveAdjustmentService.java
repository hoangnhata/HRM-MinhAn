package com.minhan.hrm.service;

import com.minhan.hrm.attendance.LeaveEntitlement;
import com.minhan.hrm.dto.attendance.ManualLeaveAttachDto;
import com.minhan.hrm.entity.AttendanceRequestStatus;
import com.minhan.hrm.entity.AttendanceRequestType;
import com.minhan.hrm.entity.AttendanceShiftScope;
import com.minhan.hrm.entity.AttendanceWorkRequest;
import com.minhan.hrm.entity.Employee;
import com.minhan.hrm.exception.ApiException;
import com.minhan.hrm.repository.AttendanceWorkRequestRepository;
import com.minhan.hrm.repository.EmployeeRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.apache.poi.ss.usermodel.BorderStyle;
import org.apache.poi.ss.usermodel.Cell;
import org.apache.poi.ss.usermodel.CellType;
import org.apache.poi.ss.usermodel.DataFormatter;
import org.apache.poi.ss.usermodel.DateUtil;
import org.apache.poi.ss.usermodel.FillPatternType;
import org.apache.poi.ss.usermodel.HorizontalAlignment;
import org.apache.poi.ss.usermodel.IndexedColors;
import org.apache.poi.ss.usermodel.Row;
import org.apache.poi.ss.usermodel.Sheet;
import org.apache.poi.ss.usermodel.VerticalAlignment;
import org.apache.poi.ss.usermodel.Workbook;
import org.apache.poi.xssf.usermodel.XSSFCellStyle;
import org.apache.poi.xssf.usermodel.XSSFFont;
import org.apache.poi.xssf.usermodel.XSSFWorkbook;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.math.BigDecimal;
import java.text.Normalizer;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.time.format.DateTimeParseException;
import java.time.format.ResolverStyle;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Optional;

/**
 * Admin ghi nhận ngày phép năm đã nghỉ ngoài hệ thống (trước khi triển khai phần mềm) để trừ vào
 * hạn mức 12 ngày. Mỗi lần gắn tạo một đơn LEAVE đã duyệt có marker ở đầu lý do — {@code leaveBalanceFor}
 * tự cộng vào số ngày đã dùng. Hỗ trợ gắn tay và import Excel (Họ tên, CCCD, Từ ngày, Đến ngày, Ghi chú).
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class ManualLeaveAdjustmentService {

    public static final String REASON_MARKER = "[PHÉP NGOÀI HỆ THỐNG]";
    private static final int MAX_DAYS_PER_ENTRY = 60;
    private static final DataFormatter FORMATTER = new DataFormatter(Locale.forLanguageTag("vi-VN"));
    private static final DateTimeFormatter DMY = DateTimeFormatter.ofPattern("dd/MM/uuuu")
            .withResolverStyle(ResolverStyle.STRICT);
    private static final List<DateTimeFormatter> DATE_PATTERNS = List.of(
            DateTimeFormatter.ofPattern("d/M/uuuu").withResolverStyle(ResolverStyle.STRICT),
            DateTimeFormatter.ofPattern("d-M-uuuu").withResolverStyle(ResolverStyle.STRICT),
            DateTimeFormatter.ofPattern("d.M.uuuu").withResolverStyle(ResolverStyle.STRICT),
            DateTimeFormatter.ofPattern("uuuu-M-d").withResolverStyle(ResolverStyle.STRICT),
            DateTimeFormatter.ofPattern("uuuu/M/d").withResolverStyle(ResolverStyle.STRICT));

    private final EmployeeRepository employeeRepository;
    private final AttendanceWorkRequestRepository requestRepository;
    private final AttendanceWorkRequestService workRequestService;
    private final EmployeeService employeeService;

    // ------------------------------------------------------------------ list / manual

    @Transactional(readOnly = true)
    public List<Map<String, Object>> list(int year) {
        LocalDate from = LocalDate.of(year, 1, 1);
        LocalDate to = LocalDate.of(year, 12, 31);
        List<Map<String, Object>> out = new ArrayList<>();
        for (AttendanceWorkRequest r : requestRepository.findManualLeavesOverlapping(REASON_MARKER, from, to)) {
            out.add(toMap(r));
        }
        return out;
    }

    @Transactional
    public Map<String, Object> attachManual(ManualLeaveAttachDto dto) {
        Employee emp = employeeRepository.findById(dto.getEmployeeId())
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "Không tìm thấy nhân viên"));
        validateRange(dto.getFromDate(), dto.getToDate());
        List<AttendanceWorkRequest> conflicts =
                workRequestService.findLeaveConflicts(emp.getId(), dto.getFromDate(), dto.getToDate());
        if (!conflicts.isEmpty()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, conflictMessage(conflicts));
        }
        AttendanceWorkRequest saved = create(emp, dto.getFromDate(), dto.getToDate(), dto.getNote(),
                !Boolean.FALSE.equals(dto.getApplyAttendance()));
        Map<String, Object> m = toMap(saved);
        m.put("balance", workRequestService.leaveBalanceSnapshot(emp, dto.getFromDate().getYear()));
        return m;
    }

    @Transactional
    public Map<String, Object> delete(Long id) {
        AttendanceWorkRequest r = requestRepository.findById(id)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "Không tìm thấy bản ghi phép"));
        if (!isManual(r)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Bản ghi này không phải phép gắn ngoài hệ thống");
        }
        int reverted = workRequestService.revertManualLeaveDays(r);
        Employee emp = r.getEmployee();
        int year = r.getWorkDate().getYear();
        requestRepository.delete(r);
        requestRepository.flush();
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("id", id);
        m.put("revertedDays", reverted);
        m.put("balance", workRequestService.leaveBalanceSnapshot(emp, year));
        return m;
    }

    // ------------------------------------------------------------------ excel

    public byte[] template() {
        try (XSSFWorkbook wb = new XSSFWorkbook(); ByteArrayOutputStream bos = new ByteArrayOutputStream()) {
            XSSFFont bold = wb.createFont();
            bold.setBold(true);
            bold.setColor(IndexedColors.WHITE.getIndex());
            XSSFCellStyle header = wb.createCellStyle();
            header.setFont(bold);
            header.setFillForegroundColor(IndexedColors.DARK_TEAL.getIndex());
            header.setFillPattern(FillPatternType.SOLID_FOREGROUND);
            header.setAlignment(HorizontalAlignment.CENTER);
            border(header);

            XSSFCellStyle text = wb.createCellStyle();
            border(text);
            XSSFCellStyle center = wb.createCellStyle();
            center.setAlignment(HorizontalAlignment.CENTER);
            border(center);
            XSSFCellStyle date = wb.createCellStyle();
            date.setDataFormat(wb.createDataFormat().getFormat("dd/mm/yyyy"));
            date.setAlignment(HorizontalAlignment.CENTER);
            border(date);
            XSSFCellStyle cccdStyle = wb.createCellStyle();
            cccdStyle.setDataFormat(wb.createDataFormat().getFormat("@"));
            cccdStyle.setAlignment(HorizontalAlignment.CENTER);
            border(cccdStyle);

            Sheet sh = wb.createSheet("Phep ngoai he thong");
            String[] heads = {"STT", "Họ tên", "CCCD", "Từ ngày", "Đến ngày", "Ghi chú"};
            Row hr = sh.createRow(0);
            hr.setHeightInPoints(24);
            for (int i = 0; i < heads.length; i++) {
                Cell c = hr.createCell(i);
                c.setCellValue(heads[i]);
                c.setCellStyle(header);
            }
            Object[][] samples = {
                    {"Nguyễn Văn A", "040190001234", LocalDate.of(2026, 3, 2), LocalDate.of(2026, 3, 4),
                            "Nghỉ phép trước khi dùng phần mềm"},
                    {"Trần Thị B", "040195005678", LocalDate.of(2026, 5, 18), LocalDate.of(2026, 5, 18), ""},
            };
            for (int r = 0; r < samples.length; r++) {
                Row row = sh.createRow(r + 1);
                Object[] v = samples[r];
                Cell c0 = row.createCell(0);
                c0.setCellValue(r + 1);
                c0.setCellStyle(center);
                Cell c1 = row.createCell(1);
                c1.setCellValue((String) v[0]);
                c1.setCellStyle(text);
                Cell c2 = row.createCell(2);
                c2.setCellValue((String) v[1]);
                c2.setCellStyle(cccdStyle);
                Cell c3 = row.createCell(3);
                c3.setCellValue((LocalDate) v[2]);
                c3.setCellStyle(date);
                Cell c4 = row.createCell(4);
                c4.setCellValue((LocalDate) v[3]);
                c4.setCellStyle(date);
                Cell c5 = row.createCell(5);
                c5.setCellValue((String) v[4]);
                c5.setCellStyle(text);
            }
            // Định dạng sẵn 200 dòng trống: CCCD dạng chữ (không mất số 0 đầu), ngày dạng dd/mm/yyyy.
            for (int r = samples.length + 1; r <= 200; r++) {
                Row row = sh.createRow(r);
                row.createCell(0).setCellStyle(center);
                row.createCell(1).setCellStyle(text);
                row.createCell(2).setCellStyle(cccdStyle);
                row.createCell(3).setCellStyle(date);
                row.createCell(4).setCellStyle(date);
                row.createCell(5).setCellStyle(text);
            }
            int[] widths = {6, 30, 18, 14, 14, 40};
            for (int i = 0; i < widths.length; i++) {
                sh.setColumnWidth(i, widths[i] * 256);
            }
            sh.createFreezePane(0, 1);

            Sheet guide = wb.createSheet("Huong dan");
            String[] lines = {
                    "HƯỚNG DẪN NHẬP PHÉP ĐÃ NGHỈ NGOÀI HỆ THỐNG",
                    "",
                    "• Mỗi dòng = một đợt nghỉ phép năm liên tục của một nhân viên (Từ ngày → Đến ngày, tính cả ngày đầu và ngày cuối).",
                    "• CCCD dùng để tìm nhân viên trong hệ thống; Họ tên chỉ để đối chiếu (cảnh báo nếu khác).",
                    "• Ngày nhập dạng dd/MM/yyyy (ví dụ 02/03/2026) hoặc định dạng ngày của Excel.",
                    "• Nghỉ 1 ngày: Từ ngày = Đến ngày. Tối đa " + MAX_DAYS_PER_ENTRY + " ngày mỗi dòng, cùng một năm.",
                    "• Dòng trùng với đơn nghỉ đã có trong hệ thống (cùng nhân viên, giao khoảng ngày) sẽ bị bỏ qua.",
                    "• Có thể xoá 2 dòng ví dụ rồi dán dữ liệu thật; giữ nguyên dòng tiêu đề.",
                    "• Số ngày ghi nhận sẽ trừ trực tiếp vào hạn mức phép năm của nhân viên theo năm của ngày nghỉ.",
            };
            XSSFFont tf = wb.createFont();
            tf.setBold(true);
            tf.setFontHeightInPoints((short) 13);
            XSSFCellStyle title = wb.createCellStyle();
            title.setFont(tf);
            for (int i = 0; i < lines.length; i++) {
                Cell c = guide.createRow(i).createCell(0);
                c.setCellValue(lines[i]);
                if (i == 0) {
                    c.setCellStyle(title);
                }
            }
            guide.setColumnWidth(0, 110 * 256);

            wb.write(bos);
            return bos.toByteArray();
        } catch (IOException e) {
            throw new ApiException(HttpStatus.INTERNAL_SERVER_ERROR, "Không tạo được file mẫu: " + e.getMessage());
        }
    }

    /**
     * Đọc file và trả về kết quả từng dòng. {@code apply=false} chỉ kiểm tra (xem trước);
     * {@code apply=true} tạo bản ghi cho các dòng hợp lệ.
     */
    @Transactional
    public Map<String, Object> importExcel(MultipartFile file, boolean apply, boolean applyAttendance) {
        if (file == null || file.isEmpty()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "File rỗng");
        }
        String fn = file.getOriginalFilename();
        if (fn == null || !fn.toLowerCase(Locale.ROOT).endsWith(".xlsx")) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Chỉ hỗ trợ file .xlsx");
        }
        List<Map<String, Object>> rows = new ArrayList<>();
        try (InputStream in = file.getInputStream(); Workbook wb = new XSSFWorkbook(in)) {
            Sheet sheet = null;
            int headerIdx = -1;
            for (int si = 0; si < wb.getNumberOfSheets(); si++) {
                Sheet s = wb.getSheetAt(si);
                int h = findHeaderRow(s);
                if (h >= 0) {
                    sheet = s;
                    headerIdx = h;
                    break;
                }
            }
            if (sheet == null) {
                throw new ApiException(HttpStatus.BAD_REQUEST,
                        "Không tìm thấy dòng tiêu đề (cần các cột: Họ tên, CCCD, Từ ngày, Đến ngày)");
            }
            Map<String, Integer> col = buildHeaderMap(sheet.getRow(headerIdx));
            int nameCol = resolveCol(col, "họ tên", "họ và tên", "ho ten", "tên");
            int cccdCol = resolveCol(col, "cccd", "căn cước", "cmnd", "mã nv", "mã nhân viên");
            int fromCol = resolveCol(col, "từ ngày", "ngày bắt đầu", "bắt đầu", "tu ngay");
            int toCol = resolveCol(col, "đến ngày", "ngày kết thúc", "kết thúc", "den ngay");
            int noteCol = resolveCol(col, "ghi chú", "ghi chu", "lý do");
            if (cccdCol < 0 || fromCol < 0 || toCol < 0) {
                throw new ApiException(HttpStatus.BAD_REQUEST,
                        "Thiếu cột bắt buộc: cần CCCD, Từ ngày, Đến ngày (tải file mẫu để đúng cấu trúc)");
            }

            // Tránh trùng lặp ngay trong file: theo dõi khoảng đã nhận của từng NV.
            Map<Long, List<LocalDate[]>> seen = new LinkedHashMap<>();
            int last = sheet.getLastRowNum();
            for (int r = headerIdx + 1; r <= last; r++) {
                Row row = sheet.getRow(r);
                if (row == null || isRowEmpty(row)) {
                    continue;
                }
                String name = nameCol >= 0 ? cellText(row, nameCol) : "";
                String cccd = normalizeDigits(cellText(row, cccdCol));
                String note = noteCol >= 0 ? cellText(row, noteCol) : "";
                Map<String, Object> res = new LinkedHashMap<>();
                res.put("row", r + 1);
                res.put("name", name);
                res.put("cccd", cccd);
                res.put("note", note);
                rows.add(res);

                LocalDate from = readDate(row, fromCol);
                LocalDate to = readDate(row, toCol);
                res.put("fromDate", from != null ? from.toString() : null);
                res.put("toDate", to != null ? to.toString() : null);
                if (cccd.isEmpty()) {
                    fail(res, "Thiếu CCCD");
                    continue;
                }
                if (from == null || to == null) {
                    fail(res, from == null && to == null
                            ? "Thiếu / sai định dạng Từ ngày và Đến ngày (dd/MM/yyyy)"
                            : from == null
                                    ? "Sai định dạng Từ ngày (dd/MM/yyyy)"
                                    : "Sai định dạng Đến ngày (dd/MM/yyyy)");
                    continue;
                }
                if (to.isBefore(from)) {
                    fail(res, "Đến ngày phải ≥ Từ ngày");
                    continue;
                }
                int days = LeaveEntitlement.calendarDaysInclusive(from, to);
                res.put("days", days);
                if (days > MAX_DAYS_PER_ENTRY) {
                    fail(res, "Một dòng tối đa " + MAX_DAYS_PER_ENTRY + " ngày");
                    continue;
                }
                if (from.getYear() != to.getYear()) {
                    fail(res, "Khoảng ngày phải nằm trong cùng một năm");
                    continue;
                }
                if (from.isAfter(LocalDate.now())) {
                    fail(res, "Chỉ ghi nhận phép đã nghỉ (ngày tương lai)");
                    continue;
                }

                Employee emp = resolveEmployee(cccd).orElse(null);
                if (emp == null) {
                    fail(res, "Không tìm thấy nhân viên có CCCD " + cccd);
                    continue;
                }
                res.put("employeeId", emp.getId());
                res.put("employeeName", emp.getFullName());
                res.put("employeeCode", emp.getEmployeeCode());
                res.put("departmentName", emp.getDepartment() != null ? emp.getDepartment().getName() : "");
                String warn = null;
                if (!name.isBlank() && !sameName(name, emp.getFullName())) {
                    warn = "Họ tên trong file (" + name + ") khác hệ thống (" + emp.getFullName() + ")";
                }
                res.put("warning", warn);

                List<AttendanceWorkRequest> conflicts = workRequestService.findLeaveConflicts(emp.getId(), from, to);
                if (!conflicts.isEmpty()) {
                    res.put("status", "DUPLICATE");
                    res.put("message", conflictMessage(conflicts));
                    continue;
                }
                List<LocalDate[]> ranges = seen.computeIfAbsent(emp.getId(), k -> new ArrayList<>());
                LocalDate f0 = from;
                LocalDate t0 = to;
                boolean dupInFile = ranges.stream().anyMatch(x -> !x[0].isAfter(t0) && !x[1].isBefore(f0));
                if (dupInFile) {
                    res.put("status", "DUPLICATE");
                    res.put("message", "Trùng với dòng khác trong file của cùng nhân viên");
                    continue;
                }
                ranges.add(new LocalDate[]{from, to});

                if (apply) {
                    AttendanceWorkRequest saved = create(emp, from, to, note, applyAttendance);
                    res.put("id", saved.getId());
                    res.put("status", "CREATED");
                    res.put("message", warn != null ? "Đã ghi nhận — " + warn : "Đã ghi nhận");
                } else {
                    res.put("status", "OK");
                    res.put("message", warn != null ? warn : "Sẵn sàng ghi nhận");
                }
            }
        } catch (ApiException e) {
            throw e;
        } catch (Exception e) {
            log.warn("Manual leave import failed", e);
            throw new ApiException(HttpStatus.BAD_REQUEST, "Không đọc được file Excel: " + e.getMessage());
        }

        long ok = rows.stream().filter(x -> "OK".equals(x.get("status"))).count();
        long created = rows.stream().filter(x -> "CREATED".equals(x.get("status"))).count();
        long dup = rows.stream().filter(x -> "DUPLICATE".equals(x.get("status"))).count();
        long err = rows.stream().filter(x -> "ERROR".equals(x.get("status"))).count();
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("applied", apply);
        out.put("total", rows.size());
        out.put("ready", ok);
        out.put("created", created);
        out.put("duplicate", dup);
        out.put("error", err);
        out.put("rows", rows);
        return out;
    }

    // ------------------------------------------------------------------ helpers

    private AttendanceWorkRequest create(Employee emp, LocalDate from, LocalDate to, String note,
                                         boolean applyAttendance) {
        String actor = employeeService.currentUser().getUsername();
        String reason = REASON_MARKER + " " + emp.getFullName() + " nghỉ phép " + DMY.format(from)
                + (to.equals(from) ? "" : " → " + DMY.format(to))
                + " (ghi nhận bởi " + actor + ")"
                + (note != null && !note.isBlank() ? ": " + note.trim() : "");
        AttendanceWorkRequest req = AttendanceWorkRequest.builder()
                .employee(emp)
                .requestType(AttendanceRequestType.LEAVE)
                .workDate(from)
                .endDate(to)
                .shiftScope(AttendanceShiftScope.FULL_DAY)
                .reason(reason)
                .status(AttendanceRequestStatus.APPROVED)
                .hrWaiveForgotFine(false)
                .explanationKeepOriginalTimes(false)
                .build();
        AttendanceWorkRequest saved = requestRepository.save(req);
        int marked = 0;
        if (applyAttendance) {
            marked = workRequestService.applyManualLeaveOnEmptyDays(saved);
        }
        log.info("Manual leave: +{} ngày phép {} ({}) {} → {} bởi {}, đánh dấu bảng công {} ngày",
                LeaveEntitlement.calendarDaysInclusive(from, to), emp.getFullName(),
                emp.getEmployeeCode(), from, to, actor, marked);
        return saved;
    }

    private static void validateRange(LocalDate from, LocalDate to) {
        if (from == null || to == null) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Chọn Từ ngày và Đến ngày");
        }
        if (to.isBefore(from)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Đến ngày phải ≥ Từ ngày");
        }
        if (from.getYear() != to.getYear()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Khoảng ngày phải nằm trong cùng một năm");
        }
        if (LeaveEntitlement.calendarDaysInclusive(from, to) > MAX_DAYS_PER_ENTRY) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Mỗi lần gắn tối đa " + MAX_DAYS_PER_ENTRY + " ngày");
        }
        if (from.isAfter(LocalDate.now())) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Chỉ ghi nhận phép đã nghỉ (không chọn ngày tương lai)");
        }
    }

    private static String conflictMessage(List<AttendanceWorkRequest> conflicts) {
        AttendanceWorkRequest c = conflicts.get(0);
        String type = switch (c.getRequestType()) {
            case LEAVE -> isManual(c) ? "phép đã gắn" : "đơn nghỉ phép";
            case UNPAID_LEAVE -> "đơn nghỉ không lương";
            case PERSONAL_LEAVE -> "đơn nghỉ chế độ";
            case BUSINESS_TRIP -> "đơn công tác";
            default -> "đơn";
        };
        LocalDate f = c.getWorkDate();
        LocalDate t = c.getEndDate() != null ? c.getEndDate() : f;
        boolean approved = c.getStatus() == AttendanceRequestStatus.APPROVED
                || c.getStatus() == AttendanceRequestStatus.APPROVED_NO_FINE;
        return "Trùng với " + type + " " + DMY.format(f) + (t.equals(f) ? "" : " → " + DMY.format(t))
                + (approved ? " đã duyệt" : " đang chờ duyệt");
    }

    private static boolean isManual(AttendanceWorkRequest r) {
        return r.getRequestType() == AttendanceRequestType.LEAVE
                && r.getReason() != null && r.getReason().startsWith(REASON_MARKER);
    }

    private Optional<Employee> resolveEmployee(String cccd) {
        Optional<Employee> byId = employeeRepository.findByIdCardNumber(cccd);
        if (byId.isPresent()) {
            return byId;
        }
        return employeeRepository.findByEmployeeCode(cccd);
    }

    private Map<String, Object> toMap(AttendanceWorkRequest r) {
        Employee e = r.getEmployee();
        LocalDate from = r.getWorkDate();
        LocalDate to = r.getEndDate() != null ? r.getEndDate() : from;
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("id", r.getId());
        m.put("employeeId", e.getId());
        m.put("employeeName", e.getFullName());
        m.put("employeeCode", e.getEmployeeCode());
        m.put("idCardNumber", e.getIdCardNumber());
        m.put("departmentName", e.getDepartment() != null ? e.getDepartment().getName() : "");
        m.put("fromDate", from.toString());
        m.put("toDate", to.toString());
        m.put("days", LeaveEntitlement.calendarDaysInclusive(from, to));
        m.put("note", noteOf(r.getReason()));
        m.put("createdBy", actorOf(r.getReason()));
        m.put("createdAt", r.getCreatedAt() != null ? r.getCreatedAt().toString() : null);
        return m;
    }

    /** Phần ghi chú tự do sau "(ghi nhận bởi …): ". */
    private static String noteOf(String reason) {
        if (reason == null) {
            return "";
        }
        int idx = reason.indexOf("): ");
        return idx >= 0 ? reason.substring(idx + 3).trim() : "";
    }

    private static String actorOf(String reason) {
        if (reason == null) {
            return "";
        }
        int a = reason.indexOf("(ghi nhận bởi ");
        if (a < 0) {
            return "";
        }
        int b = reason.indexOf(')', a);
        return b > a ? reason.substring(a + "(ghi nhận bởi ".length(), b) : "";
    }

    private static void fail(Map<String, Object> res, String msg) {
        res.put("status", "ERROR");
        res.put("message", msg);
    }

    private static String normalizeDigits(String s) {
        if (s == null) {
            return "";
        }
        String t = s.replaceAll("[\\s.'\\-]", "");
        // Excel có thể trả về "4,0190001234E10" khi ô CCCD bị đọc là số.
        String sci = s.trim().replace(',', '.');
        if (sci.matches("\\d+(\\.\\d+)?E\\+?\\d+")) {
            try {
                t = new BigDecimal(sci).toPlainString();
            } catch (NumberFormatException ignored) {
                // giữ nguyên
            }
        }
        return t;
    }

    private static boolean sameName(String a, String b) {
        return fold(a).equals(fold(b));
    }

    private static String fold(String s) {
        String n = Normalizer.normalize(s == null ? "" : s, Normalizer.Form.NFD)
                .replaceAll("\\p{M}+", "")
                .replace('đ', 'd').replace('Đ', 'D')
                .toLowerCase(Locale.ROOT);
        return n.replaceAll("\\s+", " ").trim();
    }

    private static LocalDate readDate(Row row, int col) {
        Cell cell = row.getCell(col);
        if (cell == null) {
            return null;
        }
        try {
            CellType type = cell.getCellType() == CellType.FORMULA
                    ? cell.getCachedFormulaResultType() : cell.getCellType();
            if (type == CellType.NUMERIC) {
                if (DateUtil.isCellDateFormatted(cell)) {
                    return cell.getLocalDateTimeCellValue().toLocalDate();
                }
                double v = cell.getNumericCellValue();
                if (v > 20000 && v < 80000) {
                    return DateUtil.getLocalDateTime(v).toLocalDate();
                }
                return null;
            }
        } catch (RuntimeException ignored) {
            // rơi xuống đọc dạng text
        }
        String text = FORMATTER.formatCellValue(cell).trim();
        if (text.isEmpty()) {
            return null;
        }
        String t = text.replaceAll("\\s+", "");
        for (DateTimeFormatter f : DATE_PATTERNS) {
            try {
                return LocalDate.parse(t, f);
            } catch (DateTimeParseException ignored) {
                // thử pattern tiếp theo
            }
        }
        return null;
    }

    private static int findHeaderRow(Sheet sheet) {
        int max = Math.min(sheet.getLastRowNum(), 30);
        for (int r = 0; r <= max; r++) {
            Row row = sheet.getRow(r);
            if (row == null) {
                continue;
            }
            Map<String, Integer> col = buildHeaderMap(row);
            boolean hasCccd = resolveCol(col, "cccd", "căn cước", "cmnd") >= 0;
            boolean hasFrom = resolveCol(col, "từ ngày", "ngày bắt đầu", "bắt đầu") >= 0;
            if (hasCccd && hasFrom) {
                return r;
            }
        }
        return -1;
    }

    private static Map<String, Integer> buildHeaderMap(Row headerRow) {
        Map<String, Integer> map = new LinkedHashMap<>();
        if (headerRow == null) {
            return map;
        }
        short last = headerRow.getLastCellNum();
        for (int c = 0; c < last; c++) {
            Cell cell = headerRow.getCell(c);
            String raw = cell == null ? "" : FORMATTER.formatCellValue(cell).trim();
            if (!raw.isEmpty()) {
                map.putIfAbsent(normalizeHeader(raw), c);
            }
        }
        return map;
    }

    private static String normalizeHeader(String s) {
        return s.toLowerCase(Locale.forLanguageTag("vi-VN"))
                .replace(' ', ' ')
                .replaceAll("\\s+", " ")
                .trim();
    }

    private static int resolveCol(Map<String, Integer> col, String... aliases) {
        for (String a : aliases) {
            Integer c = col.get(normalizeHeader(a));
            if (c != null) {
                return c;
            }
        }
        for (String a : aliases) {
            String sub = normalizeHeader(a);
            for (Map.Entry<String, Integer> e : col.entrySet()) {
                if (e.getKey().contains(sub)) {
                    return e.getValue();
                }
            }
        }
        return -1;
    }

    private static String cellText(Row row, int col) {
        Cell cell = row.getCell(col);
        return cell == null ? "" : FORMATTER.formatCellValue(cell).trim();
    }

    private static boolean isRowEmpty(Row row) {
        short last = row.getLastCellNum();
        for (int c = 0; c < last; c++) {
            Cell cell = row.getCell(c);
            if (cell != null && cell.getCellType() != CellType.BLANK
                    && !FORMATTER.formatCellValue(cell).trim().isEmpty()) {
                return false;
            }
        }
        return true;
    }

    private static void border(XSSFCellStyle st) {
        st.setBorderTop(BorderStyle.THIN);
        st.setBorderBottom(BorderStyle.THIN);
        st.setBorderLeft(BorderStyle.THIN);
        st.setBorderRight(BorderStyle.THIN);
        st.setVerticalAlignment(VerticalAlignment.CENTER);
    }
}
