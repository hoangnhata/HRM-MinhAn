package com.minhan.hrm.service;

import com.minhan.hrm.entity.AttendanceRequestType;
import com.minhan.hrm.entity.AttendanceWorkRequest;
import com.minhan.hrm.entity.DepartmentTransferRequest;
import com.minhan.hrm.entity.MainDutyAuthorizationRequest;
import com.minhan.hrm.entity.ProbationConversionRequest;
import com.minhan.hrm.entity.SeminarProposalRequest;
import com.minhan.hrm.entity.ShiftConfigChangeRequest;
import com.minhan.hrm.entity.TrainingProposalRequest;
import com.minhan.hrm.entity.UserAccount;
import com.minhan.hrm.entity.YoungChildRequest;
import jakarta.persistence.EntityManager;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.function.Consumer;

/**
 * Đơn gửi trước khi có cột chữ ký người lập không có file snapshot.
 * Gắn lại bằng chữ ký hiện tại của đúng tài khoản đã lập phiếu.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class RequesterSignatureBackfillService {

    private final EntityManager entityManager;
    private final ApprovalSignatureService approvalSignatureService;

    @Transactional
    public void backfillMissing() {
        int filled = 0;
        int skipped = 0;

        var attendance = count(backfillAttendance());
        filled += attendance[0];
        skipped += attendance[1];

        var training = count(stampEach(
                entityManager.createQuery("""
                        SELECT r FROM TrainingProposalRequest r
                        JOIN FETCH r.requestedBy
                        WHERE r.requesterSignaturePath IS NULL
                        """, TrainingProposalRequest.class).getResultList(),
                TrainingProposalRequest::getRequestedBy,
                TrainingProposalRequest::getId,
                "training",
                TrainingProposalRequest::setRequesterSignaturePath));
        filled += training[0];
        skipped += training[1];

        var seminar = count(stampEach(
                entityManager.createQuery("""
                        SELECT r FROM SeminarProposalRequest r
                        JOIN FETCH r.requestedBy
                        WHERE r.requesterSignaturePath IS NULL
                        """, SeminarProposalRequest.class).getResultList(),
                SeminarProposalRequest::getRequestedBy,
                SeminarProposalRequest::getId,
                "seminar",
                SeminarProposalRequest::setRequesterSignaturePath));
        filled += seminar[0];
        skipped += seminar[1];

        var transfer = count(stampEach(
                entityManager.createQuery("""
                        SELECT r FROM DepartmentTransferRequest r
                        JOIN FETCH r.requestedBy
                        WHERE r.requesterSignaturePath IS NULL
                        """, DepartmentTransferRequest.class).getResultList(),
                DepartmentTransferRequest::getRequestedBy,
                DepartmentTransferRequest::getId,
                "transfer",
                DepartmentTransferRequest::setRequesterSignaturePath));
        filled += transfer[0];
        skipped += transfer[1];

        var probation = count(stampEach(
                entityManager.createQuery("""
                        SELECT r FROM ProbationConversionRequest r
                        JOIN FETCH r.requestedBy
                        WHERE r.requesterSignaturePath IS NULL
                        """, ProbationConversionRequest.class).getResultList(),
                ProbationConversionRequest::getRequestedBy,
                ProbationConversionRequest::getId,
                "probation",
                ProbationConversionRequest::setRequesterSignaturePath));
        filled += probation[0];
        skipped += probation[1];

        var mainDuty = count(stampEach(
                entityManager.createQuery("""
                        SELECT r FROM MainDutyAuthorizationRequest r
                        JOIN FETCH r.requestedBy
                        WHERE r.requesterSignaturePath IS NULL
                        """, MainDutyAuthorizationRequest.class).getResultList(),
                MainDutyAuthorizationRequest::getRequestedBy,
                MainDutyAuthorizationRequest::getId,
                "main-duty",
                MainDutyAuthorizationRequest::setRequesterSignaturePath));
        filled += mainDuty[0];
        skipped += mainDuty[1];

        var youngChild = count(stampEach(
                entityManager.createQuery("""
                        SELECT r FROM YoungChildRequest r
                        JOIN FETCH r.requestedBy
                        WHERE r.requesterSignaturePath IS NULL
                        """, YoungChildRequest.class).getResultList(),
                YoungChildRequest::getRequestedBy,
                YoungChildRequest::getId,
                "young-child",
                YoungChildRequest::setRequesterSignaturePath));
        filled += youngChild[0];
        skipped += youngChild[1];

        var shift = count(stampEach(
                entityManager.createQuery("""
                        SELECT r FROM ShiftConfigChangeRequest r
                        JOIN FETCH r.requestedBy
                        WHERE r.requesterSignaturePath IS NULL
                        """, ShiftConfigChangeRequest.class).getResultList(),
                ShiftConfigChangeRequest::getRequestedBy,
                ShiftConfigChangeRequest::getId,
                "shift-config-change",
                ShiftConfigChangeRequest::setRequesterSignaturePath));
        filled += shift[0];
        skipped += shift[1];

        if (filled > 0 || skipped > 0) {
            log.info("Bổ sung chữ ký người lập cho đơn cũ: {} phiếu đã gắn, {} phiếu bỏ qua vì tài khoản chưa có chữ ký.",
                    filled, skipped);
        }
    }

    private int[] backfillAttendance() {
        var rows = entityManager.createQuery("""
                SELECT r FROM AttendanceWorkRequest r
                JOIN FETCH r.employee e
                JOIN FETCH e.user
                LEFT JOIN FETCH r.headReviewer
                WHERE r.requesterSignaturePath IS NULL
                """, AttendanceWorkRequest.class).getResultList();
        int filled = 0;
        int skipped = 0;
        for (AttendanceWorkRequest row : rows) {
            UserAccount requester = row.getRequestType() == AttendanceRequestType.DEPLOYMENT
                    && row.getHeadReviewer() != null
                    ? row.getHeadReviewer()
                    : row.getEmployee().getUser();
            if (copySignature(requester, "attendance", row.getId(), row::setRequesterSignaturePath)) {
                filled++;
            } else {
                skipped++;
            }
        }
        return new int[] { filled, skipped };
    }

    private <T> int[] stampEach(
            java.util.List<T> rows,
            java.util.function.Function<T, UserAccount> requester,
            java.util.function.Function<T, Long> id,
            String kind,
            java.util.function.BiConsumer<T, String> setPath) {
        int filled = 0;
        int skipped = 0;
        for (T row : rows) {
            if (copySignature(requester.apply(row), kind, id.apply(row), path -> setPath.accept(row, path))) {
                filled++;
            } else {
                skipped++;
            }
        }
        return new int[] { filled, skipped };
    }

    private boolean copySignature(UserAccount user, String kind, long id, Consumer<String> setPath) {
        if (user == null || user.getSignaturePath() == null || user.getSignaturePath().isBlank()) {
            return false;
        }
        try {
            setPath.accept(approvalSignatureService.stampRequester(user, kind, id, null));
            return true;
        } catch (RuntimeException ex) {
            log.debug("Không gắn được chữ ký người lập {} #{}: {}", kind, id, ex.getMessage());
            return false;
        }
    }

    private static int[] count(int[] pair) {
        return pair;
    }
}
