package com.minhan.hrm.config;

import com.minhan.hrm.entity.Department;
import com.minhan.hrm.entity.Employee;
import com.minhan.hrm.entity.UserAccount;
import com.minhan.hrm.entity.UserRole;
import com.minhan.hrm.repository.DepartmentRepository;
import com.minhan.hrm.repository.DepartmentWorkUnitRepository;
import com.minhan.hrm.repository.EmployeeRepository;
import com.minhan.hrm.repository.PositionRepository;
import com.minhan.hrm.repository.UserAccountRepository;
import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceContext;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.core.annotation.Order;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.util.LinkedHashSet;
import java.util.List;
import java.util.Optional;
import java.util.Set;

/**
 * Khi khởi động backend: xóa tài khoản / nhân viên / khoa phòng demo trình diễn.
 * Không bao giờ xóa tài khoản {@code admin} hoặc user role ADMIN.
 * <p>
 * Tắt bằng {@code app.demo-data.cleanup=false}.
 */
@Slf4j
@Component
@Order(Integer.MAX_VALUE)
@RequiredArgsConstructor
@ConditionalOnProperty(name = "app.demo-data.cleanup", havingValue = "true", matchIfMissing = true)
public class DemoDataCleanupRunner implements ApplicationRunner {

    public static final String ADMIN_USERNAME = "admin";
    public static final String DEMO_USERNAME = "nhanviendemo";
    public static final String DEMO_INTERN_USERNAME = "thuctapdemo";
    public static final String DEMO_EMPLOYEE_CODE = "DEMO-0001";
    public static final String DEMO_INTERN_EMPLOYEE_CODE = "DEMO-INTERN-0001";
    public static final String DEMO_DEPARTMENT_CODE = "DEMO-KCB";
    public static final String DEMO_POSITION_CODE = "DEMO-NV";
    public static final String DEMO_INTERN_POSITION_CODE = "DEMO-INTERN";

    private static final String[] EMPLOYEE_OWNED_TABLES = {
            "attendance_work_request",
            "attendance_records",
            "duty_shift_entry",
            "payroll_records",
            "nursing_evaluations",
            "evaluations",
            "contracts",
            "employee_documents",
            "employee_salary_profile",
            "salary_info",
            "employee_workforce_details",
            "employee_attendance_shift_config",
            "employee_continuous_shift_day",
            "employee_continuous_shift_month",
            "employee_young_child_month",
            "young_child_requests",
            "training_proposal_requests",
            "seminar_proposal_requests",
            "main_duty_authorization_requests",
            "department_transfer_requests",
            "probation_conversion_requests",
    };

    private final UserAccountRepository userAccountRepository;
    private final EmployeeRepository employeeRepository;
    private final DepartmentRepository departmentRepository;
    private final DepartmentWorkUnitRepository workUnitRepository;
    private final PositionRepository positionRepository;

    @PersistenceContext
    private EntityManager entityManager;

    @Override
    @Transactional
    public void run(ApplicationArguments args) {
        Set<Long> employeeIds = new LinkedHashSet<>();
        Set<Long> userIds = new LinkedHashSet<>();

        for (String code : List.of(DEMO_EMPLOYEE_CODE, DEMO_INTERN_EMPLOYEE_CODE)) {
            employeeRepository.findByEmployeeCode(code).ifPresent(e -> {
                if (isProtectedAdmin(e.getUser())) {
                    log.warn("Skip demo cleanup for employee {} — linked to ADMIN", code);
                    return;
                }
                employeeIds.add(e.getId());
                if (e.getUser() != null) {
                    userIds.add(e.getUser().getId());
                }
            });
        }
        for (String username : List.of(DEMO_USERNAME, DEMO_INTERN_USERNAME)) {
            userAccountRepository.findByUsername(username).ifPresent(u -> {
                if (isProtectedAdmin(u)) {
                    log.warn("Skip demo cleanup for username {} — ADMIN protected", username);
                    return;
                }
                userIds.add(u.getId());
                employeeRepository.findByUser(u).ifPresent(e -> employeeIds.add(e.getId()));
            });
        }

        departmentRepository.findByCode(DEMO_DEPARTMENT_CODE).ifPresent(dept ->
                employeeRepository.findByDepartment_Id(dept.getId(), Sort.unsorted()).forEach(e -> {
                    if (isProtectedAdmin(e.getUser())) {
                        return;
                    }
                    employeeIds.add(e.getId());
                    if (e.getUser() != null) {
                        userIds.add(e.getUser().getId());
                    }
                }));

        int removedEmployees = 0;
        for (Long employeeId : employeeIds) {
            if (purgeEmployee(employeeId)) {
                removedEmployees++;
            }
        }

        int removedUsers = 0;
        for (Long userId : userIds) {
            if (purgeOrphanUser(userId)) {
                removedUsers++;
            }
        }

        boolean removedDept = purgeDemoDepartment();
        purgeDemoPositions();

        if (removedEmployees > 0 || removedUsers > 0 || removedDept) {
            log.info(
                    "Demo data cleanup done: employees={}, users={}, departmentRemoved={} (admin kept)",
                    removedEmployees, removedUsers, removedDept);
        } else {
            log.info("Demo data cleanup — nothing to remove");
        }
    }

