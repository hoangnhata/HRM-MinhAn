package com.minhan.hrm.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.minhan.hrm.dto.evaluation.NursingEvaluationTemplateSaveRequest;
import com.minhan.hrm.entity.NursingEvaluationTemplateRevision;
import com.minhan.hrm.entity.UserAccount;
import com.minhan.hrm.exception.ApiException;
import com.minhan.hrm.repository.NursingEvaluationTemplateRevisionRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.concurrent.atomic.AtomicLong;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

class NursingEvaluationTemplateServiceTest {

    private static final String CODE = "DD_KTV_HS_MA_2026";
    private static final AtomicLong IDS = new AtomicLong(1_000_000);

    private final ObjectMapper mapper = new ObjectMapper();
    private NursingEvaluationTemplateRevisionRepository repo;
    private NursingEvaluationTemplateService service;

    @BeforeEach
    void setUp() {
        repo = mock(NursingEvaluationTemplateRevisionRepository.class);
        EmployeeService employeeService = mock(EmployeeService.class);
        when(employeeService.currentUser()).thenReturn(new UserAccount());
        when(repo.findFirstByTemplateCodeOrderByVersionDesc(CODE)).thenReturn(Optional.empty());
        when(repo.saveAndFlush(any())).thenAnswer(inv -> {
            NursingEvaluationTemplateRevision r = inv.getArgument(0);
            r.setId(IDS.incrementAndGet());
            r.setCreatedAt(Instant.now());
            when(repo.findFirstByTemplateCodeOrderByVersionDesc(CODE)).thenReturn(Optional.of(r));
            return r;
        });
        service = new NursingEvaluationTemplateService(mapper, repo, employeeService);
    }

    private JsonNode lastSaved() throws Exception {
        ArgumentCaptor<NursingEvaluationTemplateRevision> cap = ArgumentCaptor.forClass(NursingEvaluationTemplateRevision.class);
        verify(repo, atLeastOnce()).saveAndFlush(cap.capture());
        return mapper.readTree(cap.getValue().getTemplateJson());
    }

    private NursingEvaluationTemplateSaveRequest req(int baseVersion, JsonNode template) {
        NursingEvaluationTemplateSaveRequest r = new NursingEvaluationTemplateSaveRequest();
        r.setBaseVersion(baseVersion);
        r.setTemplate(template);
        return r;
    }

    private ObjectNode defaultCopy() {
        return service.getDefaultTemplate(CODE).deepCopy();
    }

    private ApiException expectBad(JsonNode template) {
        ApiException e = assertThrows(ApiException.class, () -> service.save(CODE, req(4, template)));
        assertEquals(400, e.getStatus().value(), e.getMessage());
        return e;
    }

    @Test
    void resetNormalizesDefaultTemplateWithoutChangingIt() throws Exception {
        service.resetToDefault(CODE, req(4, null));
        JsonNode saved = lastSaved();

        assertEquals(5, saved.get("version").asInt());
        assertEquals(100.0, saved.get("baseMaxPoints").asDouble());
        JsonNode groups = saved.get("criteriaGroups");
        assertEquals(service.getDefaultTemplate(CODE).get("criteriaGroups").size(), groups.size());
        JsonNode first = groups.get(0);
        assertEquals("I_1", first.get("id").asText());
        assertEquals("1", first.get("no").asText());
        assertEquals(15.0, first.get("sectionPoints").asDouble());
        assertEquals(5.0, first.get("maxPoints").asDouble());
        JsonNode bonus = groups.get(15);
        assertEquals("VI_1", bonus.get("id").asText());
        assertTrue(bonus.get("bonus").asBoolean());
        assertTrue(bonus.get("sectionPoints").isNull());
        assertEquals(4, saved.get("gradingScale").size());
        assertEquals("Xuất sắc", saved.get("gradingScale").get(0).get("label").asText());
    }

