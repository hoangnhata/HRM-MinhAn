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

    Optional<Employee> findByUserUsername(String username);

    Optional<Employee> findByEmployeeCode(String employeeCode);

    List<Employee> findByStatus(EmployeeStatus status, Sort sort);

    List<Employee> findByDepartment_IdAndStatus(Long departmentId, EmployeeStatus status, Sort sort);

    long countByStatus(EmployeeStatus status);

    long countByDepartment_Id(Long departmentId);

    @Query(
            value =
                    """
                    SELECT d.name AS dept_name, COUNT(e.id) AS cnt
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
                    SELECT YEAR(e.hire_date), MONTH(e.hire_date), COUNT(e.id)
                    FROM employees e
                    WHERE e.hire_date >= :from
                    GROUP BY YEAR(e.hire_date), MONTH(e.hire_date)
                    ORDER BY YEAR(e.hire_date), MONTH(e.hire_date)
                    """,
            nativeQuery = true)
    List<Object[]> countHiresByMonthSinceRaw(@Param("from") LocalDate from);
}
