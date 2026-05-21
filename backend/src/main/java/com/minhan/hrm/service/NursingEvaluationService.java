package com.minhan.hrm.service;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.minhan.hrm.dto.evaluation.NursingEvaluationChannelSubmitRequest;
import com.minhan.hrm.dto.evaluation.NursingEvaluationSubmitRequest;
import com.minhan.hrm.entity.Employee;
import com.minhan.hrm.entity.NursingEvaluation;
import com.minhan.hrm.entity.UserAccount;
import com.minhan.hrm.exception.ApiException;
import com.minhan.hrm.exception.ResourceNotFoundException;
import com.minhan.hrm.repository.EmployeeRepository;
import com.minhan.hrm.repository.NursingEvaluationRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Instant;
import java.util.*;

@Service
@RequiredArgsConstructor
public class NursingEvaluationService {

    private static final String CH_TRUONG_KHOA = "truongKhoa";
    private static final String CH_DDT = "ddt";
    private static final String CH_HD = "hd";
    /** 70 điểm: Trưởng khoa + ĐDT; 30 điểm: HCNS */
    private static final List<String> DEPT_CHANNELS = List.of(CH_TRUONG_KHOA, CH_DDT);
    private static final String NOTE_TRUONG_KHOA = "truongKhoaNote";
    private static final String NOTE_DDT = "ddtNote";
    private static final String NOTE_HD = "hdNote";
    /** Lưu kèm trong scores_json: ai đã lưu từng kênh (không phải tiêu chí). */
    private static final String META_CHANNEL_EVALUATORS = "__channelEvaluators__";

    private final NursingEvaluationTemplateService templateService;
    private final NursingEvaluationRepository nursingEvaluationRepository;
    private final EmployeeService employeeService;
    private final EmployeeRepository employeeRepository;
    private final ObjectMapper objectMapper;

    @Transactional(readOnly = true)
    public Map<String, Object> getTemplateForUi(String code) {
        JsonNode root = templateService.getTemplate(code);
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("code", text(root, "code"));
        m.put("name", text(root, "name"));
        m.put("version", root.has("version") ? root.get("version").asInt() : 1);
        m.put("criteriaGroups", objectMapper.convertValue(root.get("criteriaGroups"),
                new TypeReference<List<Map<String, Object>>>() {
                }));
        m.put("gradingScale", List.of(
                Map.of("min", 90, "label", "Xuất sắc", "proposal", "Xét tăng lương sớm"),
                Map.of("min", 80, "label", "Tốt", "proposal", "Ưu tiên, theo dõi"),
                Map.of("min", 65, "label", "Khá", "proposal", "Chưa xét"),
                Map.of("min", 0, "label", "Chưa đạt", "proposal", "Đào tạo lại")
        ));
        return m;
    }

    private static String text(JsonNode n, String field) {
        return n.has(field) ? n.get(field).asText() : "";
    }

    @Transactional(readOnly = true)
    public List<Map<String, Object>> listForEmployee(Long employeeId) {
        Employee emp = employeeService.requireEmployeeEntity(employeeId);
        assertCanViewNursing(emp);
        return nursingEvaluationRepository.findByEmployeeOrderByPeriodYearDescPeriodMonthDesc(emp).stream()
                .map(this::toRow)
                .toList();
    }

    /**
     * Trạng thái đã có điểm từng kênh trong kỳ — lọc NV theo quyền xem của user (ADMIN/HCNS/trưởng khoa/ĐDT: toàn viện).
     */
    @Transactional(readOnly = true)
    @PreAuthorize("hasAnyRole('ADMIN','HR','HEAD_DEPARTMENT','HEAD_NURSING')")
    public List<Map<String, Object>> listPeriodEvaluationStatus(int year, int month, String templateCode) {
        UserAccount current = employeeService.currentUser();
        List<NursingEvaluation> all = nursingEvaluationRepository.listMonthlyForTemplate(year, month, templateCode);
        List<Map<String, Object>> out = new ArrayList<>();
        for (NursingEvaluation n : all) {
            Employee emp = n.getEmployee();
            if (!canViewNursingEvalQuiet(current, emp)) {
                continue;
            }
            String json = n.getScoresJson();
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("employeeId", emp.getId());
            // Một người có thể kiêm Trưởng khoa và ĐDT: chấm một kênh (khoa hoặc ĐDT) coi như đủ phần 70 điểm (trước HĐ).
            boolean deptSide = mergedHasAnyChannelScore(json, CH_TRUONG_KHOA)
                    || mergedHasAnyChannelScore(json, CH_DDT);
            m.put("hasTruongKhoa", deptSide);
            m.put("hasDdt", deptSide);
            m.put("hasHd", mergedHasAnyChannelScore(json, CH_HD));
            out.add(m);
        }
        return out;
    }

