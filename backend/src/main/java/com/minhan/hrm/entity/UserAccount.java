package com.minhan.hrm.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.time.Instant;

@Entity
@Table(name = "users")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class UserAccount {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, unique = true, length = 64)
    private String username;

    @Column(name = "password_hash", nullable = false)
    private String passwordHash;

    @Column(nullable = false)
    private String email;

    /** Tên từ ERP / SSO — dùng khi chưa có hồ sơ employees. */
    @Column(name = "display_name", length = 200)
    private String displayName;

    /** Bearer token ERP — gọi GET/PUT /api/auth/profile. */
    @Column(name = "erp_access_token", columnDefinition = "TEXT")
    private String erpAccessToken;

    /** Đường dẫn tương đối file chữ ký cá nhân (PNG) trong thư mục upload. */
    @Column(name = "signature_path", length = 500)
    private String signaturePath;

    /** Ảnh đại diện local (PNG/JPG) trong thư mục upload. */
    @Column(name = "avatar_path", length = 500)
    private String avatarPath;

    @JdbcTypeCode(SqlTypes.VARCHAR)
    @Column(nullable = false, length = 32)
    private UserRole role;

    @Column(nullable = false)
    private boolean enabled = true;

    /** Quyền duyệt các bước Giám đốc, độc lập với vai trò chính của tài khoản. */
    @Column(name = "director_approval_enabled", nullable = false)
    private boolean directorApprovalEnabled = false;

    /**
     * Được xem menu/API báo cáo nhân lực (toàn viện, đi làm hằng ngày),
     * độc lập với vai trò — cấp bởi Admin qua công tắc «Báo cáo».
     */
    @Column(name = "report_view_enabled", nullable = false)
    private boolean reportViewEnabled = false;

    /**
     * Trưởng khoa/phòng được đánh dấu "Trưởng bộ phận":
     * chỉ quản lý nhân sự cùng bộ phận (workUnitDetail), không cả khoa.
     */
    @Column(name = "work_unit_scoped", nullable = false)
    private boolean workUnitScoped = false;

    /** Bắt đổi mật khẩu sau lần đăng nhập đầu (tài khoản NV mới / import). */
    @Column(name = "must_change_password", nullable = false)
    private boolean mustChangePassword = false;

    @OneToOne(mappedBy = "user", fetch = FetchType.LAZY)
    private Employee employee;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at")
    private Instant updatedAt;

    @PrePersist
    void prePersist() {
        createdAt = Instant.now();
    }

    @PreUpdate
    void preUpdate() {
        updatedAt = Instant.now();
    }
}
