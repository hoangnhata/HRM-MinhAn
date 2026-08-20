package com.minhan.hrm.service;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.minhan.hrm.entity.ProbationFormType;
import com.minhan.hrm.exception.ApiException;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;

/**
 * Tiêu chí / xếp loại theo mẫu đơn Word:
 * - Bác sĩ: 6 nhóm × 0–5 = /30
 * - Điều dưỡng: 30+40+20+10 = /100
 * - Nhân viên: 30+40+20+10 = /100
 */
@Component
public class ProbationEvaluationHelper {

    public static final List<Criterion> DOCTOR_CRITERIA = List.of(
            new Criterion("knowledge", "Kiến thức chuyên môn", 5,
                    "Hiểu phác đồ điều trị, hướng dẫn BYT; nhận định, chẩn đoán ban đầu đúng; "
                            + "biết chỉ định cận lâm sàng hợp lý; hiểu được cơ bản về các thuốc thường dùng tại khoa phòng"),
            new Criterion("clinical", "Kỹ năng lâm sàng & thực hành", 5,
                    "Thăm khám, khai thác bệnh sử, biết đọc kết quả cận lâm sàng; thực hiện thủ thuật cơ bản (nếu có)"),
            new Criterion("admin", "Nghiệp vụ hành chính", 5,
                    "Hoàn thiện hồ sơ bệnh án, kê đơn, báo cáo theo quy định"),
            new Criterion("attitude", "Thái độ - đạo đức", 5,
                    "Tôn trọng, cảm thông với bệnh nhân; trung thực, cầu thị, không giấu sai sót; "
                            + "tuân thủ quy định BV, quy chế chuyên môn; hợp tác tốt với đồng nghiệp"),
            new Criterion("learning", "Học tập & phát triển", 5,
                    "Tham gia CME, đào tạo nội bộ; chủ động cập nhật kiến thức, tiếp thu góp ý, tinh thần cầu tiến"),
            new Criterion("effectiveness", "Hiệu quả công việc", 5,
                    "Hoàn thành trực & công việc được giao; hạn chế sai sót, đảm bảo an toàn người bệnh; "
                            + "được NB và người nhà hài lòng"));

    public static final List<Criterion> NURSE_CRITERIA = List.of(
            new Criterion("knowledge", "Kiến thức chuyên môn", 30,
                    "Nắm quy trình chăm sóc 5 bước; hiểu quy định an toàn người bệnh, KSNK; "
                            + "hiểu thuốc thường dùng và phản ứng phụ cơ bản; nắm kiến thức sơ cứu, cấp cứu ban đầu; "
                            + "nắm được phác đồ xử trí phản vệ, cấp cứu ban đầu"),
            new Criterion("practice", "Kỹ năng thực hành", 40,
                    "Thực hiện đúng các quy trình điều dưỡng cơ bản: đo sinh hiệu, ghi hồ sơ đầy đủ; "
                            + "thực hiện y lệnh chính xác; kỹ thuật cơ bản: tiêm truyền, thay băng, đặt sonde; "
                            + "sử dụng, bảo quản trang thiết bị y tế"),
            new Criterion("attitude", "Thái độ - đạo đức", 20,
                    "Tôn trọng, giao tiếp tốt với NB & thân nhân; tuân thủ quy chế chuyên môn, nội quy BV; "
                            + "tinh thần học hỏi, trung thực, không che giấu sai sót"),
            new Criterion("teamwork", "Phối hợp & học tập", 10,
                    "Hợp tác với đồng nghiệp, hỗ trợ kịp thời; chủ động xin ý kiến khi gặp tình huống khó; "
                            + "tham gia đào tạo nội bộ"));

