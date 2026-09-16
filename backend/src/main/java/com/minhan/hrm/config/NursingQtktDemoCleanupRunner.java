package com.minhan.hrm.config;

import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceContext;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.YearMonth;

/**
 * Xóa dữ liệu ảo Module A / QTKT khi {@code DEMO_SEED_CLEANUP=true}.
 * Idempotent — chạy lại an toàn (0 dòng nếu đã xóa hết).
 */
@Slf4j
@Component
@Order(Integer.MAX_VALUE - 1)
@RequiredArgsConstructor
public class NursingQtktDemoCleanupRunner implements ApplicationRunner {

    private final HrmProperties hrmProperties;

    @PersistenceContext
    private EntityManager entityManager;

    @Override
    @Transactional
    public void run(ApplicationArguments args) {
        HrmProperties.DemoSeed demo = hrmProperties.getDemoSeed();
        if (demo == null || !demo.isCleanup()) {
            return;
        }
        if (demo.isEnabled()) {
            log.warn("Demo cleanup bỏ qua — DEMO_SEED đang bật (không xóa khi vừa seed)");
            return;
        }

        log.info("Demo cleanup BAT — đang xóa dữ liệu ảo Module A / QTKT");

        int qtktFlag = entityManager.createNativeQuery(
                        "DELETE FROM qtkt_evaluations WHERE is_demo = 1")
                .executeUpdate();
        int qtktNote = entityManager.createNativeQuery(
                        "DELETE FROM qtkt_evaluations WHERE note LIKE 'Dữ liệu demo test%' OR note LIKE 'Demo GDSK%'")
                .executeUpdate();

        int ndrFlag = entityManager.createNativeQuery(
                        "DELETE FROM nursing_daily_reports WHERE is_demo = 1")
                .executeUpdate();

        // Bản ghi seed trước khi có cột is_demo (tháng hiện tại, tạo bởi admin)
        YearMonth ym = YearMonth.now();
        LocalDate from = ym.atDay(1);
        LocalDate to = LocalDate.now().isBefore(ym.atEndOfMonth()) ? LocalDate.now() : ym.atEndOfMonth();
        int ndrLegacy = entityManager.createNativeQuery("""
                        DELETE ndr FROM nursing_daily_reports ndr
                        INNER JOIN users u ON u.id = ndr.created_by_user_id
                        WHERE u.username = 'admin'
                          AND ndr.report_date BETWEEN ?1 AND ?2
                          AND ndr.is_demo = 0
                        """)
                .setParameter(1, from)
                .setParameter(2, to)
                .executeUpdate();

        log.info("Demo cleanup xong: qtkt(is_demo)={}, qtkt(note)={}, nursing(is_demo)={}, nursing(legacy)={}",
                qtktFlag, qtktNote, ndrFlag, ndrLegacy);
        log.info("QUAN TRONG: dat DEMO_SEED_CLEANUP=false trong start-hrm.bat roi restart — tranh xoa bao cao DD that cua admin");
    }
}