    private boolean purgeEmployee(Long employeeId) {
        Employee employee = employeeRepository.findById(employeeId).orElse(null);
        if (employee == null) {
            return false;
        }
        UserAccount user = employee.getUser();
        if (isProtectedAdmin(user)) {
            return false;
        }
        Long uid = user != null ? user.getId() : null;
        for (String table : EMPLOYEE_OWNED_TABLES) {
            entityManager.createNativeQuery("DELETE FROM " + table + " WHERE employee_id = :id")
                    .setParameter("id", employeeId)
                    .executeUpdate();
        }
        entityManager.createNativeQuery(
                        "UPDATE notifications SET related_employee_id = NULL WHERE related_employee_id = :id")
                .setParameter("id", employeeId)
                .executeUpdate();
        if (uid != null) {
            detachUserReferences(uid);
        }
        employeeRepository.delete(employee);
        entityManager.flush();
        return true;
    }

    private boolean purgeOrphanUser(Long userId) {
        UserAccount user = userAccountRepository.findById(userId).orElse(null);
        if (user == null || isProtectedAdmin(user)) {
            return false;
        }
        if (employeeRepository.findByUser(user).isPresent()) {
            return false;
        }
        detachUserReferences(userId);
        userAccountRepository.delete(user);
        return true;
    }

    private boolean purgeDemoDepartment() {
        Optional<Department> deptOpt = departmentRepository.findByCode(DEMO_DEPARTMENT_CODE);
        if (deptOpt.isEmpty()) {
            return false;
        }
        Department dept = deptOpt.get();
        Long deptId = dept.getId();
        if (employeeRepository.countByDepartment_Id(deptId) > 0) {
            log.warn("Skip deleting demo department {} — still has employees", DEMO_DEPARTMENT_CODE);
            return false;
        }
        entityManager.createNativeQuery(
                        "DELETE FROM department_transfer_requests WHERE from_department_id = :id OR to_department_id = :id")
                .setParameter("id", deptId)
                .executeUpdate();
        workUnitRepository.findByDepartment_IdOrderByNameAsc(deptId).forEach(workUnitRepository::delete);
        departmentRepository.delete(dept);
        return true;
    }

    private void purgeDemoPositions() {
        for (String code : List.of(DEMO_POSITION_CODE, DEMO_INTERN_POSITION_CODE)) {
            positionRepository.findByCode(code).ifPresent(position -> {
                long used = employeeRepository.count((root, query, cb) ->
                        cb.equal(root.get("position").get("id"), position.getId()));
                if (used == 0) {
                    positionRepository.delete(position);
                }
            });
        }
    }