    /** Theo mẫu Word nhân viên 2026 */
    public static final List<Criterion> STAFF_CRITERIA = List.of(
            new Criterion("knowledge", "Kiến thức chuyên môn", 30,
                    "Hiểu các quy định, quy trình nội bộ liên quan đến công việc được giao; "
                            + "có kiến thức cơ bản về hoạt động kinh doanh dịch vụ y tế và chăm sóc khách hàng; "
                            + "hiểu nguyên tắc giao tiếp, tư vấn và làm việc với khách hàng/đối tác trong môi trường bệnh viện; "
                            + "nắm được các quy định chung về đạo đức nghề nghiệp, bảo mật thông tin và hình ảnh bệnh viện"),
            new Criterion("practice", "Kỹ năng thực hành", 40,
                    "Kỹ năng giao tiếp, tư vấn dịch vụ y tế cho khách hàng/đối tác; "
                            + "kỹ năng xây dựng, duy trì và phát triển mối quan hệ với đối tác (doanh nghiệp, bảo hiểm, phòng khám, cộng đồng); "
                            + "thực hiện công việc đúng quy trình, đúng kế hoạch được giao; "
                            + "kỹ năng tin học văn phòng; phối hợp triển khai các hoạt động truyền thông - marketing bệnh viện"),
            new Criterion("attitude", "Thái độ - đạo đức", 20,
                    "Thái độ chuẩn mực, lịch sự, tôn trọng người bệnh, khách hàng và đối tác; "
                            + "tuân thủ quy định bệnh viện, quy tắc ứng xử và bảo mật thông tin y tế; "
                            + "có ý thức trách nhiệm, chủ động trong công việc; giữ hình ảnh, uy tín và thương hiệu bệnh viện"),
            new Criterion("teamwork", "Phối hợp & học tập", 10,
                    "Hợp tác với đồng nghiệp, hỗ trợ kịp thời; chủ động học hỏi kiến thức y tế, dịch vụ mới, chính sách mới; "
                            + "tiếp thu góp ý, cải thiện hiệu quả công việc; tham gia đầy đủ các chương trình đào tạo nội bộ"));

    private final ObjectMapper objectMapper;

    public ProbationEvaluationHelper(ObjectMapper objectMapper) {
        this.objectMapper = objectMapper;
    }

    public static List<Criterion> criteriaOf(ProbationFormType formType) {
        return switch (formType) {
            case DOCTOR -> DOCTOR_CRITERIA;
            case NURSE -> NURSE_CRITERIA;
            case STAFF -> STAFF_CRITERIA;
        };
    }

    public static int maxScoreOf(ProbationFormType formType) {
        return formType == ProbationFormType.DOCTOR ? 30 : 100;
    }

    public ScoreResult validateAndScore(ProbationFormType formType, Map<String, Integer> scores) {
        if (scores == null || scores.isEmpty()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Thiếu điểm đánh giá theo mẫu đơn");
        }
        List<Criterion> criteria = criteriaOf(formType);
        Map<String, Integer> normalized = new LinkedHashMap<>();
        int total = 0;
        int max = 0;
        for (Criterion c : criteria) {
            Integer raw = scores.get(c.code());
            if (raw == null) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "Thiếu điểm: " + c.label());
            }
            if (raw < 0 || raw > c.maxScore()) {
                throw new ApiException(HttpStatus.BAD_REQUEST,
                        c.label() + " phải từ 0 đến " + c.maxScore());
            }
            normalized.put(c.code(), raw);
            total += raw;
            max += c.maxScore();
        }
        Set<String> allowed = criteria.stream().map(Criterion::code).collect(java.util.stream.Collectors.toSet());
        for (String key : scores.keySet()) {
            if (!allowed.contains(key)) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "Mã tiêu chí không hợp lệ: " + key);
            }
        }
        String json;
        try {
            json = objectMapper.writeValueAsString(normalized);
        } catch (JsonProcessingException e) {
            throw new ApiException(HttpStatus.INTERNAL_SERVER_ERROR, "Không lưu được điểm đánh giá");
        }
        return new ScoreResult(json, total, max, gradeLabel(formType, total));
    }

    public static String gradeLabel(ProbationFormType formType, int total) {
        if (formType == ProbationFormType.DOCTOR) {
            if (total >= 27) return "Tốt";
            if (total >= 21) return "Khá";
            if (total >= 15) return "Đạt yêu cầu";
            return "Không đạt";
        }
        // Điều dưỡng & Nhân viên: cùng thang /100 theo mẫu Word
        if (total >= 90) return "Xuất sắc";
        if (total >= 75) return "Khá";
        if (total >= 60) return "Đạt yêu cầu";
        return "Chưa đạt";
    }

    public record Criterion(String code, String label, int maxScore, String detail) {}

    public record ScoreResult(String scoresJson, Integer totalScore, Integer maxScore, String gradeLabel) {}
}
