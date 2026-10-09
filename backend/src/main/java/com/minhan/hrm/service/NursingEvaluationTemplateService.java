package com.minhan.hrm.service;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.minhan.hrm.dto.evaluation.NursingEvaluationTemplateSaveRequest;
import com.minhan.hrm.entity.NursingEvaluationTemplateRevision;
import com.minhan.hrm.entity.UserAccount;
import com.minhan.hrm.exception.ApiException;
import com.minhan.hrm.exception.ResourceNotFoundException;
import com.minhan.hrm.repository.NursingEvaluationTemplateRevisionRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.core.io.ClassPathResource;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.io.IOException;
import java.io.InputStream;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;
import java.util.regex.Pattern;

/**
 * Mẫu đánh giá NV khối ĐD. Mẫu gốc nằm trong evaluation-templates/*.json; ADMIN / Trưởng phòng ĐD
 * chỉnh sửa qua giao diện → mỗi lần lưu tạo một phiên bản trong DB, bản mới nhất là mẫu đang dùng.
 */
@Service
@RequiredArgsConstructor
public class NursingEvaluationTemplateService {

    /** Thang xếp loại mặc định — ngưỡng tính theo % trên tổng điểm chuẩn. */
    public static final List<GradeBand> DEFAULT_GRADING_SCALE = List.of(
            new GradeBand(new BigDecimal("90"), "Xuất sắc", "Xét tăng lương sớm"),
            new GradeBand(new BigDecimal("80"), "Tốt", "Ưu tiên, theo dõi"),
            new GradeBand(new BigDecimal("65"), "Khá", "Chưa xét"),
            new GradeBand(BigDecimal.ZERO, "Chưa đạt", "Đào tạo lại"));

    private static final Pattern ID_PATTERN = Pattern.compile("^[A-Za-z0-9_]{1,40}$");
    private static final int MAX_CRITERIA = 200;
    private static final int MAX_OPTIONS = 20;
    private static final int MAX_GRADES = 10;
    private static final BigDecimal MAX_OPTION_POINTS = new BigDecimal("1000");

    private static final Map<String, JsonNode> DEFAULT_CACHE = new ConcurrentHashMap<>();
    private static final Map<Long, JsonNode> REVISION_CACHE = new ConcurrentHashMap<>();

    private final ObjectMapper objectMapper;
    private final NursingEvaluationTemplateRevisionRepository revisionRepository;
    private final EmployeeService employeeService;

    public record GradeBand(BigDecimal min, String label, String proposal) {
    }

    // ------------------------------------------------------------------ đọc mẫu

    /** Mẫu đang dùng: phiên bản mới nhất trong DB, chưa có thì mẫu gốc. */
    @Transactional(readOnly = true)
    public JsonNode getTemplate(String code) {
        return revisionRepository.findFirstByTemplateCodeOrderByVersionDesc(code)
                .map(this::parseRevision)
                .orElseGet(() -> getDefaultTemplate(code));
    }

    public JsonNode getDefaultTemplate(String code) {
        return DEFAULT_CACHE.computeIfAbsent(code, this::loadDefault);
    }

    private JsonNode loadDefault(String code) {
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

    private JsonNode parseRevision(NursingEvaluationTemplateRevision r) {
        return REVISION_CACHE.computeIfAbsent(r.getId(), id -> {
            try {
                return objectMapper.readTree(r.getTemplateJson());
            } catch (IOException e) {
                throw new ApiException(HttpStatus.INTERNAL_SERVER_ERROR, "Phiên bản mẫu đánh giá bị lỗi dữ liệu");
            }
        });
    }

    /** Định dạng trả về cho web / mobile (giữ nguyên cấu trúc cũ + thang xếp loại). */
    public Map<String, Object> toUi(JsonNode root) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("code", text(root, "code"));
        m.put("name", text(root, "name"));
        m.put("version", root.has("version") ? root.get("version").asInt() : 1);
        m.put("baseMaxPoints", root.hasNonNull("baseMaxPoints") ? root.get("baseMaxPoints").numberValue() : 90);
        m.put("criteriaGroups", objectMapper.convertValue(root.get("criteriaGroups"),
                new TypeReference<List<Map<String, Object>>>() {
                }));
        m.put("note", text(root, "note"));
        List<Map<String, Object>> scale = new ArrayList<>();
        for (GradeBand b : gradingScale(root)) {
            Map<String, Object> s = new LinkedHashMap<>();
            s.put("min", b.min());
            s.put("label", b.label());
            s.put("proposal", b.proposal());
            scale.add(s);
        }
        m.put("gradingScale", scale);
        return m;
    }

