package com.minhan.hrm.service;

import com.minhan.hrm.attendance.AttendanceDayProcessor;
import com.minhan.hrm.entity.AttendanceRecord;
import com.minhan.hrm.entity.Employee;
import com.minhan.hrm.entity.EmployeeWorkforceDetails;
import com.minhan.hrm.exception.ApiException;
import com.minhan.hrm.repository.AttendanceRecordRepository;
import com.minhan.hrm.repository.EmployeeWorkforceDetailsRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Slf4j
public class CheckInOutImportService {

    public record PunchRow(int enrollNumber, LocalDateTime timeStr) {}

    private static final Pattern ROW_PATTERN = Pattern.compile(
            "\\(\\s*(\\d+)\\s*,\\s*'(\\d{4}-\\d{2}-\\d{2} \\d{2}:\\d{2}:\\d{2})'\\s*,\\s*'(\\d{4}-\\d{2}-\\d{2})'");
    private static final DateTimeFormatter DT = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss");
    private static final int BATCH_SIZE = 1000;

    private final AttendanceRecordRepository attendanceRecordRepository;
    private final EmployeeWorkforceDetailsRepository workforceDetailsRepository;
    private final AttendanceDayProcessor attendanceDayProcessor;
    private final ContinuousShiftService continuousShiftService;
    private final HolidayWorkDayService holidayWorkDayService;
    private final CheckInOutImportBatchService importBatchService;

