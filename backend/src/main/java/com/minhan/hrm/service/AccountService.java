package com.minhan.hrm.service;

import com.minhan.hrm.config.HrmProperties;
import com.minhan.hrm.dto.account.AccountMeResponse;
import com.minhan.hrm.dto.account.AccountProfileUpdateRequest;
import com.minhan.hrm.dto.account.AvatarSaveRequest;
import com.minhan.hrm.dto.account.ChangePasswordRequest;
import com.minhan.hrm.dto.account.SignatureSaveRequest;
import com.minhan.hrm.dto.auth.ErpProfileResponse;
import com.minhan.hrm.dto.auth.ErpProfileUpdateBody;
import com.minhan.hrm.dto.auth.ErpProfileUpdateResponse;
import com.minhan.hrm.entity.Department;
import com.minhan.hrm.entity.Employee;
import com.minhan.hrm.entity.UserAccount;
import com.minhan.hrm.entity.UserRole;
import com.minhan.hrm.exception.ApiException;
import com.minhan.hrm.repository.DepartmentRepository;
import com.minhan.hrm.repository.EmployeeRepository;
import com.minhan.hrm.repository.EmployeeWorkforceDetailsRepository;
import com.minhan.hrm.repository.UserAccountRepository;
import com.minhan.hrm.security.SecurityUtils;
import com.minhan.hrm.sso.ErpAuthClient;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.nio.file.Files;
import java.nio.file.Path;
import java.time.LocalDate;
import java.time.format.DateTimeParseException;
import java.util.ArrayList;
import java.util.Base64;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Locale;
import java.util.Optional;
import java.util.Set;

@Slf4j
@Service
@RequiredArgsConstructor
public class AccountService {

    private final UserAccountRepository userAccountRepository;
    private final EmployeeRepository employeeRepository;
    private final EmployeeWorkforceDetailsRepository employeeWorkforceDetailsRepository;
    private final EmployeeLinkService employeeLinkService;
    private final DepartmentRepository departmentRepository;
    private final PasswordEncoder passwordEncoder;
    private final ErpAuthClient erpAuthClient;
    private final HrmProperties hrmProperties;
    private final FileStorageService fileStorageService;
    private final EmployeeService employeeService;

    @Transactional
    public AccountMeResponse getMe() {
        UserAccount u = currentUser();
        return buildMe(u, true);
    }

    /** Ảnh đại diện: ưu tiên file local, không có thì proxy ERP. */
    @Transactional
    public ErpAuthClient.AvatarBytes getMyAvatar() {
        UserAccount u = currentUser();
        if (u.getAvatarPath() != null && !u.getAvatarPath().isBlank()) {
            try {
                Path path = fileStorageService.resolveStoredPath(u.getAvatarPath());
                if (Files.exists(path)) {
                    String name = path.getFileName().toString().toLowerCase(Locale.ROOT);
                    String ct = name.endsWith(".jpg") || name.endsWith(".jpeg")
                            ? MediaType.IMAGE_JPEG_VALUE
                            : MediaType.IMAGE_PNG_VALUE;
                    return new ErpAuthClient.AvatarBytes(Files.readAllBytes(path), ct);
                }
            } catch (ApiException ex) {
                throw ex;
            } catch (Exception ex) {
                log.warn("Không đọc được avatar local userId={}: {}", u.getId(), ex.getMessage());
            }
        }
        return getErpAvatar();
    }

