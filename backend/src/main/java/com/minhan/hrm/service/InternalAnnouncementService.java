package com.minhan.hrm.service;

import com.minhan.hrm.dto.announcement.AnnouncementRequest;
import com.minhan.hrm.entity.AnnouncementAttachment;
import com.minhan.hrm.entity.AnnouncementCategory;
import com.minhan.hrm.entity.AnnouncementPriority;
import com.minhan.hrm.entity.InternalAnnouncement;
import com.minhan.hrm.entity.UserAccount;
import com.minhan.hrm.exception.ApiException;
import com.minhan.hrm.exception.ResourceNotFoundException;
import com.minhan.hrm.repository.AnnouncementAttachmentRepository;
import com.minhan.hrm.repository.InternalAnnouncementRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.core.io.Resource;
import org.springframework.core.io.UrlResource;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;
import org.springframework.web.multipart.MultipartFile;

import java.net.MalformedURLException;
import java.nio.file.Path;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class InternalAnnouncementService {

    private final InternalAnnouncementRepository announcementRepository;
    private final AnnouncementAttachmentRepository attachmentRepository;
    private final EmployeeService employeeService;
    private final FileStorageService fileStorageService;
    private final NotificationService notificationService;

    @Transactional(readOnly = true)
    public List<Map<String, Object>> listActive(String categoryStr) {
        AnnouncementCategory filter = parseCategoryOrNull(categoryStr);
        return announcementRepository.findActiveWithAttachments(Instant.now(), filter).stream()
                .map(this::toMap)
                .collect(Collectors.toList());
    }

    private AnnouncementCategory parseCategoryOrNull(String categoryStr) {
        if (categoryStr == null || categoryStr.isBlank()) {
            return null;
        }
        if (!AnnouncementCategory.isValidName(categoryStr.trim())) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Mục thông báo không hợp lệ");
        }
        return AnnouncementCategory.valueOf(categoryStr.trim());
    }

    private AnnouncementCategory resolveCategory(AnnouncementRequest req) {
        if (req.getCategory() == null || req.getCategory().isBlank()) {
            return AnnouncementCategory.THONG_BAO_CHUNG;
        }
        if (!AnnouncementCategory.isValidName(req.getCategory())) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Mục thông báo không hợp lệ");
        }
        return AnnouncementCategory.valueOf(req.getCategory().trim());
    }

    @PreAuthorize("hasRole('ADMIN')")
    @Transactional
    public Map<String, Object> create(AnnouncementRequest req, List<MultipartFile> files) {
        UserAccount author = employeeService.currentUser();
        AnnouncementCategory cat = resolveCategory(req);
        InternalAnnouncement a = InternalAnnouncement.builder()
                .title(req.getTitle().trim())
                .body(req.getBody())
                .category(cat)
                .displayDate(req.getDisplayDate())
                .priority(req.getPriority() != null ? req.getPriority() : AnnouncementPriority.NORMAL)
                .author(author)
                .expiresAt(req.getExpiresAt())
                .build();
        a = announcementRepository.save(a);

        if (files != null && !files.isEmpty()) {
            int i = 0;
            for (MultipartFile f : files) {
                if (f == null || f.isEmpty()) {
                    continue;
                }
                String rel = fileStorageService.storeAnnouncementFile(f, "announcements/" + a.getId());
                String label = "tại đây";
                if (req.getLinkLabels() != null && i < req.getLinkLabels().size()) {
                    String l = req.getLinkLabels().get(i);
                    if (l != null && !l.isBlank()) {
                        label = l.trim();
                    }
                }
                AnnouncementAttachment att = AnnouncementAttachment.builder()
                        .announcement(a)
                        .originalName(f.getOriginalFilename() != null ? f.getOriginalFilename() : "file")
                        .storedPath(rel)
                        .contentType(f.getContentType())
                        .linkLabel(label)
                        .sortOrder(i)
                        .build();
                a.getAttachments().add(att);
                i++;
            }
            a = announcementRepository.save(a);
        }

        InternalAnnouncement full = announcementRepository.findByIdWithAttachments(a.getId()).orElse(a);
        notificationService.notifyAllUsersAboutNewAnnouncement(full.getId(), author.getId());
        return toMap(full);
    }

    private Map<String, Object> toMap(InternalAnnouncement a) {
        List<AnnouncementAttachment> sorted = new ArrayList<>(a.getAttachments());
        sorted.sort(Comparator.comparingInt(AnnouncementAttachment::getSortOrder));
        List<Map<String, Object>> attachmentMaps = sorted.stream()
                .map(att -> {
                    Map<String, Object> m = new LinkedHashMap<>();
                    m.put("id", att.getId());
                    m.put("originalName", att.getOriginalName());
                    m.put("linkLabel", att.getLinkLabel());
                    m.put("contentType", att.getContentType() != null ? att.getContentType() : "");
                    return m;
                })
                .collect(Collectors.toList());

        String displayDateIso = null;
        if (a.getDisplayDate() != null) {
            displayDateIso = a.getDisplayDate().toString();
        }

        Map<String, Object> out = new LinkedHashMap<>();
        out.put("id", a.getId());
        out.put("title", a.getTitle());
        out.put("body", a.getBody());
        out.put("category", a.getCategory().name());
        out.put("categoryLabel", a.getCategory().getLabelVi());
        out.put("displayDate", displayDateIso);
        out.put("priority", a.getPriority().name());
        out.put("authorUsername", a.getAuthor().getUsername());
        out.put("publishedAt", a.getPublishedAt().toString());
        out.put("expiresAt", a.getExpiresAt() != null ? a.getExpiresAt().toString() : "");
        out.put("attachments", attachmentMaps);
        return out;
    }

    @Transactional(readOnly = true)
    public ResponseEntity<Resource> serveAttachment(Long attachmentId) {
        AnnouncementAttachment att = attachmentRepository.findById(attachmentId)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy đính kèm"));
        InternalAnnouncement ann = att.getAnnouncement();
        if (ann.getExpiresAt() != null && ann.getExpiresAt().isBefore(Instant.now())) {
            throw new ResourceNotFoundException("Không tìm thấy đính kèm");
        }
        Path path = fileStorageService.resolveStoredPath(att.getStoredPath());
        try {
            Resource resource = new UrlResource(path.toUri());
            if (!resource.exists() || !resource.isReadable()) {
                throw new ResourceNotFoundException("File không tồn tại trên ổ đĩa");
            }
            MediaType mt = MediaType.APPLICATION_OCTET_STREAM;
            if (StringUtils.hasText(att.getContentType())) {
                try {
                    mt = MediaType.parseMediaType(att.getContentType());
                } catch (Exception ignored) {
                }
            }
            return ResponseEntity.ok()
                    .contentType(mt)
                    .header(HttpHeaders.CONTENT_DISPOSITION, "inline; filename=\"" + att.getOriginalName() + "\"")
                    .body(resource);
        } catch (MalformedURLException e) {
            throw new ApiException(HttpStatus.INTERNAL_SERVER_ERROR, "Không đọc được file");
        }
    }

    @PreAuthorize("hasRole('ADMIN')")
    @Transactional
    public void delete(Long id) {
        InternalAnnouncement a = announcementRepository.findByIdWithAttachments(id)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy thông báo nội viện"));
        for (AnnouncementAttachment att : a.getAttachments()) {
            fileStorageService.deleteStoredFile(att.getStoredPath());
        }
        announcementRepository.delete(a);
    }
}