    @PreAuthorize("hasRole('ADMIN')")
    @Transactional
    public Map<String, Object> submit(NursingEvaluationSubmitRequest req) {
        JsonNode template = templateService.getTemplate(req.getTemplateCode());
        JsonNode groups = template.get("criteriaGroups");
        if (groups == null || !groups.isArray()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Mẫu đánh giá không hợp lệ");
        }
        Map<String, Set<BigDecimal>> allowedByCriterion = buildAllowedPoints(groups);
        Map<String, Object> merged = new LinkedHashMap<>();

        for (JsonNode g : groups) {
            String cid = g.get("id").asText();
            Map<String, Object> src = req.getScores().get(cid);
            if (src == null) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "Thiếu điểm cho tiêu chí: " + cid);
            }
            Map<String, Object> row = new LinkedHashMap<>();
            Set<BigDecimal> allowed = allowedByCriterion.get(cid);
            if (allowed == null) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "Tiêu chí không hợp lệ: " + cid);
            }

            if (isCouncilCriterion(g)) {
                BigDecimal val = toBigDecimalOrNull(src.get(CH_HD));
                if (val == null) {
                    throw new ApiException(HttpStatus.BAD_REQUEST, "Thiếu điểm Hội đồng cho " + cid);
                }
                val = val.setScale(2, RoundingMode.HALF_UP);
                if (!containsPoint(allowed, val)) {
                    throw new ApiException(HttpStatus.BAD_REQUEST, "Điểm Hội đồng không hợp lệ cho " + cid + ": " + val);
                }
                row.put(CH_HD, val);
                copyNoteIfPresent(src, row, NOTE_HD);
            } else {
                for (String channel : DEPT_CHANNELS) {
                    BigDecimal val = toBigDecimalOrNull(src.get(channel));
                    if (val == null) {
                        throw new ApiException(HttpStatus.BAD_REQUEST, "Thiếu điểm " + channel + " cho " + cid);
                    }
                    val = val.setScale(2, RoundingMode.HALF_UP);
                    if (!containsPoint(allowed, val)) {
                        throw new ApiException(HttpStatus.BAD_REQUEST,
                                "Điểm không hợp lệ cho " + cid + "/" + channel + ": " + val);
                    }
                    row.put(channel, val);
                }
                copyNoteIfPresent(src, row, NOTE_TRUONG_KHOA);
                copyNoteIfPresent(src, row, NOTE_DDT);
            }
            merged.put(cid, row);
        }

        UserAccount evaluator = employeeService.currentUser();
        touchChannelEvaluator(merged, CH_TRUONG_KHOA, evaluator);
        touchChannelEvaluator(merged, CH_DDT, evaluator);
        touchChannelEvaluator(merged, CH_HD, evaluator);
        Employee emp = employeeService.requireEmployeeEntity(req.getEmployeeId());
        return persistEvaluation(emp, evaluator, req.getPeriodYear(), req.getPeriodMonth(),
                req.getTemplateCode(), merged, req.getComments(), groups);
    }

    @PreAuthorize("hasAnyRole('ADMIN','HR','HEAD_DEPARTMENT','HEAD_NURSING')")
    @Transactional
    public Map<String, Object> submitChannel(NursingEvaluationChannelSubmitRequest req) {
        if (!Set.of(CH_TRUONG_KHOA, CH_DDT, CH_HD).contains(req.getChannel())) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Kênh không hợp lệ");
        }
        JsonNode template = templateService.getTemplate(req.getTemplateCode());
        JsonNode groups = template.get("criteriaGroups");
        if (groups == null || !groups.isArray()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Mẫu đánh giá không hợp lệ");
        }
        Map<String, Set<BigDecimal>> allowedByCriterion = buildAllowedPoints(groups);
        Employee emp = employeeService.requireEmployeeEntity(req.getEmployeeId());
        UserAccount evaluator = employeeService.currentUser();
        assertCanSubmitChannel(evaluator, emp, req.getChannel());

        String existingJson = nursingEvaluationRepository
                .findByEmployeeAndPeriodYearAndPeriodMonthAndTemplateCode(
                        emp, req.getPeriodYear(), req.getPeriodMonth(), req.getTemplateCode())
                .map(NursingEvaluation::getScoresJson)
                .orElse(null);
        Map<String, Object> merged = readMergedScores(existingJson);

        // Chỉ bắt buộc các tiêu chí thuộc đúng phần (70 hoặc 30) tương ứng với kênh đang lưu
        Set<String> requiredIds = new LinkedHashSet<>();
        for (JsonNode g : groups) {
            boolean council = isCouncilCriterion(g);
            boolean bonus = isBonusCriterion(g);
            if (bonus) {
                continue;
            }
            if (CH_HD.equals(req.getChannel()) && council) {
                requiredIds.add(g.get("id").asText());
            }
            if (!CH_HD.equals(req.getChannel()) && !council) {
                requiredIds.add(g.get("id").asText());
            }
        }

        for (String cid : requiredIds) {
            BigDecimal val = req.getScores().get(cid);
            if (val == null) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "Thiếu điểm cho tiêu chí: " + cid);
            }
            val = val.setScale(2, RoundingMode.HALF_UP);
            Set<BigDecimal> allowed = allowedByCriterion.get(cid);
            if (allowed == null) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "Tiêu chí không hợp lệ: " + cid);
            }
            if (!containsPoint(allowed, val)) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "Điểm không hợp lệ cho " + cid + ": " + val);
            }
        }

        String noteKey = CH_TRUONG_KHOA.equals(req.getChannel()) ? NOTE_TRUONG_KHOA
                : CH_DDT.equals(req.getChannel()) ? NOTE_DDT
                : NOTE_HD;
        Map<String, String> noteMap = req.getNotes();

        for (String cid : requiredIds) {
            BigDecimal raw = req.getScores().get(cid);
            if (raw == null) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "Thiếu điểm cho tiêu chí: " + cid);
            }
            BigDecimal val = raw.setScale(2, RoundingMode.HALF_UP);
            Map<String, Object> row = ensureScoreRow(merged, cid);
            row.put(req.getChannel(), val);
            if (noteMap != null && noteMap.containsKey(cid)) {
                String n = noteMap.get(cid);
                if (n != null && !n.isBlank()) {
                    row.put(noteKey, n.trim());
                }
            }
        }

        // Điểm thưởng VI_*: mỗi mục 0 hoặc 3; nếu client không gửi thì giữ điểm cũ của kênh, không có thì 0
        if (!CH_HD.equals(req.getChannel())) {
            for (JsonNode g : groups) {
                if (!isBonusCriterion(g)) {
                    continue;
                }
                String id = g.get("id").asText();
                BigDecimal raw = req.getScores() != null ? req.getScores().get(id) : null;
                if (raw == null) {
                    Map<String, Object> ex = scoreRow(merged, id);
                    raw = ex != null ? toBigDecimalOrNull(ex.get(req.getChannel())) : null;
                }
                if (raw == null) {
                    raw = BigDecimal.ZERO;
                }
                BigDecimal val = raw.setScale(2, RoundingMode.HALF_UP);
                Set<BigDecimal> allowed = allowedByCriterion.get(id);
                if (allowed == null) {
                    throw new ApiException(HttpStatus.BAD_REQUEST, "Tiêu chí không hợp lệ: " + id);
                }
                if (!containsPoint(allowed, val)) {
                    throw new ApiException(HttpStatus.BAD_REQUEST, "Điểm thưởng không hợp lệ cho " + id + ": " + val);
                }
                Map<String, Object> row = ensureScoreRow(merged, id);
                row.put(req.getChannel(), val);
                if (noteMap != null && noteMap.containsKey(id)) {
                    String n = noteMap.get(id);
                    if (n != null && !n.isBlank()) {
                        row.put(noteKey, n.trim());
                    }
                }
            }
        }

        touchChannelEvaluator(merged, req.getChannel(), evaluator);
        return persistEvaluation(emp, evaluator, req.getPeriodYear(), req.getPeriodMonth(),
                req.getTemplateCode(), merged, req.getComments(), groups);
    }

    @Transactional(readOnly = true)
    @PreAuthorize("hasAnyRole('ADMIN','HR')")
    public List<Map<String, Object>> listMonthlySummary(int year, int month, String templateCode) {
        return nursingEvaluationRepository.listMonthlyForTemplate(year, month, templateCode).stream()
                .map(this::toSummaryRow)
                .toList();
    }

    @Transactional(readOnly = true)
    @PreAuthorize("hasAnyRole('ADMIN','HR')")
    public Map<String, Object> getRecordDetail(Long evaluationId) {
        NursingEvaluation n = nursingEvaluationRepository.findDetailById(evaluationId)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy bản đánh giá"));
        Map<String, Object> m = toRow(n);
        Employee e = n.getEmployee();
        m.put("fullName", e.getFullName());
        m.put("departmentName", e.getDepartment().getName());
        m.put("employeeCode", e.getEmployeeCode());
        Object scores = m.get("scores");
        if (scores instanceof Map<?, ?> sm) {
            @SuppressWarnings("unchecked")
            Map<String, Object> sc = (Map<String, Object>) scores;
            if (sc.containsKey(META_CHANNEL_EVALUATORS)) {
                m.put("channelEvaluators", sc.remove(META_CHANNEL_EVALUATORS));
            }
        }
        return m;
    }

    /**
     * Phần 70 điểm trong báo cáo: trung bình hai cột khi Trưởng khoa và ĐDT đều đã chấm đủ;
     * nếu chỉ một bên chấm (vẫn đạt tổng /70) thì dùng điểm cột đó để cộng với Hội đồng 30.
     */
    private static BigDecimal deptSeventyForSummary(BigDecimal totalTruongKhoa, BigDecimal totalDdt) {
        if (totalTruongKhoa != null && totalDdt != null) {
            return totalTruongKhoa.add(totalDdt).divide(new BigDecimal("2"), 2, RoundingMode.HALF_UP);
        }
        if (totalTruongKhoa != null) {
            return totalTruongKhoa.setScale(2, RoundingMode.HALF_UP);
        }
        if (totalDdt != null) {
            return totalDdt.setScale(2, RoundingMode.HALF_UP);
        }
        return null;
    }

    private Map<String, Object> toSummaryRow(NursingEvaluation n) {
        Employee e = n.getEmployee();
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("evaluationId", n.getId());
        m.put("employeeId", e.getId());
        m.put("employeeCode", e.getEmployeeCode());
        m.put("fullName", e.getFullName());
        m.put("departmentName", e.getDepartment().getName());
        m.put("periodYear", n.getPeriodYear());
        m.put("periodMonth", n.getPeriodMonth());
        m.put("totalTruongKhoa", n.getTotalTruongKhoa()); // /70
        m.put("totalDdt", n.getTotalDdt()); // /70
        m.put("gradeTruongKhoa", n.getGradeTruongKhoa());
        m.put("gradeDdt", n.getGradeDdt());
        m.put("evaluatorUsername", n.getEvaluator().getUsername());
        BigDecimal tk = n.getTotalTruongKhoa();
        BigDecimal ddt = n.getTotalDdt();
        BigDecimal deptAvg70 = deptSeventyForSummary(tk, ddt);
        m.put("deptAvg70", deptAvg70);

        HrAgg hd = computeCouncilAgg(templateService.getTemplate(String.valueOf(n.getTemplateCode())), n.getScoresJson());
        m.put("hdTotal30", hd.total30);
        m.put("hdGrade", hd.grade30);

        if (deptAvg70 != null && hd.total30 != null) {
            BigDecimal total100 = deptAvg70.add(hd.total30).setScale(2, RoundingMode.HALF_UP);
            m.put("total100", total100);
            m.put("overallGrade", gradeFromTotalScaled(total100, new BigDecimal("100.00")));
        } else {
            m.put("total100", null);
            m.put("overallGrade", null);
        }
        return m;
    }

    private Map<String, Object> persistEvaluation(Employee emp, UserAccount evaluator, int year, int month,
                                                  String templateCode, Map<String, Object> merged,
                                                  String comments, JsonNode groups) {
        stripLegacySelf(merged);
        String json;
        try {
            json = objectMapper.writeValueAsString(merged);
        } catch (Exception ex) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Không serialize điểm");
        }

        NursingEvaluation entity = nursingEvaluationRepository
                .findByEmployeeAndPeriodYearAndPeriodMonthAndTemplateCode(emp, year, month, templateCode)
                .orElse(NursingEvaluation.builder()
                        .employee(emp)
                        .evaluator(evaluator)
                        .periodYear(year)
                        .periodMonth(month)
                        .templateCode(templateCode)
                        .build());
        entity.setEvaluator(evaluator);
        entity.setScoresJson(json);
        if (comments != null && !comments.isBlank()) {
            entity.setComments(comments);
        }
        applyTotalsFromMerged(entity, groups, merged);
        entity = nursingEvaluationRepository.save(entity);
        return toRow(entity);
    }

    private void applyTotalsFromMerged(NursingEvaluation entity, JsonNode groups,
                                       Map<String, Object> merged) {
        entity.setTotalSelf(null);
        entity.setGradeSelf(null);
        // Tổng tối đa kênh khoa/phòng = I–V + điểm thưởng VI
        BigDecimal maxDept = maxTotal70(groups).add(maxBonusTotal(groups)).setScale(2, RoundingMode.HALF_UP);
        for (String channel : DEPT_CHANNELS) {
            BigDecimal baseSum = BigDecimal.ZERO;
            boolean baseComplete = true;
            for (JsonNode g : groups) {
                if (isCouncilCriterion(g) || isBonusCriterion(g)) {
                    continue;
                }
                String cid = g.get("id").asText();
                Map<String, Object> row = scoreRow(merged, cid);
                BigDecimal v = getChannelPoint(row, channel);
                if (v == null) {
                    baseComplete = false;
                    break;
                }
                baseSum = baseSum.add(v);
            }
            BigDecimal bonusSum = BigDecimal.ZERO;
            for (JsonNode g : groups) {
                if (!isBonusCriterion(g)) {
                    continue;
                }
                String cid = g.get("id").asText();
                Map<String, Object> row = scoreRow(merged, cid);
                BigDecimal v = getChannelPoint(row, channel);
                bonusSum = bonusSum.add(v != null ? v : BigDecimal.ZERO);
            }
            if (!baseComplete) {
                if (CH_TRUONG_KHOA.equals(channel)) {
                    entity.setTotalTruongKhoa(null);
                    entity.setGradeTruongKhoa(null);
                } else {
                    entity.setTotalDdt(null);
                    entity.setGradeDdt(null);
                }
            } else {
                BigDecimal sum = baseSum.add(bonusSum).setScale(2, RoundingMode.HALF_UP);
                if (CH_TRUONG_KHOA.equals(channel)) {
                    entity.setTotalTruongKhoa(sum);
                    entity.setGradeTruongKhoa(gradeFromTotalScaled(sum, maxDept));
                } else {
                    entity.setTotalDdt(sum);
                    entity.setGradeDdt(gradeFromTotalScaled(sum, maxDept));
                }
            }
        }
    }

    private static void stripLegacySelf(Map<String, Object> merged) {
        for (Map.Entry<String, Object> e : merged.entrySet()) {
            if (META_CHANNEL_EVALUATORS.equals(e.getKey())) {
                continue;
            }
            if (e.getValue() instanceof Map<?, ?> raw) {
                @SuppressWarnings("unchecked")
                Map<String, Object> row = (Map<String, Object>) raw;
                row.remove("self");
            }
        }
    }

    private String evaluatorDisplayName(UserAccount user) {
        if (user == null) {
            return "";
        }
        return employeeRepository.findByUserUsername(user.getUsername())
                .map(Employee::getFullName)
                .map(String::trim)
                .filter(s -> !s.isEmpty())
                .orElse(user.getUsername());
    }

    private void touchChannelEvaluator(Map<String, Object> merged, String channel, UserAccount user) {
        Object existing = merged.get(META_CHANNEL_EVALUATORS);
        Map<String, Object> meta;
        if (existing instanceof Map<?, ?>) {
            @SuppressWarnings("unchecked")
            Map<String, Object> m = (Map<String, Object>) existing;
            meta = m;
        } else {
            meta = new LinkedHashMap<>();
            merged.put(META_CHANNEL_EVALUATORS, meta);
        }
        Map<String, Object> info = new LinkedHashMap<>();
        info.put("username", user != null ? user.getUsername() : "");
        info.put("displayName", user != null ? evaluatorDisplayName(user) : "");
        info.put("savedAt", Instant.now().toString());
        meta.put(channel, info);
    }

    @SuppressWarnings("unchecked")
    private static Map<String, Object> ensureScoreRow(Map<String, Object> merged, String cid) {
        Object o = merged.get(cid);
        if (o instanceof Map<?, ?> raw) {
            return (Map<String, Object>) raw;
        }
        Map<String, Object> row = new LinkedHashMap<>();
        merged.put(cid, row);
        return row;
    }

    @SuppressWarnings("unchecked")
    private static Map<String, Object> scoreRow(Map<String, Object> merged, String cid) {
        Object o = merged.get(cid);
        if (o instanceof Map<?, ?> raw) {
            return (Map<String, Object>) raw;
        }
        return null;
    }

    /**
     * Đọc JSON lưu trữ: giữ điểm (truongKhoa, ddt, hd) và ghi chú; giữ meta người chấm.
     */
    private Map<String, Object> readMergedScores(String json) {
        if (json == null || json.isBlank()) {
            return new LinkedHashMap<>();
        }
        try {
            Map<String, Map<String, Object>> raw = objectMapper.readValue(json, new TypeReference<>() {
            });
            Map<String, Object> out = new LinkedHashMap<>();
            for (Map.Entry<String, Map<String, Object>> e : raw.entrySet()) {
                if (META_CHANNEL_EVALUATORS.equals(e.getKey())) {
                    Map<String, Object> preserved = new LinkedHashMap<>();
                    if (e.getValue() != null) {
                        preserved.putAll(e.getValue());
                    }
                    out.put(e.getKey(), preserved);
                    continue;
                }
                Map<String, Object> cleaned = new LinkedHashMap<>();
                if (e.getValue() != null) {
                    for (Map.Entry<String, Object> c : e.getValue().entrySet()) {
                        String k = c.getKey();
                        if ("self".equals(k)) {
                            continue;
                        }
                        Object v = c.getValue();
                        if (v == null) {
                            continue;
                        }
                        if (Set.of(CH_TRUONG_KHOA, CH_DDT, CH_HD).contains(k)) {
                            BigDecimal p = toBigDecimalOrNull(v);
                            if (p != null) {
                                cleaned.put(k, p);
                            }
                        } else if (NOTE_TRUONG_KHOA.equals(k) || NOTE_DDT.equals(k) || NOTE_HD.equals(k)) {
                            String s = String.valueOf(v).trim();
                            if (!s.isEmpty()) {
                                cleaned.put(k, s);
                            }
                        }
                    }
                }
                out.put(e.getKey(), cleaned);
            }
            return out;
        } catch (Exception ex) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Dữ liệu điểm lưu trữ không hợp lệ");
        }
    }

    private static BigDecimal getChannelPoint(Map<String, Object> row, String channel) {
        if (row == null) {
            return null;
        }
        return toBigDecimalOrNull(row.get(channel));
    }

    private static BigDecimal toBigDecimalOrNull(Object o) {
        if (o == null) {
            return null;
        }
        try {
            return new BigDecimal(o.toString()).setScale(2, RoundingMode.HALF_UP);
        } catch (Exception e) {
            return null;
        }
    }

    private static void copyNoteIfPresent(Map<String, Object> src, Map<String, Object> row, String noteKey) {
        if (src == null || !src.containsKey(noteKey)) {
            return;
        }
        Object v = src.get(noteKey);
        if (v == null) {
            return;
        }
        String s = String.valueOf(v).trim();
        if (!s.isEmpty()) {
            row.put(noteKey, s);
        }
    }

    private Map<String, Set<BigDecimal>> buildAllowedPoints(JsonNode groups) {
        Map<String, Set<BigDecimal>> allowedByCriterion = new LinkedHashMap<>();
        for (JsonNode g : groups) {
            String id = g.get("id").asText();
            Set<BigDecimal> pts = new HashSet<>();
            if (g.has("options") && g.get("options").isArray()) {
                for (JsonNode opt : g.get("options")) {
                    if (opt.has("points")) {
                        pts.add(BigDecimal.valueOf(opt.get("points").asDouble()).setScale(2, RoundingMode.HALF_UP));
                    }
                }
            }
            allowedByCriterion.put(id, pts);
        }
        return allowedByCriterion;
    }

    private void assertCanViewNursing(Employee target) {
        UserAccount current = employeeService.currentUser();
        if (!canViewNursingEvalQuiet(current, target)) {
            throw new ApiException(HttpStatus.FORBIDDEN, "Không có quyền xem đánh giá");
        }
    }

    private boolean canViewNursingEvalQuiet(UserAccount current, Employee target) {
        if (current == null || target == null) {
            return false;
        }
        switch (current.getRole()) {
            case ADMIN, HR -> {
                return true;
            }
            case EMPLOYEE -> {
                Employee self = employeeRepository.findByUserUsername(current.getUsername()).orElse(null);
                return self != null && self.getId().equals(target.getId());
            }
            case HEAD_DEPARTMENT, HEAD_NURSING -> {
                return true;
            }
            default -> {
                return false;
            }
        }
    }

    private boolean mergedHasAnyChannelScore(String scoresJson, String channel) {
        if (scoresJson == null || scoresJson.isBlank()) {
            return false;
        }
        Map<String, Object> merged = readMergedScores(scoresJson);
        for (Map.Entry<String, Object> e : merged.entrySet()) {
            if (META_CHANNEL_EVALUATORS.equals(e.getKey())) {
                continue;
            }
            String cid = e.getKey();
            if (CH_HD.equals(channel)) {
                if (!cid.startsWith("HD_")) {
                    continue;
                }
            } else {
                if (cid.startsWith("HD_")) {
                    continue;
                }
            }
            Map<String, Object> row = scoreRow(merged, cid);
            if (getChannelPoint(row, channel) != null) {
                return true;
            }
        }
        return false;
    }

    private void assertCanSubmitChannel(UserAccount current, Employee target, String channel) {
        switch (current.getRole()) {
            case ADMIN -> {
            }
            case HEAD_DEPARTMENT -> {
                if (!CH_TRUONG_KHOA.equals(channel)) {
                    throw new ApiException(HttpStatus.FORBIDDEN, "Trưởng khoa chỉ chấm kênh Trưởng khoa");
                }
                Employee self = employeeRepository.findByUserUsername(current.getUsername()).orElse(null);
                if (self == null) {
                    throw new ApiException(HttpStatus.FORBIDDEN,
                            "Tài khoản trưởng khoa cần gắn hồ sơ nhân viên để nhập điểm");
                }
            }
            case HEAD_NURSING -> {
                if (!CH_DDT.equals(channel)) {
                    throw new ApiException(HttpStatus.FORBIDDEN, "Điều dưỡng trưởng chỉ chấm kênh ĐDT");
                }
                Employee self = employeeRepository.findByUserUsername(current.getUsername()).orElse(null);
                if (self == null) {
                    throw new ApiException(HttpStatus.FORBIDDEN,
                            "Tài khoản Điều dưỡng trưởng cần gắn hồ sơ nhân viên để nhập điểm");
                }
            }
            case HR -> {
                if (!CH_HD.equals(channel)) {
                    throw new ApiException(HttpStatus.FORBIDDEN, "Hội đồng chỉ chấm phần 30 điểm (Hội đồng)");
                }
            }
            case EMPLOYEE -> throw new ApiException(HttpStatus.FORBIDDEN, "Vai trò này không nhập điểm trên phiếu");
            default -> throw new ApiException(HttpStatus.FORBIDDEN, "Không có quyền nhập điểm");
        }
    }

    private static boolean isCouncilCriterion(JsonNode g) {
        if (g == null) return false;
        String id = g.has("id") ? g.get("id").asText("") : "";
        String sec = g.has("section") ? g.get("section").asText("") : "";
        return id.startsWith("HD_") || sec.startsWith("HỘI ĐỒNG");
    }

    private static boolean isBonusCriterion(JsonNode g) {
        if (g == null) return false;
        String id = g.has("id") ? g.get("id").asText("") : "";
        return id.startsWith("VI_");
    }

    private static BigDecimal maxTotal70(JsonNode groups) {
        BigDecimal sum = BigDecimal.ZERO;
        for (JsonNode g : groups) {
            if (isCouncilCriterion(g) || isBonusCriterion(g)) continue;
            sum = sum.add(maxPointsFromGroup(g));
        }
        return sum.setScale(2, RoundingMode.HALF_UP);
    }

    /** Tổng điểm tối đa phần thưởng VI_* (thường 12). */
    private static BigDecimal maxBonusTotal(JsonNode groups) {
        BigDecimal sum = BigDecimal.ZERO;
        for (JsonNode g : groups) {
            if (!isBonusCriterion(g)) continue;
            sum = sum.add(maxPointsFromGroup(g));
        }
        return sum.setScale(2, RoundingMode.HALF_UP);
    }

    private static BigDecimal maxPointsFromGroup(JsonNode g) {
        if (g.has("maxPoints") && !g.get("maxPoints").isNull()) {
            return BigDecimal.valueOf(g.get("maxPoints").asDouble());
        }
        if (g.has("options") && g.get("options").isArray()) {
            double m = 0;
            for (JsonNode o : g.get("options")) {
                if (o.has("points")) m = Math.max(m, o.get("points").asDouble());
            }
            return BigDecimal.valueOf(m);
        }
        return BigDecimal.ZERO;
    }

    private record HrAgg(BigDecimal total30, String grade30) {
    }

    private HrAgg computeCouncilAgg(JsonNode template, String scoresJson) {
        JsonNode groups = template.get("criteriaGroups");
        if (groups == null || !groups.isArray()) {
            return new HrAgg(null, null);
        }
        Map<String, Object> merged = readMergedScores(scoresJson);
        BigDecimal sum = BigDecimal.ZERO;
        boolean complete = true;
        BigDecimal max30 = BigDecimal.ZERO;
        for (JsonNode g : groups) {
            if (!isCouncilCriterion(g)) continue;
            String cid = g.get("id").asText();
            BigDecimal v = getChannelPoint(scoreRow(merged, cid), CH_HD);
            if (v == null) {
                complete = false;
                break;
            }
            sum = sum.add(v);
            max30 = max30.add(maxPointsFromGroup(g));
        }
        if (!complete) return new HrAgg(null, null);
        sum = sum.setScale(2, RoundingMode.HALF_UP);
        max30 = max30.setScale(2, RoundingMode.HALF_UP);
        return new HrAgg(sum, gradeFromTotalScaled(sum, max30));
    }

    private static boolean containsPoint(Set<BigDecimal> allowed, BigDecimal val) {
        for (BigDecimal a : allowed) {
            if (a.compareTo(val) == 0) {
                return true;
            }
        }
        return false;
    }

    public static String gradeFromTotal(BigDecimal total) {
        if (total == null) {
            return "Chưa đạt";
        }
        double v = total.doubleValue();
        if (v >= 90) {
            return "Xuất sắc";
        }
        if (v >= 80) {
            return "Tốt";
        }
        if (v >= 65) {
            return "Khá";
        }
        return "Chưa đạt";
    }

    private static String gradeFromTotalScaled(BigDecimal total, BigDecimal maxTotal) {
        if (total == null || maxTotal == null || maxTotal.signum() <= 0) {
            return "Chưa đạt";
        }
        double pct = total.divide(maxTotal, 6, RoundingMode.HALF_UP).doubleValue() * 100.0;
        if (pct >= 90) return "Xuất sắc";
        if (pct >= 80) return "Tốt";
        if (pct >= 65) return "Khá";
        return "Chưa đạt";
    }

    // (đã thay bằng maxTotal70() + computeHrAgg())

    private Map<String, Object> toRow(NursingEvaluation n) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("id", n.getId());
        m.put("employeeId", n.getEmployee().getId());
        m.put("periodYear", n.getPeriodYear());
        m.put("periodMonth", n.getPeriodMonth());
        m.put("templateCode", n.getTemplateCode());
        m.put("totalTruongKhoa", n.getTotalTruongKhoa());
        m.put("totalDdt", n.getTotalDdt());
        m.put("gradeTruongKhoa", n.getGradeTruongKhoa());
        m.put("gradeDdt", n.getGradeDdt());
        m.put("comments", n.getComments());
        m.put("evaluatorUsername", n.getEvaluator().getUsername());
        m.put("createdAt", n.getCreatedAt().toString());
        try {
            m.put("scores", objectMapper.readValue(n.getScoresJson(), Map.class));
        } catch (Exception ignored) {
            m.put("scores", Map.of());
        }
        return m;
    }
}