    /** Ảnh đại diện ERP — proxy qua HRM (Bearer) để tránh CORS / path tương đối. */
    @Transactional
    public ErpAuthClient.AvatarBytes getErpAvatar() {
        UserAccount u = currentUser();
        if (u.getErpAccessToken() == null || u.getErpAccessToken().isBlank()) {
            throw new ApiException(HttpStatus.NOT_FOUND, "Chưa có ảnh đại diện");
        }
        ErpProfileResponse.ErpProfile p = erpAuthClient.getProfile(u.getErpAccessToken()).getProfile();
        String raw = p.getUserAvatar();
        if (raw == null || raw.isBlank()) {
            throw new ApiException(HttpStatus.NOT_FOUND, "ERP chưa có ảnh đại diện");
        }
        if (raw.startsWith("data:image")) {
            return decodeDataUri(raw);
        }
        for (String candidate : resolveAvatarCandidateUrls(raw)) {
            log.debug("Trying ERP avatar URL: {}", candidate);
            ErpAuthClient.AvatarBytes bytes = erpAuthClient.fetchAvatar(candidate, u.getErpAccessToken());
            if (bytes != null) {
                log.info("ERP avatar loaded from {}", candidate);
                return bytes;
            }
        }
        log.warn("ERP avatar not found for raw path={}", raw);
        throw new ApiException(HttpStatus.NOT_FOUND, "Không tải được ảnh đại diện từ ERP");
    }

    @Transactional
    public AccountMeResponse saveMyAvatar(AvatarSaveRequest req) {
        UserAccount u = currentUser();
        DecodedImage decoded = decodeSignatureImage(req.getImageBase64());
        String oldPath = u.getAvatarPath();
        String relative = fileStorageService.storeImageBytes(
                decoded.data(),
                decoded.contentType(),
                "avatars/" + u.getId(),
                "avatar");
        u.setAvatarPath(relative);
        userAccountRepository.save(u);
        if (oldPath != null && !oldPath.isBlank() && !oldPath.equals(relative)) {
            fileStorageService.deleteStoredFile(oldPath);
        }
        return buildMe(u, true);
    }

    @Transactional
    public AccountMeResponse deleteMyAvatar() {
        UserAccount u = currentUser();
        String old = u.getAvatarPath();
        u.setAvatarPath(null);
        userAccountRepository.save(u);
        fileStorageService.deleteStoredFile(old);
        return buildMe(u, true);
    }

    @Transactional
    public AccountMeResponse updateProfile(AccountProfileUpdateRequest req) {
        UserAccount u = currentUser();

        if (u.getErpAccessToken() != null && !u.getErpAccessToken().isBlank()) {
            updateErpProfile(u, req);
        } else {
            updateLocalOnly(u, req);
        }

        employeeLinkService.findLinkedEmployee(u).ifPresent(e -> {
            boolean changed = false;
            if (req.getAddress() != null) {
                e.setAddress(req.getAddress().trim().isEmpty() ? null : req.getAddress().trim());
                changed = true;
            }
            if (req.getDepartmentId() != null) {
                Department d = departmentRepository
                        .findById(req.getDepartmentId())
                        .orElseThrow(() -> new ApiException(HttpStatus.BAD_REQUEST, "Phòng ban không tồn tại"));
                e.setDepartment(d);
                changed = true;
            }
            if (req.getPhone() != null && (u.getErpAccessToken() == null || u.getErpAccessToken().isBlank())) {
                if (req.getPhone().trim().isEmpty()) {
                    e.setPhone(null);
                    changed = true;
                } else {
                    employeeService.syncPhoneAndLoginUsername(e, req.getPhone());
                    changed = true;
                }
            }
            if (changed) {
                employeeRepository.save(e);
            }
        });

        return buildMe(userAccountRepository.findById(u.getId()).orElseThrow(), true);
    }

