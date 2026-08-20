package com.minhan.hrm.controller;

import com.minhan.hrm.entity.*;
import com.minhan.hrm.exception.ApiException;
import com.minhan.hrm.exception.ResourceNotFoundException;
import com.minhan.hrm.repository.AttendanceWorkRequestRepository;
import com.minhan.hrm.repository.DepartmentTransferRequestRepository;
import com.minhan.hrm.repository.ProbationConversionRequestRepository;
import com.minhan.hrm.repository.MainDutyAuthorizationRequestRepository;
import com.minhan.hrm.repository.NursingEvaluationRepository;
import com.minhan.hrm.repository.SeminarProposalRequestRepository;
import com.minhan.hrm.repository.TrainingProposalRequestRepository;
import com.minhan.hrm.repository.YoungChildRequestRepository;
import com.minhan.hrm.repository.ShiftConfigChangeRequestRepository;
import com.minhan.hrm.service.ApprovalSignatureService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/j1-api/v1/approval-signatures")
@RequiredArgsConstructor
@SecurityRequirement(name = "bearerAuth")
@Tag(name = "Approval signatures", description = "Xem chữ ký đã gắn khi duyệt đơn")
public class ApprovalSignatureController {

    private final ApprovalSignatureService approvalSignatureService;
    private final ProbationConversionRequestRepository probationRepo;
    private final AttendanceWorkRequestRepository attendanceRepo;
    private final DepartmentTransferRequestRepository transferRepo;
    private final YoungChildRequestRepository youngChildRepo;
    private final ShiftConfigChangeRequestRepository shiftConfigChangeRepo;
    private final TrainingProposalRequestRepository trainingRepo;
    private final SeminarProposalRequestRepository seminarRepo;
    private final MainDutyAuthorizationRequestRepository mainDutyRepo;
    private final NursingEvaluationRepository nursingEvalRepo;

    @GetMapping("/{kind}/{id}/{role}")
    @Operation(summary = "Ảnh chữ ký snapshot theo loại đơn / bước duyệt")
    public ResponseEntity<byte[]> get(
            @PathVariable String kind,
            @PathVariable long id,
            @PathVariable String role) {
        String path = resolvePath(kind, id, role);
        ApprovalSignatureService.SignatureFile file = approvalSignatureService.readRelative(path);
        return ResponseEntity.ok()
                .header(HttpHeaders.CACHE_CONTROL, "private, max-age=3600")
                .contentType(MediaType.parseMediaType(file.contentType()))
                .body(file.data());
    }

    private String resolvePath(String kind, long id, String role) {
        String k = kind == null ? "" : kind.trim().toLowerCase();
        String r = role == null ? "" : role.trim().toLowerCase();
        return switch (k) {
            case "probation" -> {
                ProbationConversionRequest row = probationRepo.findById(id)
                        .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy đơn"));
                yield switch (r) {
                    case "nursing-head" -> row.getNursingHeadSignaturePath();
                    case "hr" -> row.getHrSignaturePath();
                    case "director" -> row.getDirectorSignaturePath();
                    default -> throw badRole();
                };
            }
            case "attendance" -> {
                AttendanceWorkRequest row = attendanceRepo.findById(id)
                        .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy đơn"));
                yield switch (r) {
                    case "head" -> row.getHeadSignaturePath();
                    case "nursing-head" -> row.getNursingHeadSignaturePath();
                    case "hr" -> row.getHrSignaturePath();
                    case "director" -> row.getDirectorSignaturePath();
                    default -> throw badRole();
                };
            }
            case "transfer" -> {
                DepartmentTransferRequest row = transferRepo.findById(id)
                        .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy đơn"));
                if (!"director".equals(r)) {
                    throw badRole();
                }
                yield row.getDirectorSignaturePath();
            }
            case "young-child" -> {
                YoungChildRequest row = youngChildRepo.findById(id)
                        .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy đơn"));
                if (!"hr".equals(r)) {
                    throw badRole();
                }
                yield row.getHrSignaturePath();
            }
            case "shift-config-change" -> {
                ShiftConfigChangeRequest row = shiftConfigChangeRepo.findById(id)
                        .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy đơn"));
                if (!"hr".equals(r)) {
                    throw badRole();
                }
                yield row.getHrSignaturePath();
            }
            case "training" -> {
                TrainingProposalRequest row = trainingRepo.findById(id)
                        .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy đơn"));
                yield switch (r) {
                    case "hr" -> row.getHrSignaturePath();
                    case "director" -> row.getDirectorSignaturePath();
                    default -> throw badRole();
                };
            }
            case "seminar" -> {
                SeminarProposalRequest row = seminarRepo.findById(id)
                        .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy đơn"));
                yield switch (r) {
                    case "hr" -> row.getHrSignaturePath();
                    case "director" -> row.getDirectorSignaturePath();
                    default -> throw badRole();
                };
            }
            case "main-duty" -> {
                var row = mainDutyRepo.findById(id)
                        .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy đơn"));
                yield switch (r) {
                    case "head" -> row.getHeadSignaturePath();
                    case "nursing-head" -> row.getNursingHeadSignaturePath();
                    case "hr" -> row.getHrSignaturePath();
                    case "director" -> row.getDirectorSignaturePath();
                    default -> throw badRole();
                };
            }
            case "nursing-eval" -> {
                var row = nursingEvalRepo.findById(id)
                        .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy phiếu đánh giá"));
                yield switch (r) {
                    case "evaluator" -> row.getEvaluatorSignaturePath();
                    // "head" giữ tương thích chữ ký cũ; bước duyệt = Trưởng phòng ĐD
                    case "head", "nursing-head" -> row.getHeadSignaturePath();
                    case "hr" -> row.getHrSignaturePath();
                    case "director" -> row.getDirectorSignaturePath();
                    default -> throw badRole();
                };
            }
            default -> throw new ApiException(HttpStatus.BAD_REQUEST, "Loại đơn không hợp lệ");
        };
    }

    private static ApiException badRole() {
        return new ApiException(HttpStatus.BAD_REQUEST, "Bước duyệt không hợp lệ");
    }
}
