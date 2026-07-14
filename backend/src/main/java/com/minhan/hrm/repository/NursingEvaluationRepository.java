package com.minhan.hrm.repository;

import com.minhan.hrm.entity.Employee;
import com.minhan.hrm.entity.NursingEvaluation;
import com.minhan.hrm.entity.UserAccount;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

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
            WHERE n.id = :id
            """)
            Optional<NursingEvaluation> findDetailById(@Param("id") Long id);

    void deleteByEmployee_Id(Long employeeId);

    @Modifying
    @Query("UPDATE NursingEvaluation n SET n.evaluator = :to WHERE n.evaluator = :from")
    void reassignEvaluator(@Param("from") UserAccount from, @Param("to") UserAccount to);
}
