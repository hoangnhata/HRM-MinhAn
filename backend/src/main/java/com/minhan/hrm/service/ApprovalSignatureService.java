package com.minhan.hrm.service;

import com.minhan.hrm.entity.UserAccount;
import com.minhan.hrm.exception.ApiException;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;

import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Instant;
import java.util.Locale;

/**
 * Bắt buộc có chữ ký cá nhân khi duyệt đơn; snapshot file để xem lại lịch sử.
 */
@Service
@RequiredArgsConstructor
public class ApprovalSignatureService {

    private final FileStorageService fileStorageService;

    public record SignatureFile(byte[] data, String contentType) {}

    /** Đảm bảo user đã tạo chữ ký. */
    public void requireUserHasSignature(UserAccount user) {
        if (user == null || user.getSignaturePath() == null || user.getSignaturePath().isBlank()) {
            throw new ApiException(HttpStatus.BAD_REQUEST,
                    "Bạn chưa có chữ ký số. Vào menu tài khoản → Chữ ký số để tạo trước khi duyệt đơn.");
        }
        Path src = fileStorageService.resolveStoredPath(user.getSignaturePath());
        if (!Files.exists(src)) {
            throw new ApiException(HttpStatus.BAD_REQUEST,
                    "File chữ ký không tồn tại. Vào Chữ ký số để tạo lại trước khi duyệt.");
        }
    }

    /**
     * Copy chữ ký hiện tại của user vào thư mục đơn (audit nếu user đổi chữ ký sau này).
     */
    /**
     * Chữ ký người lập phiếu. Thiếu chữ ký thì báo trước khi gửi, không dùng câu chữ của bước duyệt.
     * {@code previousPath} được xóa nếu snapshot mới khác file cũ.
     */
    public String stampRequester(UserAccount user, String requestKind, long requestId, String previousPath) {
        String next;
        try {
            next = snapshotForApproval(user, requestKind, requestId, "requester");
        } catch (ApiException ex) {
            if (ex.getStatus() == HttpStatus.BAD_REQUEST) {
                throw new ApiException(HttpStatus.BAD_REQUEST,
                        "Bạn chưa có chữ ký số. Vào menu tài khoản → Chữ ký số để tạo trước khi gửi phiếu.");
            }
            throw ex;
        }
        if (previousPath != null && !previousPath.isBlank() && !previousPath.equals(next)) {
            fileStorageService.deleteStoredFile(previousPath);
        }
        return next;
    }

    public static String requesterSignatureUrl(String kind, long id, String path) {
        if (path == null || path.isBlank()) {
            return null;
        }
        return "/j1-api/v1/approval-signatures/" + kind + "/" + id + "/requester";
    }

    public String snapshotForApproval(UserAccount user, String requestKind, long requestId, String role) {
        requireUserHasSignature(user);
        Path src = fileStorageService.resolveStoredPath(user.getSignaturePath());
        String ext = user.getSignaturePath().toLowerCase(Locale.ROOT).endsWith(".jpg")
                || user.getSignaturePath().toLowerCase(Locale.ROOT).endsWith(".jpeg") ? ".jpg" : ".png";
        String subdir = "signatures/approvals/" + sanitize(requestKind) + "/" + requestId;
        String prefix = sanitize(role);
        try {
            byte[] data = Files.readAllBytes(src);
            String ct = ".jpg".equals(ext) ? MediaType.IMAGE_JPEG_VALUE : MediaType.IMAGE_PNG_VALUE;
            return fileStorageService.storeImageBytes(data, ct, subdir, prefix);
        } catch (ApiException ex) {
            throw ex;
        } catch (Exception ex) {
            throw new ApiException(HttpStatus.INTERNAL_SERVER_ERROR, "Không lưu được chữ ký duyệt đơn");
        }
    }

    /**
     * Snapshot chữ ký cho bước tự hoàn tất lúc lập phiếu (người lập chính là người duyệt bước đó,
     * vd. Trưởng khoa lập phiếu điều động). Người đó chưa có chữ ký thì để trống, không chặn luồng.
     */
    public String snapshotIfAvailable(UserAccount user, String requestKind, long requestId, String role) {
        if (user == null || user.getSignaturePath() == null || user.getSignaturePath().isBlank()) {
            return null;
        }
        try {
            return snapshotForApproval(user, requestKind, requestId, role);
        } catch (ApiException ex) {
            return null;
        }
    }

    /**
     * Chữ ký hiệu lực của một bước duyệt: snapshot đã lưu; thiếu snapshot mà bước đã có người duyệt
     * (bước tự hoàn tất / bỏ qua ở phiếu cũ) thì dùng chữ ký hồ sơ hiện tại của chính người đó.
     */
    public static String effectiveStagePath(String snapshotPath, UserAccount reviewer, Instant reviewedAt) {
        if (snapshotPath != null && !snapshotPath.isBlank()) {
            return snapshotPath;
        }
        if (reviewer == null || reviewedAt == null) {
            return null;
        }
        String profile = reviewer.getSignaturePath();
        return profile != null && !profile.isBlank() ? profile : null;
    }

    /** URL xem ảnh chữ ký của bước, {@code null} khi bước chưa có chữ ký hiệu lực. */
    public static String stageSignatureUrl(
            String kind, long id, String role, String snapshotPath, UserAccount reviewer, Instant reviewedAt) {
        return effectiveStagePath(snapshotPath, reviewer, reviewedAt) == null
                ? null
                : "/j1-api/v1/approval-signatures/" + kind + "/" + id + "/" + role;
    }

    public SignatureFile readRelative(String relativePath) {
        if (relativePath == null || relativePath.isBlank()) {
            throw new ApiException(HttpStatus.NOT_FOUND, "Không có chữ ký");
        }
        String normalized = relativePath.replace('\\', '/');
        if (!normalized.startsWith("signatures/")) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Đường dẫn chữ ký không hợp lệ");
        }
        try {
            Path path = fileStorageService.resolveStoredPath(relativePath);
            if (!Files.exists(path)) {
                throw new ApiException(HttpStatus.NOT_FOUND, "File chữ ký không tồn tại");
            }
            String name = path.getFileName().toString().toLowerCase(Locale.ROOT);
            String ct = name.endsWith(".jpg") || name.endsWith(".jpeg")
                    ? MediaType.IMAGE_JPEG_VALUE
                    : MediaType.IMAGE_PNG_VALUE;
            return new SignatureFile(Files.readAllBytes(path), ct);
        } catch (ApiException ex) {
            throw ex;
        } catch (Exception ex) {
            throw new ApiException(HttpStatus.INTERNAL_SERVER_ERROR, "Không đọc được chữ ký");
        }
    }

    private static String sanitize(String s) {
        return s == null ? "x" : s.replaceAll("[^a-zA-Z0-9_-]", "_");
    }
}
