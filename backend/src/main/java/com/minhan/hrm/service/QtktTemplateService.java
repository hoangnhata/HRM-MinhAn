package com.minhan.hrm.service;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.minhan.hrm.exception.ApiException;
import jakarta.annotation.PostConstruct;
import lombok.Getter;
import lombok.RequiredArgsConstructor;
import org.springframework.core.io.ClassPathResource;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

import java.io.InputStream;
import java.math.BigDecimal;
import java.text.Normalizer;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;

@Service
@RequiredArgsConstructor
public class QtktTemplateService {

    private final ObjectMapper objectMapper;

    @Getter
    private Map<String, Object> template;

    @PostConstruct
    void load() {
        try (InputStream in = new ClassPathResource("qtkt-templates/qtkt-procedures-v1.json").getInputStream()) {
            template = objectMapper.readValue(in, new TypeReference<>() {});
        } catch (Exception e) {
            throw new IllegalStateException("Không đọc được template QTKT", e);
        }
    }

    @SuppressWarnings("unchecked")
    public List<Map<String, Object>> procedures() {
        return (List<Map<String, Object>>) template.get("procedures");
    }

    public Map<String, Object> requireProcedure(String code) {
        return procedures().stream()
                .filter(p -> code.equals(p.get("code")))
                .findFirst()
                .orElseThrow(() -> new ApiException(HttpStatus.BAD_REQUEST, "Không tìm thấy quy trình: " + code));
    }

    @SuppressWarnings("unchecked")
    public Map<String, Double> stepMaxPoints(String procedureCode) {
        Map<String, Object> proc = requireProcedure(procedureCode);
        Map<String, Double> max = new LinkedHashMap<>();
        List<Map<String, Object>> sections = (List<Map<String, Object>>) proc.get("sections");
        for (Map<String, Object> section : sections) {
            List<Map<String, Object>> steps = (List<Map<String, Object>>) section.get("steps");
            for (Map<String, Object> step : steps) {
                max.put(String.valueOf(step.get("id")), ((Number) step.get("maxPoints")).doubleValue());
            }
        }
        return max;
    }

    @SuppressWarnings("unchecked")
    public Map<String, Object> checkOptions(String procedureCode) {
        Map<String, Object> proc = requireProcedure(procedureCode);
        Object raw = proc.get("checkOptions");
        if (raw instanceof Map<?, ?> m) {
            return (Map<String, Object>) m;
        }
        return null;
    }

    /** Trả về [code, label] sau khi kiểm tra; code rỗng nếu quy trình không có checkOptions. */
    @SuppressWarnings("unchecked")
    public String[] resolveCheckContext(String procedureCode, String requestedCode) {
        Map<String, Object> opts = checkOptions(procedureCode);
        if (opts == null) {
            return new String[] {"", null};
        }
        String code = requestedCode != null ? requestedCode.trim() : "";
        if (code.isBlank()) {
            throw new ApiException(HttpStatus.BAD_REQUEST,
                    "Cần chọn " + opts.getOrDefault("label", "nội dung kiểm tra"));
        }
        List<Map<String, Object>> options = (List<Map<String, Object>>) opts.get("options");
        if (options == null) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Template quy trình thiếu danh sách lựa chọn kiểm tra");
        }
        for (Map<String, Object> o : options) {
            if (code.equals(String.valueOf(o.get("code")))) {
                return new String[] {code, String.valueOf(o.get("label"))};
            }
        }
        throw new ApiException(HttpStatus.BAD_REQUEST, "Lựa chọn kiểm tra không hợp lệ");
    }

    public boolean requiresPatientCode(String procedureCode) {
        return Boolean.TRUE.equals(requireProcedure(procedureCode).get("requiresPatientCode"));
    }

    /** Chuẩn hóa mã BN; rỗng nếu không bắt buộc. */
    public String resolvePatientCode(String procedureCode, String raw) {
        String code = raw != null ? raw.trim() : "";
        if (requiresPatientCode(procedureCode)) {
            if (code.isBlank()) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "Cần nhập mã bệnh nhân");
            }
            if (code.length() > 64) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "Mã bệnh nhân tối đa 64 ký tự");
            }
            return code;
        }
        return "";
    }

    @SuppressWarnings("unchecked")
    public List<String> requiredFullStepIds(String procedureCode) {
        Object raw = requireProcedure(procedureCode).get("requiredFullStepIds");
        if (!(raw instanceof List<?> list) || list.isEmpty()) {
            return List.of();
        }
        List<String> out = new ArrayList<>();
        for (Object o : list) {
            if (o != null) out.add(String.valueOf(o));
        }
        return out;
    }

    public BigDecimal passMinScore(String procedureCode) {
        Object raw = requireProcedure(procedureCode).get("passMinScore");
        if (raw instanceof Number n) {
            return BigDecimal.valueOf(n.doubleValue());
        }
        return BigDecimal.valueOf(7);
    }

    @SuppressWarnings("unchecked")
    public List<String> allowedDepartmentKeys(String procedureCode) {
        Object raw = requireProcedure(procedureCode).get("allowedDepartmentKeys");
        if (!(raw instanceof List<?> list) || list.isEmpty()) {
            return List.of();
        }
        List<String> out = new ArrayList<>();
        for (Object o : list) {
            if (o != null) {
                String key = normalizeDeptKey(String.valueOf(o));
                if (!key.isBlank()) out.add(key);
            }
        }
        return out;
    }

    public boolean isDepartmentAllowedForProcedure(String procedureCode, String departmentName) {
        List<String> keys = allowedDepartmentKeys(procedureCode);
        if (keys.isEmpty()) return true;
        String normalized = normalizeDeptKey(departmentName);
        if (normalized.isBlank()) return false;
        for (String key : keys) {
            if (normalized.contains(key)) return true;
        }
        return false;
    }

    public static String normalizeDeptKey(String raw) {
        if (raw == null || raw.isBlank()) return "";
        String s = Normalizer.normalize(raw, Normalizer.Form.NFD)
                .replaceAll("\\p{M}+", "")
                .toUpperCase(Locale.ROOT)
                .replace('Đ', 'D')
                .replace('đ', 'D');
        s = s.replaceAll("[^A-Z0-9]+", " ").trim().replaceAll("\\s+", " ");
        return s;
    }
}
