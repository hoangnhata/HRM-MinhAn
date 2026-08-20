package com.minhan.hrm.assistant;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.minhan.hrm.config.HrmProperties;
import com.minhan.hrm.dto.assistant.HrAssistantChatResponse;
import com.minhan.hrm.entity.UserAccount;
import com.minhan.hrm.exception.ApiException;
import com.minhan.hrm.service.EmployeeService;
import lombok.extern.slf4j.Slf4j;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;
import org.springframework.web.client.ResourceAccessException;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientResponseException;

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.UUID;

@Slf4j
@Service
public class HrAssistantService {

    private static final Logger AUDIT = LoggerFactory.getLogger("HR_ASSISTANT_AUDIT");
    private static final String OUT_OF_SCOPE_ANSWER = """
            Tôi chỉ hỗ trợ các nội dung liên quan đến phần mềm HRM Minh An như công, phép, lịch làm việc, đơn từ, lương và hướng dẫn sử dụng.

            Bạn vui lòng đặt câu hỏi trong phạm vi này để tôi hỗ trợ chính xác nhất.
            """.trim();
    private static final Set<String> OUT_OF_SCOPE_HINTS = Set.of(
            "thời tiết", "tin tức", "bóng đá", "chứng khoán", "bitcoin", "tiền ảo",
            "làm thơ", "kể chuyện", "nấu ăn", "viết code", "lập trình", "giải phương trình",
            "chính trị", "tổng thống", "dịch sang tiếng");
    private static final Set<String> HRM_HINTS = Set.of(
            "hrm", "phần mềm", "website", "trang web", "công", "chấm", "phép", "nghỉ",
            "đơn", "điều động", "lịch", "ca làm", "lương", "nhân viên", "hồ sơ", "tài khoản",
            "mật khẩu", "chữ ký", "khoa", "phòng", "bộ phận", "đánh giá", "xếp loại",
            "thang bảng", "nâng bậc", "đi muộn", "về sớm", "hội thảo", "đào tạo");
    private static final String SYSTEM_INSTRUCTIONS = """
            Bạn là trợ lý chính thức bên trong phần mềm HRM Bệnh viện Minh An. Chỉ trả lời bằng tiếng Việt, rõ ràng, thân thiện và dễ đọc.
            NGUYÊN TẮC BẮT BUỘC:
            1. Với dữ liệu cá nhân, công, phép, lịch hoặc trạng thái đơn: phải gọi đúng công cụ. Chỉ dùng kết quả công cụ, tuyệt đối không tự tạo hoặc suy đoán số liệu.
            2. Nếu công cụ báo không có dữ liệu/không đủ dữ liệu, nói rõ điều đó và hướng dẫn người dùng kiểm tra hoặc liên hệ HCNS.
            3. Không yêu cầu hay nhắc lại employeeId. Khi cần xem người khác, chỉ truyền employee_query là họ tên hoặc mã nhân viên; backend tự kiểm tra quyền.
            4. Không hỏi, tiết lộ hoặc suy luận CCCD, tài khoản ngân hàng, mật khẩu, access token, API key hay dữ liệu nhạy cảm không cần thiết.
            5. Chỉ được đọc và hướng dẫn. Không được tạo đơn, duyệt đơn, sửa công, sửa hồ sơ hoặc thực hiện hành động làm thay đổi dữ liệu.
            6. Không nói rằng bạn đã kiểm tra hệ thống nếu chưa gọi công cụ. Có thể giải thích tên trạng thái bằng tiếng Việt dễ hiểu.
            7. PHẠM VI DUY NHẤT: chức năng và dữ liệu của HRM Minh An, gồm công/chấm công, ca và lịch làm việc, phép, đơn từ, điều động, lương/thang bảng lương/nâng bậc, hồ sơ tài khoản, đánh giá xếp loại và hướng dẫn sử dụng phần mềm.
            8. Nếu câu hỏi ngoài phạm vi trên (ví dụ tin tức, thời tiết, y khoa, pháp luật, chính trị, giải trí, lập trình hoặc kiến thức chung), không trả lời nội dung câu hỏi. Chỉ trả lời đúng thông báo: "Tôi chỉ hỗ trợ các nội dung liên quan đến phần mềm HRM Minh An như công, phép, lịch làm việc, đơn từ, lương và hướng dẫn sử dụng. Bạn vui lòng đặt câu hỏi trong phạm vi này để tôi hỗ trợ chính xác nhất."
            9. CÁCH TRÌNH BÀY: mở đầu bằng kết luận trực tiếp. Khi có nhiều thông tin, dùng tiêu đề ngắn như "### Kết quả", "### Chi tiết", "### Bạn cần làm gì" và danh sách gạch đầu dòng. Chỉ tạo các mục thực sự cần thiết, không lặp lại.
            10. Hiển thị ngày theo dd/MM/yyyy, giờ theo HH:mm; chuyển mã trạng thái kỹ thuật thành tiếng Việt dễ hiểu. Phân biệt rõ dữ liệu thực tế lấy từ HRM với hướng dẫn thao tác chung.
            11. Câu trả lời phải đủ ý để người dùng tự xử lý bước tiếp theo, nhưng không dài dòng. Không dùng bảng trừ khi việc so sánh nhiều dòng thực sự cần thiết.
            12. Không dùng LaTeX hoặc ký hiệu dạng $\\rightarrow$, $\\to$. Khi hướng dẫn đường dẫn menu, chỉ dùng ký hiệu Unicode →, ví dụ: Công & đơn → Đơn.
            13. Với mọi câu hỏi "cách làm", "hướng dẫn", "ở đâu", "tạo/lập/gắn" một chức năng HRM, bắt buộc gọi get_usage_guidance trước khi trả lời. Không được suy đoán vị trí menu, tên nút, trường nhập hoặc quyền thao tác từ kiến thức chung.
            14. Đặc biệt: đơn điều động KHÔNG được tạo tại màn Đơn → Tạo đơn. Phải trình bày đúng đường dẫn do công cụ get_usage_guidance trả về và nói rõ quyền theo vai trò.
            15. Khi trả lời hướng dẫn, chỉ dùng các bước, nhãn nút, trường nhập và lưu ý do get_usage_guidance trả về; không tự thêm tệp đính kèm, đơn vị/vị trí công tác hoặc bước thao tác không có trong kết quả công cụ.
            16. Luôn tuân thủ kết quả phân quyền của công cụ: EMPLOYEE chỉ dữ liệu bản thân; HEAD_DEPARTMENT chỉ khoa/phòng hoặc bộ phận quản lý; HR2 chỉ đọc dữ liệu công toàn viện; HEAD_HR = trưởng khoa/phòng HCNS + toàn bộ chức năng HCNS 2 (không gồm HCNS 1); ADMIN/HR/DIRECTOR chỉ được xem đúng nhóm dữ liệu mà API nội bộ cho phép. Khi bị từ chối, giải thích ngắn gọn phạm vi quyền, không gợi ý cách vượt quyền.
            17. Khi người dùng hỏi "log máy chấm", "giờ log", "lần quẹt", "giờ quẹt thẻ/vân tay" của một ngày, bắt buộc gọi get_attendance_machine_logs. Phải nêu tên nhân viên, ngày, tổng số lần log và liệt kê ĐỦ mọi giờ theo đúng thứ tự; sau đó mới nêu giờ sáng/chiều hệ thống suy ra. Không được bỏ bớt log, gộp log hoặc tự tạo giờ.
            """;