    @Test
    void saveRecomputesNumberingAndPoints() throws Exception {
        ObjectNode tpl = defaultCopy();
        ArrayNode groups = (ArrayNode) tpl.get("criteriaGroups");
        // Thêm tiêu chí 8 điểm vào mục I (ngay sau I_3).
        ObjectNode extra = mapper.createObjectNode();
        extra.put("id", "C_NEW1");
        extra.put("section", "I. Tuân thủ nội quy");
        extra.put("title", "Tiêu chí mới");
        ArrayNode opts = extra.putArray("options");
        opts.addObject().put("label", "Tốt").put("points", "8");
        opts.addObject().put("label", "Chưa đạt").put("points", 0);
        groups.insert(3, extra);
        tpl.putArray("gradingScale")
                .add(mapper.createObjectNode().put("label", "Đạt").put("min", 50).put("proposal", ""))
                .add(mapper.createObjectNode().put("label", "Không đạt").put("min", 0).put("proposal", "Đào tạo lại"));

        service.save(CODE, req(4, tpl));
        JsonNode saved = lastSaved();

        JsonNode added = saved.get("criteriaGroups").get(3);
        assertEquals("4", added.get("no").asText());
        assertEquals(8.0, added.get("maxPoints").asDouble());
        assertEquals(23.0, added.get("sectionPoints").asDouble());
        assertEquals(23.0, saved.get("criteriaGroups").get(0).get("sectionPoints").asDouble());
        assertEquals(108.0, saved.get("baseMaxPoints").asDouble());
        assertEquals("Đạt", saved.get("gradingScale").get(0).get("label").asText());

        // Thang mới được dùng để xếp loại.
        List<NursingEvaluationTemplateService.GradeBand> scale = service.gradingScale(saved);
        assertEquals("Đạt", NursingEvaluationTemplateService.gradeFor(new BigDecimal("54"), new BigDecimal("108"), scale));
        assertEquals("Không đạt", NursingEvaluationTemplateService.gradeFor(new BigDecimal("53"), new BigDecimal("108"), scale));
    }

    @Test
    void staleBaseVersionIsRejected() {
        ApiException e = assertThrows(ApiException.class, () -> service.save(CODE, req(3, defaultCopy())));
        assertEquals(409, e.getStatus().value());
        verify(repo, never()).saveAndFlush(any());
    }

    @Test
    void duplicatePointsInCriterionAreRejected() {
        ObjectNode tpl = defaultCopy();
        ((ObjectNode) tpl.get("criteriaGroups").get(0).get("options").get(1)).put("points", 5);
        assertTrue(expectBad(tpl).getMessage().contains("cùng 5 điểm"));
    }

    @Test
    void bonusPrefixOnNormalCriterionIsRejected() {
        ObjectNode tpl = defaultCopy();
        ((ObjectNode) tpl.get("criteriaGroups").get(15)).remove("bonus");
        assertTrue(expectBad(tpl).getMessage().contains("VI_"));
    }

    @Test
    void splitSectionIsRejected() {
        ObjectNode tpl = defaultCopy();
        ArrayNode groups = (ArrayNode) tpl.get("criteriaGroups");
        JsonNode first = groups.remove(0);
        groups.insert(5, first);
        assertTrue(expectBad(tpl).getMessage().contains("tách rời"));
    }

    @Test
    void gradingScaleNeedsZeroThreshold() {
        ObjectNode tpl = defaultCopy();
        tpl.putArray("gradingScale").add(mapper.createObjectNode().put("label", "Tốt").put("min", 80));
        assertTrue(expectBad(tpl).getMessage().contains("ngưỡng 0"));
    }

    @Test
    void blankTitleIsRejected() {
        ObjectNode tpl = defaultCopy();
        ((ObjectNode) tpl.get("criteriaGroups").get(2)).put("title", "  ");
        assertTrue(expectBad(tpl).getMessage().contains("tên tiêu chí"));
    }

    @Test
    void currentTemplateFallsBackToDefaultThenUsesLatestRevision() throws Exception {
        assertEquals(4, service.getTemplate(CODE).get("version").asInt());
        service.resetToDefault(CODE, req(4, null));
        assertEquals(5, service.getTemplate(CODE).get("version").asInt());
        assertEquals(5, service.editorState(CODE).get("version"));
    }
}