    /** Thang xếp loại của mẫu (giảm dần theo ngưỡng); mẫu cũ chưa có → thang mặc định. */
    public List<GradeBand> gradingScale(JsonNode root) {
        JsonNode arr = root != null ? root.get("gradingScale") : null;
        if (arr == null || !arr.isArray() || arr.isEmpty()) {
            return DEFAULT_GRADING_SCALE;
        }
        List<GradeBand> out = new ArrayList<>();
        for (JsonNode g : arr) {
            out.add(new GradeBand(
                    BigDecimal.valueOf(g.path("min").asDouble()),
                    g.path("label").asText(""),
                    g.path("proposal").asText("")));
        }
        out.sort(Comparator.comparing(GradeBand::min).reversed());
        return out;
    }

    /** Xếp loại theo % tổng điểm / điểm chuẩn. */
    public static String gradeFor(BigDecimal total, BigDecimal maxTotal, List<GradeBand> scale) {
        List<GradeBand> bands = scale == null || scale.isEmpty() ? DEFAULT_GRADING_SCALE : scale;
        String lowest = bands.get(bands.size() - 1).label();
        if (total == null || maxTotal == null || maxTotal.compareTo(BigDecimal.ZERO) <= 0) {
            return lowest;
        }
        BigDecimal pct = total.multiply(new BigDecimal("100")).divide(maxTotal, 2, RoundingMode.HALF_UP);
        for (GradeBand b : bands) {
            if (pct.compareTo(b.min()) >= 0) {
                return b.label();
            }
        }
        return lowest;
    }

    // ------------------------------------------------------------------ chỉnh sửa mẫu

    @Transactional(readOnly = true)
    @PreAuthorize("hasAnyRole('ADMIN','HEAD_NURSING')")
    public Map<String, Object> editorState(String code) {
        JsonNode defaults = getDefaultTemplate(code);
        Optional<NursingEvaluationTemplateRevision> latest =
                revisionRepository.findFirstByTemplateCodeOrderByVersionDesc(code);
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("template", toUi(latest.map(this::parseRevision).orElse(defaults)));
        m.put("version", latest.map(NursingEvaluationTemplateRevision::getVersion)
                .orElse(defaults.path("version").asInt(1)));
        m.put("isDefault", latest.isEmpty());
        m.put("defaultVersion", defaults.path("version").asInt(1));
        m.put("updatedAt", latest.map(r -> r.getCreatedAt().toString()).orElse(null));
        m.put("updatedBy", latest.map(r -> displayName(r.getCreatedBy())).orElse(null));
        m.put("changeNote", latest.map(NursingEvaluationTemplateRevision::getChangeNote).orElse(null));
        return m;
    }

    @Transactional(readOnly = true)
    @PreAuthorize("hasAnyRole('ADMIN','HEAD_NURSING')")
    public List<Map<String, Object>> listRevisions(String code) {
        getDefaultTemplate(code);
        List<NursingEvaluationTemplateRevision> revisions = revisionRepository.findByTemplateCodeOrderByVersionDesc(code);
        List<Map<String, Object>> out = new ArrayList<>();
        for (int i = 0; i < revisions.size(); i++) {
            NursingEvaluationTemplateRevision r = revisions.get(i);
            JsonNode tpl = parseRevision(r);
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("id", r.getId());
            m.put("version", r.getVersion());
            m.put("current", i == 0);
            m.put("createdAt", r.getCreatedAt().toString());
            m.put("createdBy", displayName(r.getCreatedBy()));
            m.put("changeNote", r.getChangeNote());
            m.put("name", text(tpl, "name"));
            m.put("criteriaCount", tpl.path("criteriaGroups").size());
            m.put("baseMaxPoints", tpl.path("baseMaxPoints").numberValue());
            out.add(m);
        }
        return out;
    }

    @Transactional(readOnly = true)
    @PreAuthorize("hasAnyRole('ADMIN','HEAD_NURSING')")
    public Map<String, Object> revisionTemplate(String code, Long revisionId) {
        return toUi(parseRevision(requireRevision(code, revisionId)));
    }

