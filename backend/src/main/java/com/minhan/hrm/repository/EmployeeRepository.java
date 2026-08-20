package com.minhan.hrm.repository;

import com.minhan.hrm.entity.Employee;
import com.minhan.hrm.entity.EmployeeStatus;
import com.minhan.hrm.entity.UserAccount;
import org.springframework.data.domain.Sort;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

public interface EmployeeRepository extends JpaRepository<Employee, Long>, JpaSpecificationExecutor<Employee> {

    Optional<Employee> findByUser(UserAccount user);

    @Query(
            """
            SELECT e FROM Employee e
            WHERE e.phone IS NOT NULL AND TRIM(e.phone) <> ''
              AND (
                   e.phone LIKE CONCAT('%', :tail9)
                OR REPLACE(REPLACE(REPLACE(REPLACE(e.phone, '+', ''), ' ', ''), '-', ''), '.', '')
                     LIKE CONCAT('%', :tail9)
              )
            ORDER BY e.id ASC
            """)
    List<Employee> findByPhoneEndingWith(@Param("tail9") String tail9);

    Optional<Employee> findByUserUsername(String username);

    Optional<Employee> findByEmployeeCode(String employeeCode);

    boolean existsByEmployeeCode(String employeeCode);

    Optional<Employee> findByIdCardNumber(String idCardNumber);

    @Query(
            value =
                    """
                    SELECT * FROM employees e
                    WHERE REGEXP_REPLACE(COALESCE(e.id_card_number, ''), '[^0-9]', '') = :normalized
                    ORDER BY e.id ASC
                    """,
            nativeQuery = true)
    List<Employee> findAllByIdCardNumberNormalized(@Param("normalized") String normalized);

    default Optional<Employee> findByIdCardNumberNormalized(String normalized) {
        List<Employee> list = findAllByIdCardNumberNormalized(normalized);
        return list.isEmpty() ? Optional.empty() : Optional.of(list.get(0));
    }

    List<Employee> findByStatusNot(EmployeeStatus status);

    @Query("SELECT e FROM Employee e WHERE LOWER(TRIM(e.fullName)) = LOWER(TRIM(:name))")
    List<Employee> findByFullNameIgnoreCaseTrim(@Param("name") String name);

    List<Employee> findByStatus(EmployeeStatus status, Sort sort);

    List<Employee> findByDepartment_IdAndStatus(Long departmentId, EmployeeStatus status, Sort sort);

    long countByStatus(EmployeeStatus status);

    long countByDepartment_Id(Long departmentId);

    @Query(
            value =
                    """
                    SELECT d.id AS dept_id, d.name AS dept_name, COUNT(e.id) AS cnt,
                           SUM(CASE
                               WHEN e.status IN ('PROBATION', 'INTERN')
                                    OR (e.employee_code IS NOT NULL AND UPPER(e.employee_code) LIKE 'TV-%')
                               THEN 1 ELSE 0 END) AS trial_cnt
                    FROM employees e
                    INNER JOIN departments d ON e.department_id = d.id
                    GROUP BY d.id, d.name
                    ORDER BY cnt DESC
                    """,
            nativeQuery = true)
    List<Object[]> countEmployeesByDepartmentRaw();

    @Query(
            value =
                    """
                    SELECT YEAR(e.hire_date), MONTH(e.hire_date), COUNT(e.id),
                           SUM(CASE
                               WHEN e.status IN ('PROBATION', 'INTERN')
                                    OR (e.employee_code IS NOT NULL AND UPPER(e.employee_code) LIKE 'TV-%')
                               THEN 1 ELSE 0 END)
                    FROM employees e
                    WHERE e.hire_date IS NOT NULL AND e.hire_date >= :from
                    GROUP BY YEAR(e.hire_date), MONTH(e.hire_date)
                    ORDER BY YEAR(e.hire_date), MONTH(e.hire_date)
                    """,
            nativeQuery = true)
    List<Object[]> countHiresByMonthSinceRaw(@Param("from") LocalDate from);

    @Query(
            """
            SELECT e FROM Employee e
            WHERE e.hireDate IS NOT NULL
            AND YEAR(e.hireDate) = :year AND MONTH(e.hireDate) = :month
            ORDER BY e.hireDate ASC, e.fullName ASC
            """)
    List<Employee> findByHireYearAndMonth(@Param("year") int year, @Param("month") int month);

    List<Employee> findByDepartment_Id(Long departmentId, Sort sort);

    @Query("""
            SELECT e FROM Employee e
            LEFT JOIN FETCH e.department
            LEFT JOIN FETCH e.position
            LEFT JOIN FETCH e.user
            ORDER BY e.fullName ASC
            """)
    List<Employee> findAllWithDepartment();
}
