package com.minhan.hrm.config;

import com.minhan.hrm.entity.*;
import com.minhan.hrm.repository.*;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.context.annotation.Profile;
import org.springframework.core.annotation.Order;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

/**
 * Seed dữ liệu mẫu khi DB trống (bật mặc định; tắt bằng --spring.profiles.active=prod).
 */
@Slf4j
@Component
@Order(Integer.MAX_VALUE)
@RequiredArgsConstructor
@Profile("!prod")
public class DataSeedRunner implements ApplicationRunner {

    private final DepartmentRepository departmentRepository;
    private final PositionRepository positionRepository;
    private final UserAccountRepository userAccountRepository;
    private final EmployeeRepository employeeRepository;
    private final InternalAnnouncementRepository announcementRepository;
    private final PasswordEncoder passwordEncoder;

    @Override
    @Transactional
    public void run(ApplicationArguments args) {
        if (userAccountRepository.count() > 0) {
            log.info("Skip data seed — users already exist");
            return;
        }

        departmentRepository.save(Department.builder()
                .code("KHTH").name("Khối kỹ thuật hình ảnh").description("Chẩn đoán hình ảnh").build());
        Department deptNoi = departmentRepository.save(Department.builder()
                .code("NOI").name("Khoa Nội").build());
        departmentRepository.save(Department.builder().code("DUOC").name("Khoa Dược").build());
        Department deptHcns = departmentRepository.save(Department.builder()
                .code("HCNS").name("Phòng Hành chính — Nhân sự").build());

        Position posHcnsNv = positionRepository.save(Position.builder()
                .code("HCNS_NV").title("Chuyên viên HCNS").levelRank(2).build());
        Position posTk = positionRepository.save(Position.builder()
                .code("TK_KHOA").title("Trưởng khoa").levelRank(5).build());
        Position posDdt = positionRepository.save(Position.builder()
                .code("DDT_TRUONG").title("Điều dưỡng trưởng").levelRank(4).build());

        UserAccount admin = userAccountRepository.save(UserAccount.builder()
                .username("admin")
                .passwordHash(passwordEncoder.encode("Admin@123"))
                .email("admin@minhan.vn")
                .role(UserRole.ADMIN)
                .enabled(true)
                .mustChangePassword(false)
                .build());

        UserAccount hrUser = userAccountRepository.save(UserAccount.builder()
                .username("hcns")
                .passwordHash(passwordEncoder.encode("Hcns@123"))
                .email("hcns@minhan.vn")
                .role(UserRole.HR)
                .enabled(true)
                .mustChangePassword(false)
                .build());

        UserAccount tkUser = userAccountRepository.save(UserAccount.builder()
                .username("truongkhoa")
                .passwordHash(passwordEncoder.encode("Tk@12345"))
                .email("truongkhoa@minhan.vn")
                .role(UserRole.HEAD_DEPARTMENT)
                .enabled(true)
                .mustChangePassword(false)
                .build());

        UserAccount ddtUser = userAccountRepository.save(UserAccount.builder()
                .username("dieuduongtruong")
                .passwordHash(passwordEncoder.encode("Ddt@12345"))
                .email("ddt@minhan.vn")
                .role(UserRole.HEAD_NURSING)
                .enabled(true)
                .mustChangePassword(false)
                .build());

        employeeRepository.save(Employee.builder()
                .user(hrUser)
                .employeeCode("HCNS-001")
                .fullName("Trần Thị HCNS")
                .phone("0901000003")
                .department(deptHcns)
                .position(posHcnsNv)
                .hireDate(java.time.LocalDate.of(2020, 1, 1))
                .status(EmployeeStatus.ACTIVE)
                .build());

        employeeRepository.save(Employee.builder()
                .user(tkUser)
                .employeeCode("TK-NOI-001")
                .fullName("Phạm Trưởng Khoa")
                .phone("0901000004")
                .department(deptNoi)
                .position(posTk)
                .hireDate(java.time.LocalDate.of(2018, 3, 1))
                .status(EmployeeStatus.ACTIVE)
                .build());

        employeeRepository.save(Employee.builder()
                .user(ddtUser)
                .employeeCode("DDT-NOI-001")
                .fullName("Hoàng Điều Dưỡng Trưởng")
                .phone("0901000005")
                .department(deptNoi)
                .position(posDdt)
                .hireDate(java.time.LocalDate.of(2019, 2, 1))
                .status(EmployeeStatus.ACTIVE)
                .build());

        announcementRepository.save(InternalAnnouncement.builder()
                .title("Hội nghị chất lượng bệnh viện Q2/2026")
                .body("Toàn thể CBCNV tham dự vào 08:00 ngày 15/04/2026 tại Hội trường A.")
                .category(AnnouncementCategory.THONG_BAO_CHUNG)
                .priority(AnnouncementPriority.HIGH)
                .author(admin)
                .build());

        log.info("Data seed: admin, hcns, truongkhoa, dieuduongtruong (không có tài khoản demo nhanvien)");
    }
}