    @Transactional
    @PreAuthorize("hasAnyRole('ADMIN','HEAD_NURSING')")
    public Map<String, Object> save(String code, NursingEvaluationTemplateSaveRequest req) {
        if (req.getTemplate() == null) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Thiếu nội dung mẫu đánh giá");
        }
        int next = assertBaseVersion(code, req.getBaseVersion()) + 1;
        persist(code, normalize(code, req.getTemplate(), next), next, req.getChangeNote());
        return editorState(code);
    }

    @Transactional
    @PreAuthorize("hasAnyRole('ADMIN','HEAD_NURSING')")
    public Map<String, Object> restoreRevision(String code, Long revisionId, NursingEvaluationTemplateSaveRequest req) {
        NursingEvaluationTemplateRevision source = requireRevision(code, revisionId);
        int next = assertBaseVersion(code, req.getBaseVersion()) + 1;
        String note = blankToNull(req.getChangeNote());
        persist(code, normalize(code, parseRevision(source), next), next,
                note != null ? note : "Khôi phục từ phiên bản v" + source.getVersion());
        return editorState(code);
    }

    @Transactional
    @PreAuthorize("hasAnyRole('ADMIN','HEAD_NURSING')")
    public Map<String, Object> resetToDefault(String code, NursingEvaluationTemplateSaveRequest req) {
        JsonNode defaults = getDefaultTemplate(code);
        int next = assertBaseVersion(code, req.getBaseVersion()) + 1;
        String note = blankToNull(req.getChangeNote());
        persist(code, normalize(code, defaults, next), next,
                note != null ? note : "Khôi phục mẫu gốc (v" + defaults.path("version").asInt(1) + ")");
        return editorState(code);
    }

    private NursingEvaluationTemplateRevision requireRevision(String code, Long revisionId) {
        return revisionRepository.findByIdAndTemplateCode(revisionId, code)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy phiên bản mẫu"));
    }

    /** @return phiên bản hiện tại (đã khớp với phiên bản người sửa tải về). */
    private int assertBaseVersion(String code, Integer baseVersion) {
        JsonNode defaults = getDefaultTemplate(code);
        int current = revisionRepository.findFirstByTemplateCodeOrderByVersionDesc(code)
                .map(NursingEvaluationTemplateRevision::getVersion)
                .orElse(defaults.path("version").asInt(1));
        if (baseVersion == null || baseVersion != current) {
            throw new ApiException(HttpStatus.CONFLICT,
                    "Mẫu đã được cập nhật lên phiên bản v" + current
                            + " trong lúc bạn chỉnh sửa. Tải lại mẫu rồi thực hiện lại.");
        }
        return current;
    }

    private void persist(String code, ObjectNode template, int version, String changeNote) {
        String json;
        try {
            json = objectMapper.writeValueAsString(template);
        } catch (IOException e) {
            throw new ApiException(HttpStatus.INTERNAL_SERVER_ERROR, "Không lưu được mẫu đánh giá");
        }
        NursingEvaluationTemplateRevision r = NursingEvaluationTemplateRevision.builder()
                .templateCode(code)
                .version(version)
                .templateJson(json)
                .changeNote(blankToNull(changeNote))
                .createdBy(employeeService.currentUser())
                .build();
        try {
            revisionRepository.saveAndFlush(r);
        } catch (DataIntegrityViolationException e) {
            throw new ApiException(HttpStatus.CONFLICT,
                    "Mẫu vừa được người khác lưu cùng lúc. Tải lại mẫu rồi thực hiện lại.");
        }
    }

    // ------------------------------------------------------------------ kiểm tra + chuẩn hoá

    private enum Kind { NORMAL, BONUS, PENALTY }

    private static final class SectionAcc {
        final Kind kind;
        BigDecimal points = BigDecimal.ZERO;
        int count;

        SectionAcc(Kind kind) {
            this.kind = kind;
        }
    }

    /**
     * Kiểm tra mẫu và tính lại các trường suy ra: STT trong mục, điểm tối đa tiêu chí,
     * điểm mục, tổng điểm chuẩn, thứ tự thang xếp loại.
     */
    private ObjectNode normalize(String code, JsonNode in, int version) {
        if (in == null || !in.isObject()) {
            throw bad("Nội dung mẫu đánh giá không hợp lệ");
        }
        ObjectNode out = objectMapper.createObjectNode();
        out.put("code", code);
        out.put("name", requireText(in, "name", "Tên mẫu đánh giá", 255));
        out.put("version", version);

        JsonNode groups = in.get("criteriaGroups");
        if (groups == null || !groups.isArray() || groups.isEmpty()) {
            throw bad("Mẫu phải có ít nhất 1 tiêu chí");
        }
        if (groups.size() > MAX_CRITERIA) {
            throw bad("Mẫu tối đa " + MAX_CRITERIA + " tiêu chí");
        }

        Set<String> ids = new HashSet<>();
        Set<String> seenSections = new HashSet<>();
        Map<String, SectionAcc> sections = new LinkedHashMap<>();
        List<ObjectNode> outGroups = new ArrayList<>();
        String prevSection = null;

        for (int i = 0; i < groups.size(); i++) {
            JsonNode g = groups.get(i);
            String where = "Tiêu chí #" + (i + 1);
            String title = requireText(g, "title", where + " — tên tiêu chí", 500);
            where = "Tiêu chí \"" + shorten(title) + "\"";

            String id = requireText(g, "id", where + " — mã", 40);
            if (!ID_PATTERN.matcher(id).matches()) {
                throw bad(where + ": mã chỉ gồm chữ không dấu, số và dấu gạch dưới");
            }
            if (!ids.add(id)) {
                throw bad("Mã tiêu chí bị trùng: " + id);
            }
            if (id.startsWith("HD_")) {
                throw bad(where + ": mã không được bắt đầu bằng HD_ (dành cho Hội đồng)");
            }

            boolean bonus = g.path("bonus").asBoolean(false);
            boolean penalty = g.path("penalty").asBoolean(false);
            if (bonus && penalty) {
                throw bad(where + ": không thể vừa là điểm thưởng vừa là điểm trừ");
            }
            // Bản mobile đã phát hành nhận diện thưởng / trừ theo tiền tố mã.
            if (id.startsWith("VI_") && !bonus) {
                throw bad(where + ": mã VI_ chỉ dùng cho tiêu chí điểm thưởng");
            }
            if (id.startsWith("VII_") && !penalty) {
                throw bad(where + ": mã VII_ chỉ dùng cho tiêu chí điểm trừ");
            }
            Kind kind = bonus ? Kind.BONUS : penalty ? Kind.PENALTY : Kind.NORMAL;

            String section = requireText(g, "section", where + " — tên mục", 255);
            if (!section.equals(prevSection)) {
                if (!seenSections.add(section)) {
                    throw bad("Mục \"" + shorten(section) + "\" bị tách rời — các tiêu chí cùng mục phải liền nhau");
                }
                prevSection = section;
            }
            SectionAcc acc = sections.computeIfAbsent(section, s -> new SectionAcc(kind));
            if (acc.kind != kind) {
                throw bad("Mục \"" + shorten(section) + "\" lẫn tiêu chí tính điểm / thưởng / trừ");
            }

            JsonNode opts = g.get("options");
            if (opts == null || !opts.isArray() || opts.isEmpty()) {
                throw bad(where + ": cần ít nhất 1 mức điểm");
            }
            if (opts.size() > MAX_OPTIONS) {
                throw bad(where + ": tối đa " + MAX_OPTIONS + " mức điểm");
            }
            ArrayNode outOpts = objectMapper.createArrayNode();
            Set<BigDecimal> points = new HashSet<>();
            BigDecimal max = BigDecimal.ZERO;
            for (int j = 0; j < opts.size(); j++) {
                JsonNode o = opts.get(j);
                String optWhere = where + " — mức " + (j + 1);
                String label = requireText(o, "label", optWhere + ": mô tả", 1000);
                BigDecimal p = requirePoints(o.get("points"), optWhere);
                if (!points.add(p.stripTrailingZeros())) {
                    throw bad(where + ": có 2 mức cùng " + plain(p) + " điểm");
                }
                max = max.max(p);
                ObjectNode on = objectMapper.createObjectNode();
                on.put("label", label);
                on.put("points", p.doubleValue());
                outOpts.add(on);
            }

            acc.count++;
            acc.points = acc.points.add(max);

            ObjectNode og = objectMapper.createObjectNode();
            og.put("id", id);
            og.put("section", section);
            og.put("no", String.valueOf(acc.count));
            og.put("title", title);
            og.put("maxPoints", max.doubleValue());
            og.set("options", outOpts);
            if (bonus) og.put("bonus", true);
            if (penalty) og.put("penalty", true);
            outGroups.add(og);
        }

        BigDecimal base = BigDecimal.ZERO;
        for (SectionAcc acc : sections.values()) {
            if (acc.kind == Kind.NORMAL) base = base.add(acc.points);
        }
        if (base.compareTo(BigDecimal.ZERO) <= 0) {
            throw bad("Cần ít nhất 1 tiêu chí tính điểm có điểm tối đa lớn hơn 0");
        }

        ArrayNode criteria = objectMapper.createArrayNode();
        for (ObjectNode og : outGroups) {
            SectionAcc acc = sections.get(og.get("section").asText());
            if (acc.kind == Kind.NORMAL) {
                og.put("sectionPoints", acc.points.doubleValue());
            } else {
                og.putNull("sectionPoints");
            }
            criteria.add(og);
        }

        out.put("baseMaxPoints", base.doubleValue());
        String note = optText(in, "note", "Ghi chú", 2000);
        if (note != null) out.put("note", note);
        out.set("criteriaGroups", criteria);
        out.set("gradingScale", normalizeGradingScale(in.get("gradingScale")));
        return out;
    }

    private ArrayNode normalizeGradingScale(JsonNode in) {
        List<GradeBand> bands = new ArrayList<>();
        if (in == null || in.isNull() || (in.isArray() && in.isEmpty())) {
            bands.addAll(DEFAULT_GRADING_SCALE);
        } else {
            if (!in.isArray()) throw bad("Thang xếp loại không hợp lệ");
            if (in.size() > MAX_GRADES) throw bad("Thang xếp loại tối đa " + MAX_GRADES + " mức");
            Set<BigDecimal> mins = new HashSet<>();
            Set<String> labels = new HashSet<>();
            for (int i = 0; i < in.size(); i++) {
                JsonNode g = in.get(i);
                String where = "Xếp loại #" + (i + 1);
                String label = requireText(g, "label", where + ": tên xếp loại", 64);
                where = "Xếp loại \"" + label + "\"";
                if (!labels.add(label.toLowerCase(Locale.ROOT))) {
                    throw bad("Tên xếp loại bị trùng: " + label);
                }
                BigDecimal min = requirePoints(g.get("min"), where + ": ngưỡng");
                if (min.compareTo(new BigDecimal("100")) > 0) {
                    throw bad(where + ": ngưỡng tối đa 100%");
                }
                if (!mins.add(min.stripTrailingZeros())) {
                    throw bad("Hai xếp loại cùng ngưỡng " + plain(min) + "%");
                }
                String proposal = optText(g, "proposal", where + ": đề xuất", 255);
                bands.add(new GradeBand(min, label, proposal != null ? proposal : ""));
            }
        }
        bands.sort(Comparator.comparing(GradeBand::min).reversed());
        if (bands.get(bands.size() - 1).min().compareTo(BigDecimal.ZERO) != 0) {
            throw bad("Thang xếp loại cần một mức có ngưỡng 0 (mức thấp nhất)");
        }
        ArrayNode out = objectMapper.createArrayNode();
        for (GradeBand b : bands) {
            ObjectNode n = objectMapper.createObjectNode();
            n.put("min", b.min().doubleValue());
            n.put("label", b.label());
            n.put("proposal", b.proposal());
            out.add(n);
        }
        return out;
    }

    private static BigDecimal requirePoints(JsonNode n, String where) {
        BigDecimal p;
        try {
            if (n == null || n.isNull() || (n.isTextual() && n.asText().isBlank())) {
                throw bad(where + ": chưa nhập điểm");
            }
            p = n.isNumber() ? n.decimalValue() : new BigDecimal(n.asText().trim().replace(',', '.'));
        } catch (NumberFormatException e) {
            throw bad(where + ": điểm không phải số");
        }
        p = p.setScale(2, RoundingMode.HALF_UP);
        if (p.compareTo(BigDecimal.ZERO) < 0) {
            throw bad(where + ": điểm không được âm");
        }
        if (p.compareTo(MAX_OPTION_POINTS) > 0) {
            throw bad(where + ": điểm quá lớn");
        }
        return p;
    }

    private static String requireText(JsonNode n, String field, String label, int maxLen) {
        String v = optText(n, field, label, maxLen);
        if (v == null) {
            throw bad(label + " không được để trống");
        }
        return v;
    }

    private static String optText(JsonNode n, String field, String label, int maxLen) {
        JsonNode v = n != null ? n.get(field) : null;
        if (v == null || v.isNull()) return null;
        String s = v.asText("").trim();
        if (s.isEmpty()) return null;
        if (s.length() > maxLen) {
            throw bad(label + " quá dài (tối đa " + maxLen + " ký tự)");
        }
        return s;
    }

    private static ApiException bad(String message) {
        return new ApiException(HttpStatus.BAD_REQUEST, message);
    }

    private static String shorten(String s) {
        return s.length() > 48 ? s.substring(0, 47) + "…" : s;
    }

    private static String plain(BigDecimal v) {
        return v.stripTrailingZeros().toPlainString();
    }

    private static String displayName(UserAccount u) {
        if (u == null) return null;
        return u.getDisplayName() != null && !u.getDisplayName().isBlank() ? u.getDisplayName() : u.getUsername();
    }

    private static String text(JsonNode n, String field) {
        return n.has(field) && !n.get(field).isNull() ? n.get(field).asText() : "";
    }

    private static String blankToNull(String s) {
        return s == null || s.isBlank() ? null : s.trim();
    }
}
