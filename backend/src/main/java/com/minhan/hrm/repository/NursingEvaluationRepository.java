package com.minhan.hrm.repository;

import com.minhan.hrm.entity.Employee;
import com.minhan.hrm.entity.NursingEvaluation;
import com.minhan.hrm.entity.NursingEvaluationStatus;
import com.minhan.hrm.entity.UserAccount;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Collection;
import java.util.List;
import java.util.Optional;

public interface NursingEvaluationRepository extends JpaRepository<NursingEvaluation, Long> {

    List<NursingEvaluation> findByEmployeeOrderByPeriodYearDescPeriodMonthDesc(Employee employee);

    Optional<NursingEvaluation> findByEmployeeAndPeriodYearAndPeriodMonthAndTemplateCode(
            Employee employee, int year, int month, String templateCode);

    @Query("""
            SELECT n FROM NursingEvaluation n
            JOIN FETCH n.employee e
            JOIN FETCH e.department d
            JOIN FETCH n.evaluator ev
            WHERE n.periodYear = :y AND n.periodMonth = :m AND n.templateCode = :code
            ORDER BY d.name, e.fullName
            """)
    List<NursingEvaluation> listMonthlyForTemplate(
            @Param("y") int y, @Param("m") int m, @Param("code") String code);

    @Query("""
            SELECT DISTINCT n FROM NursingEvaluation n
            JOIN FETCH n.employee e
            JOIN FETCH e.department d
            JOIN FETCH n.evaluator
            LEFT JOIN FETCH n.headReviewer
            LEFT JOIN FETCH n.hrReviewer
            LEFT JOIN FETCH n.directorReviewer
            WHERE n.id = :id
            """)
    Optional<NursingEvaluation> findDetailById(@Param("id") Long id);

    @Query("""
            SELECT DISTINCT n FROM NursingEvaluation n
            JOIN FETCH n.employee e
            JOIN FETCH e.department d
            JOIN FETCH n.evaluator
            WHERE n.status IN :statuses
            ORDER BY n.createdAt ASC
            """)
    List<NursingEvaluation> findPendingWithDetails(@Param("statuses") Collection<NursingEvaluationStatus> statuses);

    /** Phiếu đã qua ít nhất một bước duyệt / đã kết thúc (không gồm nháp, thu hồi). */
    @Query("""
            SELECT DISTINCT n FROM NursingEvaluation n
            JOIN FETCH n.employee e
            JOIN FETCH e.department d
            JOIN FETCH n.evaluator
            LEFT JOIN FETCH n.headReviewer
            LEFT JOIN FETCH n.hrReviewer
            LEFT JOIN FETCH n.directorReviewer
            WHERE n.status NOT IN :excluded
              AND (
                   n.headReviewedAt IS NOT NULL
                OR n.hrReviewedAt IS NOT NULL
                OR n.directorReviewedAt IS NOT NULL
                OR n.status IN :terminal
              )
            ORDER BY n.updatedAt DESC, n.createdAt DESC
            """)
    List<NursingEvaluation> findHistoryWithDetails(
            @Param("excluded") Collection<NursingEvaluationStatus> excluded,
            @Param("terminal") Collection<NursingEvaluationStatus> terminal);

    void deleteByEmployee_Id(Long employeeId);

    @Modifying
    @Query("UPDATE NursingEvaluation n SET n.evaluator = :to WHERE n.evaluator = :from")
    void reassignEvaluator(@Param("from") UserAccount from, @Param("to") UserAccount to);

    @Modifying
    @Query("UPDATE NursingEvaluation n SET n.headReviewer = :to WHERE n.headReviewer = :from")
    void reassignHeadReviewer(@Param("from") UserAccount from, @Param("to") UserAccount to);

    @Modifying
    @Query("UPDATE NursingEvaluation n SET n.hrReviewer = :to WHERE n.hrReviewer = :from")
    void reassignHrReviewer(@Param("from") UserAccount from, @Param("to") UserAccount to);

    @Modifying
    @Query("UPDATE NursingEvaluation n SET n.directorReviewer = :to WHERE n.directorReviewer = :from")
    void reassignDirectorReviewer(@Param("from") UserAccount from, @Param("to") UserAccount to);
}
