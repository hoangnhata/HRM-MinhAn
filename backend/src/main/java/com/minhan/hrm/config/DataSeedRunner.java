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

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalTime;

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
    private final SalaryInfoRepository salaryInfoRepository;
    private final ContractRepository contractRepository;
    private final InternalAnnouncementRepository announcementRepository;
    private final NotificationRepository notificationRepository;
    private final AttendanceRecordRepository attendanceRecordRepository;
    private final PayrollRecordRepository payrollRecordRepository;
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

        Position posBs = positionRepository.save(Position.builder()
                .code("BS").title("Bác sĩ").levelRank(3).build());
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
                .build());

        UserAccount empUser = userAccountRepository.save(UserAccount.builder()
                .username("nhanvien")
                .passwordHash(passwordEncoder.encode("Emp@123"))
                .email("nv@minhan.vn")
                .role(UserRole.EMPLOYEE)
                .enabled(true)
                .build());

        Employee emp = employeeRepository.save(Employee.builder()
                .user(empUser)
                .employeeCode("NV-DEMO-001")
                .fullName("Lê Văn Nhân viên")
                .phone("0901000002")
                .idCardNumber("079012345678")
                .dateOfBirth(LocalDate.of(1992, 5, 20))
                .address("TP.HCM")
                .gender("MALE")
                .department(deptNoi)
                .position(posBs)
                .hireDate(LocalDate.of(2021, 6, 1))
                .status(EmployeeStatus.ACTIVE)
                .build());

        UserAccount hrUser = userAccountRepository.save(UserAccount.builder()
                .username("hcns")
                .passwordHash(passwordEncoder.encode("Hcns@123"))
                .email("hcns@minhan.vn")
                .role(UserRole.HR)
                .enabled(true)
                .build());

        UserAccount tkUser = userAccountRepository.save(UserAccount.builder()
                .username("truongkhoa")
                .passwordHash(passwordEncoder.encode("Tk@12345"))
                .email("truongkhoa@minhan.vn")
                .role(UserRole.HEAD_DEPARTMENT)
                .enabled(true)
                .build());

        UserAccount ddtUser = userAccountRepository.save(UserAccount.builder()
                .username("dieuduongtruong")
                .passwordHash(passwordEncoder.encode("Ddt@12345"))
                .email("ddt@minhan.vn")
                .role(UserRole.HEAD_NURSING)
                .enabled(true)
                .build());

        Employee hrEmp = employeeRepository.save(Employee.builder()
                .user(hrUser)
                .employeeCode("HCNS-001")
                .fullName("Trần Thị HCNS")
                .phone("0901000003")
                .department(deptHcns)
                .position(posHcnsNv)
                .hireDate(LocalDate.of(2020, 1, 1))
                .status(EmployeeStatus.ACTIVE)
                .build());

        employeeRepository.save(Employee.builder()
                .user(tkUser)
                .employeeCode("TK-NOI-001")
                .fullName("Phạm Trưởng Khoa")
                .phone("0901000004")
                .department(deptNoi)
                .position(posTk)
                .hireDate(LocalDate.of(2018, 3, 1))
                .status(EmployeeStatus.ACTIVE)
                .build());

        employeeRepository.save(Employee.builder()
                .user(ddtUser)
                .employeeCode("DDT-NOI-001")
                .fullName("Hoàng Điều Dưỡng Trưởng")
                .phone("0901000005")
                .department(deptNoi)
                .position(posDdt)
                .hireDate(LocalDate.of(2019, 2, 1))
                .status(EmployeeStatus.ACTIVE)
                .build());

        salaryInfoRepository.save(SalaryInfo.builder()
                .employee(emp)
                .baseSalary(new BigDecimal("22000000"))
                .allowance(new BigDecimal("1500000"))
                .lastRaiseDate(LocalDate.of(2024, 6, 1))
                .nextReviewDate(LocalDate.now().plusDays(12))
                .build());

        contractRepository.save(Contract.builder()
                .employee(emp)
                .contractType("Xác định thời hạn 36 tháng")
                .startDate(LocalDate.of(2021, 6, 1))
                .endDate(LocalDate.of(2024, 6, 1))
                .salaryBase(new BigDecimal("20000000"))
                .build());

        announcementRepository.save(InternalAnnouncement.builder()
                .title("Hội nghị chất lượng bệnh viện Q2/2026")
                .body("Toàn thể CBCNV tham dự vào 08:00 ngày 15/04/2026 tại Hội trường A.")
                .category(AnnouncementCategory.THONG_BAO_CHUNG)
                .priority(AnnouncementPriority.HIGH)
                .author(admin)
                .build());

        notificationRepository.save(Notification.builder()
                .user(empUser)
                .category(NotificationCategory.INTERNAL)
                .title("Chào mừng đến HRM Bệnh viện Minh An")
                .message("Vui lòng cập nhật hồ sơ cá nhân. ADMIN có thể import Excel nhân lực và nhập đánh giá điều dưỡng.")
                .opened(false)
                .relatedEmployee(emp)
                .build());

        LocalDate d = LocalDate.now().withDayOfMonth(1);
        attendanceRecordRepository.save(AttendanceRecord.builder()
                .employee(emp)
                .workDate(d)
                .checkIn(LocalTime.of(7, 45))
                .checkOut(LocalTime.of(17, 10))
                .status("PRESENT")
                .build());

        payrollRecordRepository.save(PayrollRecord.builder()
                .employee(emp)
                .periodYear(d.getYear())
                .periodMonth(d.getMonthValue())
                .workingDays(22)
                .grossAmount(new BigDecimal("23500000"))
                .deductionAmount(new BigDecimal("1500000"))
                .netAmount(new BigDecimal("22000000"))
                .finalized(true)
                .build());

        log.info(
                "Data seed: admin/Admin@123, nhanvien/Emp@123, hcns/Hcns@123 (HCNS), truongkhoa/Tk@12345, dieuduongtruong/Ddt@12345");
    }
}
