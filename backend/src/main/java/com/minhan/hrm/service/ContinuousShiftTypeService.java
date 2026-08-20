package com.minhan.hrm.service;

import com.minhan.hrm.dto.attendance.ContinuousShiftTypeRequest;
import com.minhan.hrm.entity.ContinuousShiftKind;
import com.minhan.hrm.entity.ContinuousShiftType;
import com.minhan.hrm.exception.ApiException;
import com.minhan.hrm.exception.ResourceNotFoundException;
import com.minhan.hrm.repository.ContinuousShiftTypeRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Duration;
import java.time.LocalTime;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@Service
@RequiredArgsConstructor
public class ContinuousShiftTypeService {

    private static final double MIN_HOURS = 8.0;

    private final ContinuousShiftTypeRepository repository;

    @Transactional(readOnly = true)
    public List<Map<String, Object>> list(boolean activeOnly) {
        List<ContinuousShiftType> rows = activeOnly
                ? repository.findByActiveTrueOrderByNameAsc()
                : repository.findAllByOrderByNameAsc();
        return rows.stream().map(this::toMap).toList();
    }

    @Transactional(readOnly = true)
    public ContinuousShiftType require(Long id) {
        return repository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy khung ca #" + id));
    }

    @PreAuthorize("hasAnyRole('ADMIN','HR')")
    @Transactional
    public Map<String, Object> create(ContinuousShiftTypeRequest req) {
        ContinuousShiftKind kind = resolveKind(req);
        validate(req, kind);
        String name = req.getName().trim();
        // Xóa ca chỉ là ngừng dùng — tạo lại cùng tên thì kích hoạt lại bản ghi cũ.
        ContinuousShiftType existing = repository.findFirstByNameIgnoreCase(name).orElse(null);
        if (existing != null) {
            if (existing.isActive()) {
                throw new ApiException(HttpStatus.CONFLICT, "Tên khung ca đã tồn tại");
            }
            existing.setActive(true);
            existing.setKind(kind);
            applyTimesAndWindows(existing, req, kind);
            return toMap(repository.save(existing));
        }
        ContinuousShiftType row = ContinuousShiftType.builder()
                .name(name)
                .kind(kind)
                .active(req.getActive() == null || req.getActive())
                .build();
        applyTimesAndWindows(row, req, kind);
        return toMap(repository.save(row));
    }

    @PreAuthorize("hasAnyRole('ADMIN','HR')")
    @Transactional
    public Map<String, Object> update(Long id, ContinuousShiftTypeRequest req) {
        ContinuousShiftKind kind = resolveKind(req);
        validate(req, kind);
        ContinuousShiftType row = require(id);
        String name = req.getName().trim();
        if (repository.existsByNameIgnoreCaseAndActiveTrueAndIdNot(name, id)) {
            throw new ApiException(HttpStatus.CONFLICT, "Tên khung ca đã tồn tại");
        }
        // Đổi tên trùng ca đã ngừng dùng → tái sử dụng tên đó (đổi tên bản ghi cũ sang tên tạm)
        ContinuousShiftType inactiveSameName = repository.findFirstByNameIgnoreCase(name).orElse(null);
        if (inactiveSameName != null && !inactiveSameName.getId().equals(id) && !inactiveSameName.isActive()) {
            inactiveSameName.setName(inactiveSameName.getName() + " (cũ #" + inactiveSameName.getId() + ")");
            repository.save(inactiveSameName);
        }
        row.setName(name);
        row.setKind(kind);
        applyTimesAndWindows(row, req, kind);
        if (req.getActive() != null) {
            row.setActive(req.getActive());
        }
        return toMap(repository.save(row));
    }

    @PreAuthorize("hasAnyRole('ADMIN','HR')")
    @Transactional
    public void delete(Long id) {
        ContinuousShiftType row = require(id);
        repository.delete(row);
    }

    /** @deprecated dùng {@link #delete(Long)} — xóa hẳn. */
    @PreAuthorize("hasAnyRole('ADMIN','HR')")
    @Transactional
    public void deactivate(Long id) {
        delete(id);
    }

    private ContinuousShiftKind resolveKind(ContinuousShiftTypeRequest req) {
        return req.getKind() == null ? ContinuousShiftKind.CONTINUOUS : req.getKind();
    }

    private void applyTimesAndWindows(ContinuousShiftType row, ContinuousShiftTypeRequest req, ContinuousShiftKind kind) {
        row.setCheckInBeforeMin(req.getCheckInBeforeMin());
        row.setCheckInAfterMin(req.getCheckInAfterMin());
        row.setCheckOutBeforeMin(req.getCheckOutBeforeMin());
        row.setCheckOutAfterMin(req.getCheckOutAfterMin());
        if (kind == ContinuousShiftKind.SPLIT) {
            row.setMorningStart(req.getMorningStart());
            row.setMorningEnd(req.getMorningEnd());
            row.setAfternoonStart(req.getAfternoonStart());
            row.setAfternoonEnd(req.getAfternoonEnd());
            row.setStartTime(req.getMorningStart());
            row.setEndTime(req.getAfternoonEnd());
            row.setMorningOutBeforeMin(nz(req.getMorningOutBeforeMin(), 60));
            row.setMorningOutAfterMin(nz(req.getMorningOutAfterMin(), 30));
            row.setAfternoonInBeforeMin(nz(req.getAfternoonInBeforeMin(), 30));
            row.setAfternoonInAfterMin(nz(req.getAfternoonInAfterMin(), 60));
        } else {
            row.setStartTime(req.getStartTime());
            row.setEndTime(req.getEndTime());
            row.setMorningStart(null);
            row.setMorningEnd(null);
            row.setAfternoonStart(null);
            row.setAfternoonEnd(null);
            row.setMorningOutBeforeMin(null);
            row.setMorningOutAfterMin(null);
            row.setAfternoonInBeforeMin(null);
            row.setAfternoonInAfterMin(null);
        }
    }

