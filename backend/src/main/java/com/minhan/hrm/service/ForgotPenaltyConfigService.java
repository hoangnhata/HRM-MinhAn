package com.minhan.hrm.service;

import com.minhan.hrm.attendance.ForgotPenaltySettings;
import com.minhan.hrm.dto.attendance.ForgotPenaltyConfigRequest;
import com.minhan.hrm.entity.AttendanceForgotPenaltyConfig;
import com.minhan.hrm.exception.ApiException;
import com.minhan.hrm.repository.AttendanceForgotPenaltyConfigRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@Service
@RequiredArgsConstructor
public class ForgotPenaltyConfigService {

    private static final long CONFIG_ID = 1L;

    private final AttendanceForgotPenaltyConfigRepository repository;

    @Transactional(readOnly = true)
    public ForgotPenaltySettings currentSettings() {
        return toSettings(repository.findById(CONFIG_ID).orElseGet(this::defaultEntity));
    }

    @Transactional(readOnly = true)
    public Map<String, Object> getConfigView() {
        AttendanceForgotPenaltyConfig cfg = repository.findById(CONFIG_ID).orElseGet(this::defaultEntity);
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("tier1Amount", cfg.getTier1Amount());
        m.put("tier2Min", cfg.getTier2Min());
        m.put("tier2Max", cfg.getTier2Max());
        m.put("tier2Amount", cfg.getTier2Amount());
        m.put("tier3Amount", cfg.getTier3Amount());
        m.put("tiers", displayTiers(toSettings(cfg)));
        m.put("updatedAt", cfg.getUpdatedAt() != null ? cfg.getUpdatedAt().toString() : "");
        return m;
    }

    @Transactional
    public Map<String, Object> updateConfig(ForgotPenaltyConfigRequest req) {
        if (req.getTier2Max() < req.getTier2Min()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Mức giữa: số lần tối đa phải ≥ số lần tối thiểu");
        }
        AttendanceForgotPenaltyConfig cfg = repository.findById(CONFIG_ID).orElseGet(() -> {
            AttendanceForgotPenaltyConfig c = defaultEntity();
            c.setId(CONFIG_ID);
            return c;
        });
        cfg.setTier1Amount(req.getTier1Amount());
        cfg.setTier2Min(req.getTier2Min());
        cfg.setTier2Max(req.getTier2Max());
        cfg.setTier2Amount(req.getTier2Amount());
        cfg.setTier3Amount(req.getTier3Amount());
        repository.save(cfg);
        return getConfigView();
    }

    public List<Map<String, Object>> displayTiers(ForgotPenaltySettings s) {
        List<Map<String, Object>> tiers = new ArrayList<>();
        tiers.add(Map.of(
                "label", "1 lần/tháng",
                "minOccurrence", 1,
                "maxOccurrence", 1,
                "amountPerTime", s.tier1Amount()));
        tiers.add(Map.of(
                "label", s.tier2Min() + "–" + s.tier2Max() + " lần/tháng",
                "minOccurrence", s.tier2Min(),
                "maxOccurrence", s.tier2Max(),
                "amountPerTime", s.tier2Amount()));
        tiers.add(Map.of(
                "label", ">" + s.tier2Max() + " lần/tháng",
                "minOccurrence", s.tier2Max() + 1,
                "maxOccurrence", "",
                "amountPerTime", s.tier3Amount()));
        return tiers;
    }

    private ForgotPenaltySettings toSettings(AttendanceForgotPenaltyConfig cfg) {
        return new ForgotPenaltySettings(
                cfg.getTier1Amount(),
                cfg.getTier2Min(),
                cfg.getTier2Max(),
                cfg.getTier2Amount(),
                cfg.getTier3Amount());
    }

    private AttendanceForgotPenaltyConfig defaultEntity() {
        return AttendanceForgotPenaltyConfig.builder()
                .id(CONFIG_ID)
                .tier1Amount(new BigDecimal("10000"))
                .tier2Min(2)
                .tier2Max(4)
                .tier2Amount(new BigDecimal("50000"))
                .tier3Amount(new BigDecimal("100000"))
                .build();
    }
}