    @Transactional
    public void changePassword(ChangePasswordRequest req) {
        UserAccount u = currentUser();
        if (!passwordEncoder.matches(req.getOldPassword(), u.getPasswordHash())) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Mật khẩu hiện tại không đúng");
        }
        u.setPasswordHash(passwordEncoder.encode(req.getNewPassword()));
        u.setMustChangePassword(false);
        userAccountRepository.save(u);
    }

    public record SignatureBytes(byte[] data, String contentType) {}

    @Transactional(readOnly = true)
    public SignatureBytes getMySignature() {
        UserAccount u = currentUser();
        if (u.getSignaturePath() == null || u.getSignaturePath().isBlank()) {
            throw new ApiException(HttpStatus.NOT_FOUND, "Chưa có chữ ký");
        }
        try {
            Path path = fileStorageService.resolveStoredPath(u.getSignaturePath());
            if (!Files.exists(path)) {
                throw new ApiException(HttpStatus.NOT_FOUND, "File chữ ký không tồn tại");
            }
            String name = path.getFileName().toString().toLowerCase(Locale.ROOT);
            String ct = name.endsWith(".jpg") || name.endsWith(".jpeg")
                    ? MediaType.IMAGE_JPEG_VALUE
                    : MediaType.IMAGE_PNG_VALUE;
            return new SignatureBytes(Files.readAllBytes(path), ct);
        } catch (ApiException ex) {
            throw ex;
        } catch (Exception ex) {
            throw new ApiException(HttpStatus.INTERNAL_SERVER_ERROR, "Không đọc được chữ ký");
        }
    }

    @Transactional
    public AccountMeResponse saveMySignature(SignatureSaveRequest req) {
        UserAccount u = currentUser();
        DecodedImage decoded = decodeSignatureImage(req.getImageBase64());
        String oldPath = u.getSignaturePath();
        String relative = fileStorageService.storeImageBytes(
                decoded.data(),
                decoded.contentType(),
                "signatures/" + u.getId(),
                "sign");
        u.setSignaturePath(relative);
        userAccountRepository.save(u);
        if (oldPath != null && !oldPath.isBlank() && !oldPath.equals(relative)) {
            fileStorageService.deleteStoredFile(oldPath);
        }
        return buildMe(u, true);
    }

    @Transactional
    public AccountMeResponse deleteMySignature() {
        UserAccount u = currentUser();
        String old = u.getSignaturePath();
        u.setSignaturePath(null);
        userAccountRepository.save(u);
        fileStorageService.deleteStoredFile(old);
        return buildMe(u, true);
    }

    private record DecodedImage(byte[] data, String contentType) {}

    private static DecodedImage decodeSignatureImage(String raw) {
        if (raw == null || raw.isBlank()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Thiếu dữ liệu ảnh chữ ký");
        }
        String value = raw.trim();
        String contentType = MediaType.IMAGE_PNG_VALUE;
        String b64 = value;
        if (value.startsWith("data:image")) {
            int comma = value.indexOf(',');
            if (comma < 0) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "Định dạng ảnh không hợp lệ");
            }
            String meta = value.substring(5, comma);
            if (meta.toLowerCase(Locale.ROOT).contains("jpeg") || meta.toLowerCase(Locale.ROOT).contains("jpg")) {
                contentType = MediaType.IMAGE_JPEG_VALUE;
            }
            b64 = value.substring(comma + 1);
        }
        try {
            byte[] data = Base64.getDecoder().decode(b64);
            if (data.length < 32) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "Ảnh chữ ký không hợp lệ");
            }
            return new DecodedImage(data, contentType);
        } catch (IllegalArgumentException ex) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Ảnh chữ ký base64 không hợp lệ");
        }
    }

    private void updateErpProfile(UserAccount u, AccountProfileUpdateRequest req) {
        ErpProfileResponse.ErpProfile current;
        try {
            current = erpAuthClient.getProfile(u.getErpAccessToken()).getProfile();
        } catch (ApiException ex) {
            if (ex.getStatus() == HttpStatus.UNAUTHORIZED) {
                u.setErpAccessToken(null);
                userAccountRepository.save(u);
            }
            throw ex;
        }

        String fullName = firstNonBlank(req.getFullName(), current.getUserFullName());
        String email = firstNonBlank(req.getEmail(), current.getEmail());
        String dob = normalizeDob(firstNonBlank(req.getDateOfBirth(), current.getDob()));
        String avatar = req.getUserAvatar() != null && !req.getUserAvatar().isBlank()
                && !req.getUserAvatar().contains("/j1-api/v1/account/")
                ? req.getUserAvatar().trim()
                : nullToEmpty(current.getUserAvatar());

        ErpProfileUpdateResponse updated = erpAuthClient.updateProfile(
                u.getErpAccessToken(),
                ErpProfileUpdateBody.builder()
                        .userFullName(fullName)
                        .email(email)
                        .dob(dob)
                        .userAvatar(avatar)
                        .build());

        if (updated.getToken() != null && !updated.getToken().isBlank()) {
            u.setErpAccessToken(updated.getToken().trim());
        }
        if (fullName != null && !fullName.isBlank()) {
            u.setDisplayName(fullName.trim());
        }
        if (email != null && !email.isBlank()) {
            applyEmail(u, email.trim());
        }
        userAccountRepository.save(u);

        employeeLinkService.findLinkedEmployee(u).ifPresent(e -> {
            if (fullName != null && !fullName.isBlank() && !fullName.equals(e.getFullName())) {
                e.setFullName(fullName.trim());
                employeeRepository.save(e);
            }
        });
    }

    private void updateLocalOnly(UserAccount u, AccountProfileUpdateRequest req) {
        if (req.getEmail() != null && !req.getEmail().isBlank()) {
            applyEmail(u, req.getEmail().trim());
        }
        if (req.getFullName() != null && !req.getFullName().isBlank()) {
            u.setDisplayName(req.getFullName().trim());
        }
        userAccountRepository.save(u);

        employeeLinkService.findLinkedEmployee(u).ifPresent(e -> {
            boolean changed = false;
            if (req.getPhone() != null) {
                if (req.getPhone().trim().isEmpty()) {
                    e.setPhone(null);
                    changed = true;
                } else {
                    employeeService.syncPhoneAndLoginUsername(e, req.getPhone());
                    changed = true;
                }
            }
            if (req.getAddress() != null) {
                e.setAddress(req.getAddress().trim().isEmpty() ? null : req.getAddress().trim());
                changed = true;
            }
            if (req.getFullName() != null && !req.getFullName().isBlank()) {
                e.setFullName(req.getFullName().trim());
                changed = true;
            }
            if (req.getDepartmentId() != null) {
                Department d = departmentRepository
                        .findById(req.getDepartmentId())
                        .orElseThrow(() -> new ApiException(HttpStatus.BAD_REQUEST, "Phòng ban không tồn tại"));
                e.setDepartment(d);
                changed = true;
            }
            if (changed) {
                employeeRepository.save(e);
            }
        });
    }

    private void applyEmail(UserAccount u, String email) {
        if (!email.equalsIgnoreCase(u.getEmail())
                && userAccountRepository.existsByEmailIgnoreCaseAndIdNot(email, u.getId())) {
            throw new ApiException(HttpStatus.CONFLICT, "Email đã được sử dụng");
        }
        u.setEmail(email);
    }

    private UserAccount currentUser() {
        return userAccountRepository
                .findByUsername(SecurityUtils.currentUsername())
                .orElseThrow(() -> new ApiException(HttpStatus.UNAUTHORIZED, "Chưa đăng nhập"));
    }

    private AccountMeResponse buildMe(UserAccount u, boolean tryErp) {
        AccountMeResponse.AccountMeResponseBuilder b = AccountMeResponse.builder()
                .userId(u.getId())
                .username(u.getUsername())
                .email(u.getEmail())
                .role(u.getRole().name())
                .enabled(u.isEnabled())
                .directorApprovalEnabled(u.isDirectorApprovalEnabled())
                .reportViewEnabled(u.isReportViewEnabled())
                .workUnitScoped(u.isWorkUnitScoped())
                .mustChangePassword(u.isMustChangePassword())
                .createdAt(u.getCreatedAt().toString())
                .erpLinked(false);

        Optional<Employee> empOpt = employeeLinkService.findLinkedEmployee(u);
        if (empOpt.isPresent()) {
            Employee e = empOpt.get();
            b.employeeId(e.getId())
                    .fullName(e.getFullName())
                    .phone(e.getPhone())
                    .address(e.getAddress())
                    .employeeCode(resolveEmployeeCode(e))
                    .departmentName(e.getDepartment() != null ? e.getDepartment().getName() : null)
                    .departmentId(e.getDepartment() != null ? e.getDepartment().getId() : null)
                    .positionTitle(e.getPosition() != null ? e.getPosition().getTitle() : null)
                    .workUnitDetail(employeeWorkforceDetailsRepository.findByEmployee(e)
                            .map(w -> w.getWorkUnitDetail())
                            .map(String::trim)
                            .filter(s -> !s.isBlank())
                            .orElse(null))
                    .dateOfBirth(e.getDateOfBirth() != null ? e.getDateOfBirth().toString() : null)
                    .employeeStatus(e.getStatus() != null ? e.getStatus().name() : null)
                    .canViewSalary(resolveCanViewSalary(u, e));
        } else {
            b.employeeId(null)
                    .fullName(u.getDisplayName() != null && !u.getDisplayName().isBlank()
                            ? u.getDisplayName()
                            : u.getUsername())
                    .phone("")
                    .address("")
                    .employeeCode(null)
                    .departmentName(null)
                    .departmentId(null)
                    .positionTitle(null)
                    .workUnitDetail(null)
                    .employeeStatus(null)
                    .canViewSalary(true);
        }

        if (tryErp && u.getErpAccessToken() != null && !u.getErpAccessToken().isBlank()) {
            try {
                ErpProfileResponse.ErpProfile p = erpAuthClient.getProfile(u.getErpAccessToken()).getProfile();
                mergeErpIntoBuilder(b, p);
            } catch (ApiException ex) {
                if (ex.getStatus() == HttpStatus.UNAUTHORIZED) {
                    log.info("ERP token hết hạn cho userId={}", u.getId());
                    u.setErpAccessToken(null);
                    userAccountRepository.save(u);
                } else {
                    log.warn("Không lấy hồ sơ ERP cho userId={}: {}", u.getId(), ex.getMessage());
                }
            } catch (Exception ex) {
                log.warn("Không lấy hồ sơ ERP cho userId={}: {}", u.getId(), ex.getMessage());
            }
        }

        boolean hasSig = u.getSignaturePath() != null && !u.getSignaturePath().isBlank();
        boolean hasAvatar = u.getAvatarPath() != null && !u.getAvatarPath().isBlank();
        b.hasSignature(hasSig)
                .signatureUrl(hasSig ? "/j1-api/v1/account/me/signature" : null)
                .hasAvatar(hasAvatar);
        if (hasAvatar) {
            b.userAvatar("/j1-api/v1/account/me/avatar");
        }

        return b.build();
    }

    private boolean resolveCanViewSalary(UserAccount u, Employee e) {
        if (u.getRole() == UserRole.ADMIN || u.getRole() == UserRole.HR || u.getRole() == UserRole.DIRECTOR) {
            return true;
        }
        return employeeService.canViewOwnSalary(e);
    }

    /** Mã NV ưu tiên employeeCode; nếu trống thì dùng CCCD/CMND. */
    private static String resolveEmployeeCode(Employee e) {
        if (e.getEmployeeCode() != null && !e.getEmployeeCode().isBlank()) {
            return e.getEmployeeCode().trim();
        }
        if (e.getIdCardNumber() != null && !e.getIdCardNumber().isBlank()) {
            return e.getIdCardNumber().trim();
        }
        return null;
    }

    private void mergeErpIntoBuilder(
            AccountMeResponse.AccountMeResponseBuilder b,
            ErpProfileResponse.ErpProfile p) {
        b.erpLinked(true).userEnrollNumber(p.getUserEnrollNumber());

        String rawAvatar = p.getUserAvatar();
        if (rawAvatar != null && !rawAvatar.isBlank()) {
            b.userAvatar("/j1-api/v1/account/me/avatar");
            log.debug("ERP UserAvatar raw={}",
                    rawAvatar.length() > 80 ? rawAvatar.substring(0, 80) + "…" : rawAvatar);
        } else {
            b.userAvatar("");
        }

        if (p.getUserFullName() != null && !p.getUserFullName().isBlank()) {
            b.fullName(p.getUserFullName().trim());
        }
        if (p.getEmail() != null && !p.getEmail().isBlank()) {
            b.email(p.getEmail().trim());
        }
        if (p.getPhone() != null && !p.getPhone().isBlank()) {
            b.phone(p.getPhone().trim());
        }
        String dob = normalizeDob(p.getDob());
        if (dob != null) {
            b.dateOfBirth(dob);
        }
        // Phòng ban giữ theo HRM — không ghi đè Phong_khoa ERP
    }

    List<String> resolveAvatarCandidateUrls(String raw) {
        Set<String> out = new LinkedHashSet<>();
        String value = raw.trim();
        if (value.startsWith("http://") || value.startsWith("https://") || value.startsWith("data:")) {
            out.add(value);
            return new ArrayList<>(out);
        }
        String path = value.startsWith("/") ? value : "/" + value;
        String fileName = path.contains("/") ? path.substring(path.lastIndexOf('/') + 1) : path;

        for (String assetBase : assetBaseCandidates()) {
            // ERP Express: GET /api/auth/avatar/:filename (cần Bearer)
            if (!fileName.isBlank()) {
                out.add(assetBase + "/api/auth/avatar/" + fileName);
            }
            // Một số bản mount static dưới /api/auth
            out.add(assetBase + "/api/auth" + path);
            out.add(assetBase + "/api" + path);
            out.add(assetBase + path);
        }
        return new ArrayList<>(out);
    }

    private List<String> assetBaseCandidates() {
        LinkedHashSet<String> bases = new LinkedHashSet<>();
        bases.add(assetBaseUrl());
        String apiBase = apiBaseUrl();
        if (!apiBase.equals(assetBaseUrl())) {
            bases.add(apiBase);
        }
        // Node ERP thường chạy cổng 3000 trong LAN (Apache chỉ proxy /api)
        bases.add("http://192.168.8.16:3000");
        return new ArrayList<>(bases);
    }

    private String apiBaseUrl() {
        String base = hrmProperties.getErpAuth().getBaseUrl();
        if (base == null || base.isBlank()) {
            return "https://erp.benhvienminhan.com";
        }
        return base.endsWith("/") ? base.substring(0, base.length() - 1) : base.trim();
    }

    private String assetBaseUrl() {
        HrmProperties.ErpAuth cfg = hrmProperties.getErpAuth();
        String asset = cfg.getAssetBaseUrl();
        if (asset == null || asset.isBlank()) {
            asset = cfg.getBaseUrl();
        }
        if (asset == null || asset.isBlank()) {
            return "https://erp.benhvienminhan.com";
        }
        return asset.endsWith("/") ? asset.substring(0, asset.length() - 1) : asset.trim();
    }

    private static ErpAuthClient.AvatarBytes decodeDataUri(String dataUri) {
        int comma = dataUri.indexOf(',');
        if (comma < 0) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Avatar data URI không hợp lệ");
        }
        String meta = dataUri.substring(5, comma);
        String b64 = dataUri.substring(comma + 1);
        String contentType = MediaType.IMAGE_JPEG_VALUE;
        int semi = meta.indexOf(';');
        if (semi > 0) {
            contentType = meta.substring(0, semi);
        } else if (!meta.isBlank()) {
            contentType = meta;
        }
        try {
            return new ErpAuthClient.AvatarBytes(Base64.getDecoder().decode(b64), contentType);
        } catch (IllegalArgumentException e) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Avatar base64 không hợp lệ");
        }
    }

    private static String normalizeDob(String raw) {
        if (raw == null || raw.isBlank()) {
            return null;
        }
        String s = raw.trim();
        if (s.length() >= 10) {
            s = s.substring(0, 10);
        }
        try {
            LocalDate.parse(s);
            return s;
        } catch (DateTimeParseException e) {
            return null;
        }
    }

    private static String firstNonBlank(String preferred, String fallback) {
        if (preferred != null && !preferred.isBlank()) {
            return preferred.trim();
        }
        if (fallback != null && !fallback.isBlank()) {
            return fallback.trim();
        }
        return null;
    }

    private static String nullToEmpty(String value) {
        return value == null ? "" : value;
    }
}