    private final RestClient restClient;
    private final ObjectMapper objectMapper;
    private final HrmProperties properties;
    private final EmployeeService employeeService;
    private final HrAssistantToolService toolService;
    private final HrAssistantRateLimiter rateLimiter;

    public HrAssistantService(
            @Qualifier("hrAssistantRestClient") RestClient restClient,
            ObjectMapper objectMapper,
            HrmProperties properties,
            EmployeeService employeeService,
            HrAssistantToolService toolService,
            HrAssistantRateLimiter rateLimiter) {
        this.restClient = restClient;
        this.objectMapper = objectMapper;
        this.properties = properties;
        this.employeeService = employeeService;
        this.toolService = toolService;
        this.rateLimiter = rateLimiter;
    }

    public HrAssistantChatResponse chat(String message) {
        HrmProperties.Assistant cfg = properties.getAssistant();
        if (!cfg.isEnabled() || cfg.getApiKey() == null || cfg.getApiKey().isBlank()) {
            throw new ApiException(HttpStatus.SERVICE_UNAVAILABLE,
                    "Trợ lý AI chưa được cấu hình. Quản trị viên cần bật HR_ASSISTANT_ENABLED và cấu hình API key ở backend.");
        }
        UserAccount caller = employeeService.currentUser();
        rateLimiter.check(caller.getUsername());
        String requestId = UUID.randomUUID().toString();
        if (isClearlyOutOfScope(message)) {
            AUDIT.info("requestId={} username={} role={} rejected=out_of_scope",
                    requestId, caller.getUsername(), caller.getRole());
            return HrAssistantChatResponse.builder()
                    .requestId(requestId)
                    .answer(OUT_OF_SCOPE_ANSWER)
                    .usedTools(List.of())
                    .build();
        }
        List<Object> messages = new ArrayList<>();
        messages.add(Map.of(
                "role", "system",
                "content", SYSTEM_INSTRUCTIONS
                        + "\nNgày hiện tại: " + LocalDate.now()
                        + ". Vai trò tài khoản: " + caller.getRole() + "."));
        messages.add(Map.of("role", "user", "content", message.trim()));
        Set<String> usedTools = new LinkedHashSet<>();
        int toolCalls = 0;
        boolean forceFinal = false;

        for (int round = 0; round < Math.max(1, cfg.getMaxRounds()); round++) {
            Map<String, Object> body = new LinkedHashMap<>();
            body.put("model", cfg.getModel());
            body.put("messages", messages);
            body.put("tools", toolDefinitions());
            body.put("tool_choice", forceFinal ? "none" : "auto");
            body.put("max_tokens", 1400);
            body.put("temperature", 0.2);
            body.put("reasoning_effort", cfg.getReasoningEffort());

            JsonNode response = callOpenAi(body, requestId);
            JsonNode assistantMessage = response.path("choices").path(0).path("message");
            if (!assistantMessage.isObject()) {
                throw new ApiException(HttpStatus.BAD_GATEWAY, "Dịch vụ AI trả về dữ liệu không hợp lệ");
            }
            messages.add(assistantMessage);
            List<JsonNode> calls = new ArrayList<>();
            assistantMessage.path("tool_calls").forEach(calls::add);
            if (calls.isEmpty()) {
                String answer = assistantMessage.path("content").asText("").trim();
                if (answer.isBlank()) {
                    answer = "Tôi chưa thể tạo câu trả lời từ dữ liệu hiện có. Vui lòng hỏi lại cụ thể hơn.";
                }
                return HrAssistantChatResponse.builder()
                        .requestId(requestId)
                        .answer(answer)
                        .usedTools(List.copyOf(usedTools))
                        .build();
            }

            for (JsonNode call : calls) {
                String name = call.path("function").path("name").asText();
                String callId = call.path("id").asText();
                if (toolCalls >= Math.max(1, cfg.getMaxToolCalls())) {
                    AUDIT.warn("requestId={} username={} role={} tool={} argumentKeys=[] success=false durationMs=0 rejected=max_tool_calls",
                            requestId, caller.getUsername(), caller.getRole(), name);
                    messages.add(toolOutput(callId, Map.of(
                            "ok", false,
                            "error", "Đã đạt giới hạn số lần gọi công cụ; hãy trả lời bằng dữ liệu đã có.")));
                    forceFinal = true;
                    continue;
                }
                toolCalls++;
                usedTools.add(name);
                JsonNode arguments = parseArguments(call.path("function").path("arguments").asText("{}"));
                long started = System.nanoTime();
                boolean success = false;
                Map<String, Object> result;
                try {
                    result = toolService.execute(name, arguments);
                    success = true;
                } catch (Exception ex) {
                    result = Map.of("ok", false, "error", safeToolError(ex));
                } finally {
                    long durationMs = (System.nanoTime() - started) / 1_000_000L;
                    AUDIT.info("requestId={} username={} role={} tool={} argumentKeys={} success={} durationMs={}",
                            requestId, caller.getUsername(), caller.getRole(), name,
                            argumentKeys(arguments), success, durationMs);
                }
                messages.add(toolOutput(callId, result));
            }
        }
        throw new ApiException(HttpStatus.BAD_GATEWAY,
                "Trợ lý chưa hoàn tất câu trả lời trong giới hạn an toàn. Vui lòng hỏi ngắn gọn hơn.");
    }