    private void validate(ContinuousShiftTypeRequest req, ContinuousShiftKind kind) {
        if (req.getName() == null || req.getName().isBlank()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Tên ca không được trống");
        }
        if (req.getCheckInBeforeMin() == null || req.getCheckInAfterMin() == null
                || req.getCheckOutBeforeMin() == null || req.getCheckOutAfterMin() == null
                || req.getCheckInBeforeMin() < 0 || req.getCheckInAfterMin() < 0
                || req.getCheckOutBeforeMin() < 0 || req.getCheckOutAfterMin() < 0) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Cửa sổ lấy giờ chấm công không được là số âm");
        }
        if (kind == ContinuousShiftKind.SPLIT) {
            LocalTime ms = req.getMorningStart();
            LocalTime me = req.getMorningEnd();
            LocalTime as = req.getAfternoonStart();
            LocalTime ae = req.getAfternoonEnd();
            if (ms == null || me == null || as == null || ae == null) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "Ca sáng–chiều cần đủ giờ sáng vào/ra và chiều vào/ra");
            }
            if (!ms.isBefore(me) || !as.isBefore(ae)) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "Trong mỗi buổi, giờ vào phải trước giờ ra");
            }
            if (me.isAfter(as)) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "Giờ ra sáng phải trước hoặc bằng giờ vào chiều");
            }
            double hours = hoursBetween(ms, me) + hoursBetween(as, ae);
            if (hours < MIN_HOURS) {
                throw new ApiException(HttpStatus.BAD_REQUEST,
                        "Ca sáng–chiều phải tối thiểu 8 giờ làm việc (hiện " + formatHours(hours) + " giờ)");
            }
            requireNonNegativeOptional(req.getMorningOutBeforeMin(), "Cửa sổ ra sáng");
            requireNonNegativeOptional(req.getMorningOutAfterMin(), "Cửa sổ ra sáng");
            requireNonNegativeOptional(req.getAfternoonInBeforeMin(), "Cửa sổ vào chiều");
            requireNonNegativeOptional(req.getAfternoonInAfterMin(), "Cửa sổ vào chiều");
        } else {
            LocalTime start = req.getStartTime();
            LocalTime end = req.getEndTime();
            if (start == null || end == null || !start.isBefore(end)) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "Giờ vào phải trước giờ ra");
            }
            double hours = hoursBetween(start, end);
            if (hours < MIN_HOURS) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "Ca thông tầm phải tối thiểu 8 giờ");
            }
        }
    }

    private static void requireNonNegativeOptional(Integer v, String label) {
        if (v != null && v < 0) {
            throw new ApiException(HttpStatus.BAD_REQUEST, label + " không được là số âm");
        }
    }

    private static int nz(Integer v, int fallback) {
        return v == null ? fallback : v;
    }

    private static double hoursBetween(LocalTime a, LocalTime b) {
        return Duration.between(a, b).toMinutes() / 60.0;
    }

    private static String formatHours(double hours) {
        if (Math.abs(hours - Math.rint(hours)) < 0.001) {
            return String.valueOf((int) Math.rint(hours));
        }
        return String.format(java.util.Locale.US, "%.1f", hours);
    }

    private Map<String, Object> toMap(ContinuousShiftType row) {
        ContinuousShiftKind kind = row.getKind() == null ? ContinuousShiftKind.CONTINUOUS : row.getKind();
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("id", row.getId());
        m.put("name", row.getName());
        m.put("kind", kind.name());
        m.put("kindLabel", kind == ContinuousShiftKind.SPLIT ? "Ca sáng–chiều" : "Ca thông tầm");
        m.put("startTime", row.getStartTime().toString());
        m.put("endTime", row.getEndTime().toString());
        if (kind == ContinuousShiftKind.SPLIT) {
            m.put("morningStart", row.getMorningStart() != null ? row.getMorningStart().toString() : null);
            m.put("morningEnd", row.getMorningEnd() != null ? row.getMorningEnd().toString() : null);
            m.put("afternoonStart", row.getAfternoonStart() != null ? row.getAfternoonStart().toString() : null);
            m.put("afternoonEnd", row.getAfternoonEnd() != null ? row.getAfternoonEnd().toString() : null);
            m.put("morningOutBeforeMin", nz(row.getMorningOutBeforeMin(), 60));
            m.put("morningOutAfterMin", nz(row.getMorningOutAfterMin(), 30));
            m.put("afternoonInBeforeMin", nz(row.getAfternoonInBeforeMin(), 30));
            m.put("afternoonInAfterMin", nz(row.getAfternoonInAfterMin(), 60));
            double hours = hoursBetween(row.getMorningStart(), row.getMorningEnd())
                    + hoursBetween(row.getAfternoonStart(), row.getAfternoonEnd());
            m.put("hours", hours);
        } else {
            m.put("morningStart", null);
            m.put("morningEnd", null);
            m.put("afternoonStart", null);
            m.put("afternoonEnd", null);
            m.put("hours", hoursBetween(row.getStartTime(), row.getEndTime()));
        }
        m.put("checkInBeforeMin", row.getCheckInBeforeMin());
        m.put("checkInAfterMin", row.getCheckInAfterMin());
        m.put("checkOutBeforeMin", row.getCheckOutBeforeMin());
        m.put("checkOutAfterMin", row.getCheckOutAfterMin());
        m.put("active", row.isActive());
        return m;
    }
}
