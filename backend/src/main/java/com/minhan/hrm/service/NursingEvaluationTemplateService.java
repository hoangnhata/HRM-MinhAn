package com.minhan.hrm.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.minhan.hrm.exception.ApiException;
import com.minhan.hrm.exception.ResourceNotFoundException;
import lombok.RequiredArgsConstructor;
import org.springframework.core.io.ClassPathResource;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

import java.io.IOException;
import java.io.InputStream;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

@Service
@RequiredArgsConstructor
public class NursingEvaluationTemplateService {

    private static final Map<String, JsonNode> CACHE = new ConcurrentHashMap<>();

    private final ObjectMapper objectMapper;

    public JsonNode getTemplate(String code) {
        return CACHE.computeIfAbsent(code, this::load);
    }

    private JsonNode load(String code) {
        String path = "evaluation-templates/" + switch (code) {
            case "DIEU_DUONG_MONTHLY" -> "dieu-duong-monthly.json";
            case "DD_KTV_HS_MA_2026" -> "dd-ktv-hs-ma2026.json";
            default -> throw new ResourceNotFoundException("Không có mẫu đánh giá: " + code);
        };
        try (InputStream in = new ClassPathResource(path).getInputStream()) {
            return objectMapper.readTree(in);
        } catch (IOException e) {
            throw new ApiException(HttpStatus.INTERNAL_SERVER_ERROR, "Không đọc được mẫu đánh giá");
        }
    }

}
