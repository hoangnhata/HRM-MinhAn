package com.minhan.hrm.service;

import com.minhan.hrm.config.HrmProperties;
import com.minhan.hrm.entity.Employee;
import com.minhan.hrm.entity.EmployeeStatus;
import com.minhan.hrm.entity.EmployeeWorkforceDetails;
import com.minhan.hrm.exception.ApiException;
import com.minhan.hrm.repository.EmployeeRepository;
import com.minhan.hrm.repository.EmployeeWorkforceDetailsRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.text.Normalizer;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;

/**
 * Đồng bộ mã chấm công (UserEnrollNumber) từ SQL Server chamcong.dbo.UserInfo
 * vào hồ sơ HRM cho nhân viên còn thiếu mã.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class AttendanceCodeSyncService {

    private final HrmProperties hrmProperties;
    private final EmployeeRepository employeeRepository;
    private final EmployeeWorkforceDetailsRepository workforceDetailsRepository;

    @Autowired(required = false)
    @Qualifier("chamcongJdbcTemplate")
    private JdbcTemplate chamcongJdbc;

    public record ChamcongUser(int enrollNumber, String fullName, LocalDate birthDay) {}

    @Transactional
    public Map<String, Object> syncMissingAttendanceCodes() {
        requireEnabled();

        List<ChamcongUser> deviceUsers = fetchUserInfo();
        if (deviceUsers.isEmpty()) {
            throw new ApiException(HttpStatus.BAD_GATEWAY, "Không đọc được UserInfo từ máy chấm công (bảng trống hoặc lỗi kết nối).");
        }

        Set<String> usedCodes = new HashSet<>();
        for (EmployeeWorkforceDetails w : workforceDetailsRepository.findByAttendanceCodeIsNotNull()) {
            if (w.getAttendanceCode() != null && !w.getAttendanceCode().isBlank()) {
                usedCodes.add(normalizeCode(w.getAttendanceCode()));
            }
        }

        Map<String, List<ChamcongUser>> byName = new HashMap<>();
        for (ChamcongUser u : deviceUsers) {
            String key = foldName(u.fullName());
            if (key.isEmpty()) {
                continue;
            }
            byName.computeIfAbsent(key, k -> new ArrayList<>()).add(u);
        }

        List<Employee> employees = employeeRepository.findAll();
        Map<Long, EmployeeWorkforceDetails> wfByEmp = new HashMap<>();
        for (EmployeeWorkforceDetails w : workforceDetailsRepository.findAll()) {
            wfByEmp.put(w.getEmployeeId(), w);
        }

        int missingBefore = 0;
        int updated = 0;
        int skippedAmbiguous = 0;
        int skippedConflict = 0;
        int skippedNoMatch = 0;
        List<Map<String, Object>> samples = new ArrayList<>();
        List<Map<String, Object>> ambiguous = new ArrayList<>();
        List<Map<String, Object>> unmatched = new ArrayList<>();

        for (Employee emp : employees) {
            if (emp.getStatus() == EmployeeStatus.TERMINATED) {
                continue;
            }
            EmployeeWorkforceDetails wf = wfByEmp.get(emp.getId());
            String existing = wf != null ? wf.getAttendanceCode() : null;
            if (existing != null && !existing.isBlank()) {
                continue;
            }
            missingBefore++;

            String nameKey = foldName(emp.getFullName());
            List<ChamcongUser> candidates = byName.getOrDefault(nameKey, List.of());
            ChamcongUser matched = pickUniqueMatch(emp, candidates);

            if (matched == null) {
                if (candidates.size() > 1) {
                    skippedAmbiguous++;
                    if (ambiguous.size() < 40) {
                        ambiguous.add(Map.of(
                                "employeeId", emp.getId(),
                                "fullName", emp.getFullName(),
                                "candidates", candidates.stream()
                                        .map(c -> c.enrollNumber() + " · " + nullToEmpty(c.fullName()))
                                        .toList()));
                    }
                } else {
                    skippedNoMatch++;
                    if (unmatched.size() < 40) {
                        unmatched.add(Map.of(
                                "employeeId", emp.getId(),
                                "fullName", emp.getFullName()));
                    }
                }
                continue;
            }

            String code = String.valueOf(matched.enrollNumber());
            String codeKey = normalizeCode(code);
            if (usedCodes.contains(codeKey)) {
                skippedConflict++;
                continue;
            }

            if (wf == null) {
                wf = EmployeeWorkforceDetails.builder().employee(emp).build();
            }
            wf.setAttendanceCode(code);
            workforceDetailsRepository.save(wf);
            usedCodes.add(codeKey);
            updated++;

            if (samples.size() < 30) {
                samples.add(Map.of(
                        "employeeId", emp.getId(),
                        "fullName", emp.getFullName(),
                        "attendanceCode", code,
                        "deviceName", nullToEmpty(matched.fullName())));
            }
        }

        log.info("Đồng bộ mã chấm công: missing={}, updated={}, noMatch={}, ambiguous={}, conflict={}",
                missingBefore, updated, skippedNoMatch, skippedAmbiguous, skippedConflict);

        Map<String, Object> result = new LinkedHashMap<>();
        result.put("deviceUsers", deviceUsers.size());
        result.put("missingBefore", missingBefore);
        result.put("updated", updated);
        result.put("skippedNoMatch", skippedNoMatch);
        result.put("skippedAmbiguous", skippedAmbiguous);
        result.put("skippedConflict", skippedConflict);
        result.put("samples", samples);
        result.put("ambiguous", ambiguous);
        result.put("unmatched", unmatched);
        return result;
    }

    private ChamcongUser pickUniqueMatch(Employee emp, List<ChamcongUser> candidates) {
        if (candidates == null || candidates.isEmpty()) {
            return null;
        }
        if (candidates.size() == 1) {
            return candidates.get(0);
        }
        LocalDate dob = emp.getDateOfBirth();
        if (dob == null) {
            return null;
        }
        List<ChamcongUser> byDob = candidates.stream()
                .filter(c -> dob.equals(c.birthDay()))
                .toList();
        if (byDob.size() == 1) {
            return byDob.get(0);
        }
        return null;
    }

    private List<ChamcongUser> fetchUserInfo() {
        // UserBirthDay trên máy chấm công thường là nvarchar — không dùng getDate().
        String sql = """
                SELECT UserEnrollNumber, UserFullName, UserBirthDay
                FROM dbo.UserInfo
                WHERE UserEnrollNumber IS NOT NULL
                """;
        try {
            return chamcongJdbc.query(sql, (rs, rowNum) -> {
                int enroll = rs.getInt("UserEnrollNumber");
                String name = rs.getString("UserFullName");
                LocalDate birth = parseFlexibleDate(rs.getString("UserBirthDay"));
                return new ChamcongUser(enroll, name, birth);
            });
        } catch (Exception e) {
            log.error("Không đọc được dbo.UserInfo từ chamcong", e);
            throw new ApiException(HttpStatus.BAD_GATEWAY, "Không đọc được UserInfo máy chấm công: " + e.getMessage());
        }
    }

    /** Parse ngày sinh máy chấm công (nvarchar / date / datetime). */
    private static LocalDate parseFlexibleDate(String raw) {
        if (raw == null || raw.isBlank()) {
            return null;
        }
        String s = raw.trim();
        if (s.contains(" ")) {
            s = s.split("\\s+")[0];
        }
        List<DateTimeFormatter> fmts = List.of(
                DateTimeFormatter.ISO_LOCAL_DATE,
                DateTimeFormatter.ofPattern("d/M/yyyy"),
                DateTimeFormatter.ofPattern("dd/MM/yyyy"),
                DateTimeFormatter.ofPattern("M/d/yyyy"),
                DateTimeFormatter.ofPattern("yyyy/M/d"),
                DateTimeFormatter.ofPattern("dd-MM-yyyy"),
                DateTimeFormatter.ofPattern("d-M-yyyy"));
        for (DateTimeFormatter f : fmts) {
            try {
                LocalDate d = LocalDate.parse(s, f);
                if (d.getYear() < 1940 || d.getYear() > LocalDate.now().getYear()) {
                    return null;
                }
                return d;
            } catch (Exception ignored) {
                // thử format khác
            }
        }
        return null;
    }

    private void requireEnabled() {
        if (!hrmProperties.getChamcong().isEnabled() || chamcongJdbc == null) {
            throw new ApiException(
                    HttpStatus.SERVICE_UNAVAILABLE,
                    "Chưa bật kết nối máy chấm công (minhan.hrm.chamcong.enabled).");
        }
    }

    static String foldName(String raw) {
        if (raw == null || raw.isBlank()) {
            return "";
        }
        String n = Normalizer.normalize(raw.trim(), Normalizer.Form.NFD)
                .replaceAll("\\p{M}+", "")
                .toLowerCase(Locale.ROOT)
                .replace('đ', 'd')
                .replaceAll("[^a-z0-9\\s]", " ")
                .replaceAll("\\s+", " ")
                .trim();
        // Bỏ hậu tố hay gặp trên máy chấm công
        n = n.replaceAll("\\s+btg$", "").trim();
        return n;
    }

    private static String normalizeCode(String code) {
        String t = code.trim().replaceFirst("^0+(?!$)", "");
        return t.isEmpty() ? "0" : t;
    }

    private static String nullToEmpty(String s) {
        return s == null ? "" : s;
    }
}