    private JsonNode callOpenAi(Map<String, Object> body, String requestId) {
        try {
            return postChatCompletion(body, requestId);
        } catch (RestClientResponseException ex) {
            HrmProperties.Assistant cfg = properties.getAssistant();
            String fallback = cfg.getFallbackModel() == null ? "" : cfg.getFallbackModel().trim();
            String currentModel = String.valueOf(body.getOrDefault("model", ""));
            int providerStatus = ex.getStatusCode().value();
            if ((providerStatus == 400 || providerStatus == 429)
                    && !fallback.isBlank()
                    && !fallback.equals(currentModel)) {
                Map<String, Object> fallbackBody = new LinkedHashMap<>(body);
                fallbackBody.put("model", fallback);
                // Mỗi dòng model hỗ trợ tập giá trị reasoning_effort khác nhau;
                // dùng mặc định của model dự phòng để tránh lỗi tương thích 400.
                fallbackBody.remove("reasoning_effort");
                log.warn("HR assistant primary failed: status={} requestId={} model={}; trying fallback={}",
                        providerStatus, requestId, currentModel, fallback);
                try {
                    return postChatCompletion(fallbackBody, requestId);
                } catch (RestClientResponseException fallbackEx) {
                    throw providerApiException(fallbackEx, requestId, fallback);
                } catch (ResourceAccessException fallbackEx) {
                    throw new ApiException(HttpStatus.GATEWAY_TIMEOUT,
                            "Dịch vụ AI dự phòng phản hồi quá chậm. Vui lòng thử lại.");
                } catch (JsonProcessingException fallbackEx) {
                    throw new ApiException(HttpStatus.BAD_GATEWAY, "Không đọc được phản hồi từ dịch vụ AI dự phòng");
                }
            }
            throw providerApiException(ex, requestId, currentModel);
        } catch (ResourceAccessException ex) {
            log.warn("HR assistant provider timeout: requestId={}", requestId);
            throw new ApiException(HttpStatus.GATEWAY_TIMEOUT, "Dịch vụ AI phản hồi quá chậm. Vui lòng thử lại.");
        } catch (JsonProcessingException ex) {
            throw new ApiException(HttpStatus.BAD_GATEWAY, "Không đọc được phản hồi từ dịch vụ AI");
        }
    }