    private void detachUserReferences(Long uid) {
        Optional<UserAccount> fallback = userAccountRepository.findByUsername(ADMIN_USERNAME)
                .filter(u -> !u.getId().equals(uid));
        if (fallback.isEmpty()) {
            fallback = userAccountRepository.findByRoleIn(List.of(UserRole.ADMIN, UserRole.HR)).stream()
                    .filter(u -> !u.getId().equals(uid))
                    .findFirst();
        }
        if (fallback.isEmpty()) {
            // Không có ADMIN/HR khác: chỉ null reviewer + xóa notification của user demo
            entityManager.createNativeQuery("DELETE FROM notifications WHERE user_id = :uid")
                    .setParameter("uid", uid)
                    .executeUpdate();
            clearNullableReviewer(uid, "attendance_work_request",
                    "head_reviewer_id", "hr_reviewer_id", "director_reviewer_id");
            clearNullableReviewer(uid, "young_child_requests", "hr_reviewer_id");
            clearNullableReviewer(uid, "training_proposal_requests", "hr_reviewer_id", "director_reviewer_id");
            clearNullableReviewer(uid, "seminar_proposal_requests", "hr_reviewer_id", "director_reviewer_id");
            clearNullableReviewer(uid, "main_duty_authorization_requests",
                    "head_reviewer_id", "hr_reviewer_id", "director_reviewer_id");
            clearNullableReviewer(uid, "department_transfer_requests", "director_reviewer_id");
            clearNullableReviewer(uid, "probation_conversion_requests", "hr_reviewer_id", "director_reviewer_id");
            entityManager.createNativeQuery(
                            "UPDATE duty_shift_entry SET entered_by_user_id = NULL WHERE entered_by_user_id = :uid")
                    .setParameter("uid", uid)
                    .executeUpdate();
            return;
        }
        Long fb = fallback.get().getId();
        entityManager.createNativeQuery("DELETE FROM notifications WHERE user_id = :uid")
                .setParameter("uid", uid)
                .executeUpdate();
        entityManager.createNativeQuery(
                        "UPDATE nursing_evaluations SET evaluator_user_id = :fb WHERE evaluator_user_id = :uid")
                .setParameter("fb", fb).setParameter("uid", uid).executeUpdate();
        entityManager.createNativeQuery(
                        "UPDATE evaluations SET evaluator_user_id = :fb WHERE evaluator_user_id = :uid")
                .setParameter("fb", fb).setParameter("uid", uid).executeUpdate();
        entityManager.createNativeQuery(
                        "UPDATE employee_documents SET uploaded_by_user_id = NULL WHERE uploaded_by_user_id = :uid")
                .setParameter("uid", uid).executeUpdate();
        entityManager.createNativeQuery(
                        "UPDATE duty_shift_entry SET entered_by_user_id = :fb WHERE entered_by_user_id = :uid")
                .setParameter("fb", fb).setParameter("uid", uid).executeUpdate();
        for (String table : List.of(
                "young_child_requests",
                "training_proposal_requests",
                "seminar_proposal_requests",
                "main_duty_authorization_requests",
                "department_transfer_requests",
                "probation_conversion_requests")) {
            entityManager.createNativeQuery(
                            "UPDATE " + table + " SET requested_by_user_id = :fb WHERE requested_by_user_id = :uid")
                    .setParameter("fb", fb)
                    .setParameter("uid", uid)
                    .executeUpdate();
        }
        entityManager.createNativeQuery(
                        "UPDATE internal_announcements SET author_user_id = :fb WHERE author_user_id = :uid")
                .setParameter("fb", fb)
                .setParameter("uid", uid)
                .executeUpdate();
        clearNullableReviewer(uid, "attendance_work_request",
                "head_reviewer_id", "hr_reviewer_id", "director_reviewer_id");
        clearNullableReviewer(uid, "young_child_requests", "hr_reviewer_id");
        clearNullableReviewer(uid, "training_proposal_requests", "hr_reviewer_id", "director_reviewer_id");
        clearNullableReviewer(uid, "seminar_proposal_requests", "hr_reviewer_id", "director_reviewer_id");
        clearNullableReviewer(uid, "main_duty_authorization_requests",
                "head_reviewer_id", "hr_reviewer_id", "director_reviewer_id");
        clearNullableReviewer(uid, "department_transfer_requests", "director_reviewer_id");
        clearNullableReviewer(uid, "probation_conversion_requests", "hr_reviewer_id", "director_reviewer_id");
    }

    private void clearNullableReviewer(Long userId, String table, String... columns) {
        for (String col : columns) {
            entityManager.createNativeQuery(
                            "UPDATE " + table + " SET " + col + " = NULL WHERE " + col + " = :uid")
                    .setParameter("uid", userId)
                    .executeUpdate();
        }
    }

    private static boolean isProtectedAdmin(UserAccount user) {
        if (user == null) {
            return false;
        }
        if (user.getRole() == UserRole.ADMIN) {
            return true;
        }
        return ADMIN_USERNAME.equalsIgnoreCase(user.getUsername());
    }
}
