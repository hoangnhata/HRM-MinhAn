package com.minhan.hrm.service;

import com.minhan.hrm.attendance.LatePenaltySettings;
import com.minhan.hrm.dto.attendance.LatePenaltyConfigUpdateRequest;
import com.minhan.hrm.dto.attendance.LatePenaltyTierRequest;
import com.minhan.hrm.entity.AttendanceLatePenaltyTier;
import com.minhan.hrm.exception.ApiException;
import com.minhan.hrm.repository.AttendanceLatePenaltyTierRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@Service
@RequiredArgsConstructor
public class LatePenaltyConfigService {

    private final AttendanceLatePenaltyTierRepository repository;

    @Transactional(readOnly = true)
    public LatePenaltySettings currentSettings() {
        List<AttendanceLatePenaltyTier> rows = repository.findAllByOrderBySortOrderAsc();
        if (rows.isEmpty()) {
            return LatePenaltySettings.defaults();
        }
        return toSettings(rows);
    }

    @Transactional(readOnly = true)
    public Map<String, Object> getConfigView() {
        LatePenaltySettings settings = currentSettings();
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("exemptBelowMinutes", settings.exemptBelowMinutes());
        m.put("tiers", settings.toDisplayTiers());
        List<AttendanceLatePenaltyTier> rows = repository.findAllByOrderBySortOrderAsc();
        if (!rows.isEmpty()) {
            m.put("updatedAt", rows.stream()
                    .map(AttendanceLatePenaltyTier::getUpdatedAt)
                    .filter(java.util.Objects::nonNull)
                    .max(Comparator.naturalOrder())
                    .map(Object::toString)
                    .orElse(""));
        } else {
            m.put("updatedAt", "");
        }
        return m;
    }

    @Transactional
    public Map<String, Object> updateConfig(LatePenaltyConfigUpdateRequest req) {
        validateTiers(req.getTiers());
        List<LatePenaltyTierRequest> sorted = req.getTiers().stream()
                .sorted(Comparator.comparingInt(LatePenaltyTierRequest::getSortOrder))
                .toList();
        repository.deleteAll();
        for (LatePenaltyTierRequest t : sorted) {
            AttendanceLatePenaltyTier row = AttendanceLatePenaltyTier.builder()
                    .sortOrder(t.getSortOrder())
                    .minMinutes(t.getMinMinutes())
                    .maxMinutes(t.getMaxMinutes())
                    .amount(t.getAmount())
                    .requiresDiscipline(t.isRequiresDiscipline())
                    .note(t.getNote())
                    .build();
            repository.save(row);
        }
        return getConfigView();
    }

    private void validateTiers(List<LatePenaltyTierRequest> tiers) {
        if (tiers == null || tiers.isEmpty()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Phải có ít nhất một mức phạt");
        }
        List<LatePenaltyTierRequest> sorted = tiers.stream()
                .sorted(Comparator.comparingInt(LatePenaltyTierRequest::getSortOrder))
                .toList();
        LatePenaltyTierRequest prev = null;
        for (LatePenaltyTierRequest t : sorted) {
            if (t.isRequiresDiscipline()) {
                if (t.getMaxMinutes() != null) {
                    throw new ApiException(HttpStatus.BAD_REQUEST,
                            "Mức kỷ luật không được có số phút tối đa");
                }
            } else if (t.getMaxMinutes() == null) {
                throw new ApiException(HttpStatus.BAD_REQUEST,
                        "Mức " + t.getSortOrder() + ": phải nhập số phút tối đa");
            } else if (t.getMaxMinutes() < t.getMinMinutes()) {
                throw new ApiException(HttpStatus.BAD_REQUEST,
                        "Mức " + t.getSortOrder() + ": phút tối đa phải ≥ phút tối thiểu");
            }
            if (prev != null && !prev.isRequiresDiscipline()) {
                if (t.getMinMinutes() != prev.getMaxMinutes() + 1) {
                    throw new ApiException(HttpStatus.BAD_REQUEST,
                            "Các mức phải liên tiếp: mức " + t.getSortOrder()
                                    + " phải bắt đầu từ " + (prev.getMaxMinutes() + 1));
                }
            }
            prev = t;
        }
        boolean hasDiscipline = sorted.stream().anyMatch(LatePenaltyTierRequest::isRequiresDiscipline);
        LatePenaltyTierRequest last = sorted.get(sorted.size() - 1);
        if (hasDiscipline && !last.isRequiresDiscipline()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Mức kỷ luật phải là mức cuối cùng");
        }
    }

    private LatePenaltySettings toSettings(List<AttendanceLatePenaltyTier> rows) {
        List<LatePenaltySettings.LatePenaltyTier> tiers = new ArrayList<>();
        for (AttendanceLatePenaltyTier r : rows) {
            tiers.add(new LatePenaltySettings.LatePenaltyTier(
                    r.getSortOrder(),
                    r.getMinMinutes(),
                    r.getMaxMinutes(),
                    r.getAmount() != null ? r.getAmount() : BigDecimal.ZERO,
                    r.isRequiresDiscipline(),
                    r.getNote()));
        }
        return new LatePenaltySettings(tiers);
    }
}