    private JsonNode postChatCompletion(Map<String, Object> body, String requestId)
            throws JsonProcessingException {
        String raw = restClient.post()
                .uri("/chat/completions")
                .contentType(MediaType.APPLICATION_JSON)
                .header("Authorization", "Bearer " + properties.getAssistant().getApiKey())
                .header("X-Client-Request-Id", requestId)
                .body(body)
                .retrieve()
                .body(String.class);
        return objectMapper.readTree(raw == null ? "{}" : raw);
    }

    private ApiException providerApiException(
            RestClientResponseException ex,
            String requestId,
            String model) {
        int status = ex.getStatusCode().value();
        log.warn("HR assistant provider error: status={} requestId={} model={}", status, requestId, model);
        if (status == 429) {
            return new ApiException(HttpStatus.TOO_MANY_REQUESTS,
                    "Dịch vụ AI đã hết hạn mức hoặc đang bị giới hạn tần suất. Vui lòng thử lại sau; quản trị viên cần kiểm tra quota/billing của nhà cung cấp AI.");
        }
        if (status == 401 || status == 403) {
            return new ApiException(HttpStatus.BAD_GATEWAY,
                    "Dịch vụ AI không chấp nhận API key hoặc dự án chưa được cấp quyền.");
        }
        if (status == 404) {
            return new ApiException(HttpStatus.BAD_GATEWAY,
                    "Model AI đang cấu hình không tồn tại hoặc không còn được hỗ trợ.");
        }
        if (status == 400) {
            return new ApiException(HttpStatus.BAD_GATEWAY,
                    "Dịch vụ AI không chấp nhận định dạng yêu cầu hiện tại.");
        }
        return new ApiException(HttpStatus.BAD_GATEWAY,
                "Dịch vụ AI tạm thời không xử lý được yêu cầu. Vui lòng thử lại sau.");
    }

    private boolean isClearlyOutOfScope(String message) {
        String normalized = message == null ? "" : message.toLowerCase(Locale.ROOT);
        boolean hasOutsideHint = OUT_OF_SCOPE_HINTS.stream().anyMatch(normalized::contains);
        boolean hasHrmContext = HRM_HINTS.stream().anyMatch(normalized::contains);
        return hasOutsideHint && !hasHrmContext;
    }

    private JsonNode parseArguments(String raw) {
        try {
            JsonNode node = objectMapper.readTree(raw == null || raw.isBlank() ? "{}" : raw);
            return node != null && node.isObject() ? node : objectMapper.createObjectNode();
        } catch (JsonProcessingException ex) {
            return objectMapper.createObjectNode();
        }
    }

    private Map<String, Object> toolOutput(String callId, Map<String, Object> result) {
        try {
            return Map.of(
                    "role", "tool",
                    "tool_call_id", callId,
                    "content", objectMapper.writeValueAsString(result));
        } catch (JsonProcessingException ex) {
            return Map.of(
                    "role", "tool",
                    "tool_call_id", callId,
                    "content", "{\"ok\":false,\"error\":\"Không thể mã hóa kết quả công cụ\"}");
        }
    }