    public Map<String, Object> importCheckInOutSql(MultipartFile file) {
        if (file.isEmpty()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "File rỗng");
        }
        String fn = file.getOriginalFilename();
        if (fn == null || !fn.toLowerCase().endsWith(".sql")) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Chỉ hỗ trợ file .sql export từ máy chấm công (CheckInOut)");
        }

        ParseResult parsed = parseSqlFile(file);
        if (parsed.rawRows() == 0) {
            throw new ApiException(HttpStatus.BAD_REQUEST,
                    "Không tìm thấy dòng dữ liệu CheckInOut. File phải là export INSERT INTO CheckInOut.");
        }
        return persistAggregates(loadEmployeeMap(), parsed);
    }

    public Map<String, Object> importPunches(List<PunchRow> punches) {
        if (punches == null || punches.isEmpty()) {
            return Map.of(
                    "rawPunches", 0,
                    "dailyRecords", 0,
                    "upserted", 0,
                    "skippedNoEmployee", 0,
                    "unmappedEnrollCount", 0,
                    "unmappedEnrollNumbers", List.of());
        }
        return persistAggregates(loadEmployeeMap(), aggregatePunches(punches));
    }

    private ParseResult aggregatePunches(List<PunchRow> punches) {
        Map<String, DayAggregate> aggregates = new HashMap<>();
        int rawRows = 0;
        for (PunchRow row : punches) {
            if (row.timeStr() == null) {
                continue;
            }
            rawRows++;
            int enroll = row.enrollNumber();
            LocalDateTime ts = row.timeStr();
            LocalDate date = ts.toLocalDate();
            String key = enroll + "|" + date;
            aggregates.compute(key, (k, agg) -> {
                if (agg == null) {
                    return new DayAggregate(enroll, date, ts);
                }
                agg.addPunch(ts);
                return agg;
            });
        }
        return new ParseResult(rawRows, aggregates);
    }

    private Map<String, Object> persistAggregates(Map<String, Employee> employeeByEnroll, ParseResult parsed) {
        Map<String, DayAggregate> aggregates = parsed.aggregates();
        int rawRows = parsed.rawRows();

        LocalDate minDate = aggregates.values().stream().map(a -> a.workDate).min(LocalDate::compareTo).orElse(LocalDate.now());
        LocalDate maxDate = aggregates.values().stream().map(a -> a.workDate).max(LocalDate::compareTo).orElse(LocalDate.now());

        Set<Long> employeeIds = employeeByEnroll.values().stream().map(Employee::getId).collect(Collectors.toSet());
        Map<String, AttendanceRecord> existingByKey = new HashMap<>();
        if (!employeeIds.isEmpty()) {
            for (AttendanceRecord rec : attendanceRecordRepository.findByEmployeeIdInAndWorkDateBetween(
                    employeeIds, minDate, maxDate)) {
                existingByKey.put(rec.getEmployee().getId() + "|" + rec.getWorkDate(), rec);
            }
        }

        Set<String> continuousMonthKeys =
                continuousShiftService.monthKeysForEmployees(employeeIds, minDate, maxDate);
        Set<LocalDate> holidays = holidayWorkDayService.datesInRange(minDate, maxDate);

        Set<String> unmappedEnrolls = new HashSet<>();
        List<AttendanceRecord> batch = new ArrayList<>(BATCH_SIZE);
        int[] upserted = {0};
        int[] skippedNoEmployee = {0};

        attendanceDayProcessor.runWithContinuousShiftCache(continuousMonthKeys, () ->
                attendanceDayProcessor.runWithHolidayCache(holidays, () -> {
            for (DayAggregate agg : aggregates.values()) {
                String enrollKey = String.valueOf(agg.enrollNumber);
                Employee emp = employeeByEnroll.get(enrollKey);
                if (emp == null) {
                    skippedNoEmployee[0]++;
                    unmappedEnrolls.add(enrollKey);
                    continue;
                }

                List<LocalTime> punchTimes = agg.punches.stream().map(LocalDateTime::toLocalTime).sorted().distinct().toList();
                LocalTime checkIn = punchTimes.isEmpty() ? null : punchTimes.get(0);
                LocalTime checkOut = punchTimes.size() < 2 ? checkIn : punchTimes.get(punchTimes.size() - 1);
                String recKey = emp.getId() + "|" + agg.workDate;

                AttendanceRecord rec = existingByKey.computeIfAbsent(recKey,
                        k -> AttendanceRecord.builder().employee(emp).workDate(agg.workDate).build());
                rec.setCheckIn(checkIn);
                rec.setCheckOut(checkOut);
                rec.setNote("Đồng bộ máy chấm công");
                rec.setPunchTimesJson(attendanceDayProcessor.writePunches(punchTimes));
                attendanceDayProcessor.applyToRecord(rec);
                batch.add(rec);

                if (batch.size() >= BATCH_SIZE) {
                    importBatchService.saveBatch(new ArrayList<>(batch));
                    upserted[0] += batch.size();
                    batch.clear();
                }
            }
        }));

        if (!batch.isEmpty()) {
            importBatchService.saveBatch(batch);
            upserted[0] += batch.size();
        }

        log.info("CheckInOut import: raw={}, days={}, upserted={}, skipped={}",
                rawRows, aggregates.size(), upserted[0], skippedNoEmployee[0]);

        return Map.of(
                "rawPunches", rawRows,
                "dailyRecords", aggregates.size(),
                "upserted", upserted[0],
                "skippedNoEmployee", skippedNoEmployee[0],
                "unmappedEnrollNumbers", unmappedEnrolls.stream().sorted().limit(50).toList(),
                "unmappedEnrollCount", unmappedEnrolls.size());
    }

    private ParseResult parseSqlFile(MultipartFile file) {
        Map<String, DayAggregate> aggregates = new HashMap<>();
        int rawRows = 0;

        try (BufferedReader reader = new BufferedReader(
                new InputStreamReader(file.getInputStream(), StandardCharsets.UTF_8), 65536)) {
            String line;
            while ((line = reader.readLine()) != null) {
                Matcher m = ROW_PATTERN.matcher(line);
                while (m.find()) {
                    rawRows++;
                    int enroll = Integer.parseInt(m.group(1));
                    LocalDateTime ts = LocalDateTime.parse(m.group(2), DT);
                    LocalDate date = ts.toLocalDate();
                    String key = enroll + "|" + date;
                    aggregates.compute(key, (k, agg) -> {
                        if (agg == null) {
                            return new DayAggregate(enroll, date, ts);
                        }
                        agg.addPunch(ts);
                        return agg;
                    });
                }
            }
        } catch (Exception e) {
            log.error("Import CheckInOut SQL lỗi", e);
            throw new ApiException(HttpStatus.BAD_REQUEST, "Không đọc được file SQL: " + e.getMessage());
        }

        return new ParseResult(rawRows, aggregates);
    }

    private Map<String, Employee> loadEmployeeMap() {
        Map<String, Employee> map = new HashMap<>();
        for (EmployeeWorkforceDetails w : workforceDetailsRepository.findByAttendanceCodeIsNotNull()) {
            if (w.getAttendanceCode() == null || w.getAttendanceCode().isBlank()) {
                continue;
            }
            String code = w.getAttendanceCode().trim();
            map.put(code, w.getEmployee());
            map.putIfAbsent(stripLeadingZeros(code), w.getEmployee());
        }
        return map;
    }

    private static String stripLeadingZeros(String code) {
        String trimmed = code.replaceFirst("^0+(?!$)", "");
        return trimmed.isEmpty() ? "0" : trimmed;
    }

    private record ParseResult(int rawRows, Map<String, DayAggregate> aggregates) {}

    private static final class DayAggregate {
        final int enrollNumber;
        final LocalDate workDate;
        final List<LocalDateTime> punches = new ArrayList<>();

        DayAggregate(int enrollNumber, LocalDate workDate, LocalDateTime first) {
            this.enrollNumber = enrollNumber;
            this.workDate = workDate;
            punches.add(first);
        }

        void addPunch(LocalDateTime ts) {
            punches.add(ts);
        }
    }
}