    private String safeToolError(Exception ex) {
        if (ex instanceof ApiException api) {
            return api.getMessage();
        }
        log.warn("HR assistant tool failed: {}", ex.getClass().getSimpleName());
        return "Không thể lấy dữ liệu từ chức năng nội bộ";
    }

    private List<String> argumentKeys(JsonNode args) {
        List<String> keys = new ArrayList<>();
        if (args != null && args.isObject()) args.fieldNames().forEachRemaining(keys::add);
        return keys;
    }

    private List<Map<String, Object>> toolDefinitions() {
        return List.of(
                tool("get_leave_balance", "Lấy hạn mức, đã dùng, đang chờ và số ngày phép năm còn lại. Mặc định của người đăng nhập.",
                        props(Map.of(
                                "year", scalar("integer", "Năm cần xem; bỏ trống nếu là năm hiện tại"),
                                "employee_query", scalar("string", "Họ tên hoặc mã nhân viên; bỏ trống nếu hỏi bản thân")),
                                List.of())),
                tool("get_missing_attendance", "Liệt kê các bản ghi thể hiện thiếu/quên chấm công trong khoảng ngày; mặc định từ đầu tháng tới hôm nay.",
                        props(Map.of(
                                "from", scalar("string", "Ngày bắt đầu YYYY-MM-DD; có thể bỏ trống"),
                                "to", scalar("string", "Ngày kết thúc YYYY-MM-DD; có thể bỏ trống"),
                                "employee_query", scalar("string", "Họ tên/mã nhân viên; bỏ trống cho bản thân")),
                                List.of())),
                tool("explain_attendance_day", "Lấy dữ liệu chấm công và công được tính của đúng một ngày để giải thích vì sao chưa có công.",
                        props(Map.of(
                                "date", scalar("string", "Ngày YYYY-MM-DD"),
                                "employee_query", scalar("string", "Họ tên/mã nhân viên; bỏ trống cho bản thân")),
                                List.of("date"))),
                tool("get_attendance_machine_logs", "Lấy đầy đủ mọi giờ log/lần quẹt từ máy chấm công của một nhân viên trong đúng một ngày, kèm giờ ca hệ thống suy ra. Bắt buộc dùng khi câu hỏi nhắc log máy chấm, giờ log, quẹt thẻ hoặc vân tay.",
                        props(Map.of(
                                "date", scalar("string", "Ngày cần xem YYYY-MM-DD"),
                                "employee_query", scalar("string", "Họ tên hoặc mã nhân viên; bỏ trống nếu hỏi bản thân")),
                                List.of("date"))),
                tool("get_latest_deployment_request", "Lấy đơn điều động gần nhất của chính người đăng nhập và trạng thái duyệt.",
                        props(Map.of(), List.of())),
                tool("get_week_schedule", "Lấy lịch ca từ thứ Hai đến Chủ nhật của tuần chứa ngày tham chiếu.",
                        props(Map.of(
                                "week_reference", scalar("string", "Một ngày trong tuần cần xem, YYYY-MM-DD; bỏ trống là tuần hiện tại"),
                                "employee_query", scalar("string", "Họ tên/mã nhân viên; bỏ trống cho bản thân")),
                                List.of())),
                tool("get_pending_leave_requests", "Lấy các đơn nghỉ phép đang chờ duyệt của chính người đăng nhập.",
                        props(Map.of(), List.of())),
                tool("get_leave_policy", "Lấy quy tắc phép năm đang được phần mềm HRM áp dụng.",
                        props(Map.of(), List.of())),
                tool("get_forgot_punch_guidance", "Hướng dẫn thao tác khi quên hoặc thiếu chấm công.",
                        props(Map.of(), List.of())),
                tool("get_usage_guidance", "Tra cứu hướng dẫn chính xác theo giao diện và role hiện tại: vị trí menu, nút, các bước và giới hạn quyền. Bắt buộc dùng cho mọi câu hỏi cách sử dụng HRM, đặc biệt điều động, thao tác hàng loạt, đề xuất và ca thông tầm.",
                        props(Map.of("topic", scalar("string", "Chức năng người dùng cần hướng dẫn")), List.of("topic")))
        );
    }

    private Map<String, Object> tool(String name, String description, Map<String, Object> parameters) {
        return Map.of(
                "type", "function",
                "function", Map.of(
                        "name", name,
                        "description", description,
                        "parameters", parameters));
    }

    private Map<String, Object> props(Map<String, Object> properties, List<String> required) {
        return Map.of(
                "type", "object",
                "properties", properties,
                "required", required,
                "additionalProperties", false);
    }

    private Map<String, Object> scalar(String type, String description) {
        return Map.of("type", type, "description", description);
    }

}
