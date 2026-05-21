package com.minhan.hrm.service;

import com.minhan.hrm.entity.Employee;
import com.minhan.hrm.entity.EmployeeDocument;
import com.minhan.hrm.entity.UserAccount;
import com.minhan.hrm.entity.UserRole;
import com.minhan.hrm.exception.ApiException;
import com.minhan.hrm.exception.ResourceNotFoundException;
import com.minhan.hrm.repository.EmployeeDocumentRepository;
import com.minhan.hrm.repository.EmployeeRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.core.io.Resource;
import org.springframework.core.io.UrlResource;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.net.MalformedURLException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class EmployeeDocumentService {

    private final EmployeeDocumentRepository documentRepository;
    private final EmployeeRepository employeeRepository;
    private final FileStorageService fileStorageService;
    private final EmployeeService employeeService;

    @PreAuthorize("hasRole('ADMIN')")
    @Transactional
    public void deleteAllForEmployee(Long employeeId) {
        Employee emp = employeeService.requireEmployeeEntity(employeeId);
        List<EmployeeDocument> docs = documentRepository.findByEmployeeOrderByCreatedAtDesc(emp);
        for (EmployeeDocument d : docs) {
            try {
                Path p = fileStorageService.resolveStoredPath(d.getStoredPath());
                Files.deleteIfExists(p);
            } catch (Exception ex) {
                // vẫn xóa bản ghi DB
            }
        }
        documentRepository.deleteAll(docs);
    }

    @PreAuthorize("hasRole('ADMIN')")
    @Transactional
    public Map<String, Object> upload(Long employeeId, MultipartFile file, String docType) {
        Employee emp = employeeService.requireEmployeeEntity(employeeId);
        UserAccount uploader = employeeService.currentUser();
        String relative = fileStorageService.storePdf(file, "employees/" + employeeId);
        EmployeeDocument doc = EmployeeDocument.builder()
                .employee(emp)
                .originalName(file.getOriginalFilename())
                .storedPath(relative)
                .contentType(file.getContentType())
                .docType(docType != null ? docType : "GENERAL")
                .uploadedBy(uploader)
                .build();
        doc = documentRepository.save(doc);
        return Map.of(
                "id", doc.getId(),
                "originalName", doc.getOriginalName(),
                "docType", doc.getDocType(),
                "createdAt", doc.getCreatedAt().toString());
    }

    @Transactional(readOnly = true)
    public List<Map<String, Object>> list(Long employeeId) {
        Employee emp = employeeService.requireEmployeeEntity(employeeId);
        assertCanAccessDocuments(emp);
        return documentRepository.findByEmployeeOrderByCreatedAtDesc(emp).stream()
                .map(d -> Map.<String, Object>of(
                        "id", d.getId(),
                        "originalName", d.getOriginalName(),
                        "docType", d.getDocType(),
                        "createdAt", d.getCreatedAt().toString()))
                .collect(Collectors.toList());
    }

    @Transactional(readOnly = true)
    public Resource loadFile(Long documentId) {
        EmployeeDocument doc = documentRepository.findById(documentId)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy tài liệu"));
        assertCanAccessDocuments(doc.getEmployee());
        Path path = fileStorageService.resolveStoredPath(doc.getStoredPath());
        try {
            Resource resource = new UrlResource(path.toUri());
            if (!resource.exists() || !resource.isReadable()) {
                throw new ResourceNotFoundException("File không tồn tại trên ổ đĩa");
            }
            return resource;
        } catch (MalformedURLException e) {
            throw new ApiException(HttpStatus.INTERNAL_SERVER_ERROR, "Không đọc được file");
        }
    }

    @Transactional(readOnly = true)
    public EmployeeDocument requireDocument(Long id) {
        return documentRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy tài liệu"));
    }

    private void assertCanAccessDocuments(Employee target) {
        UserAccount current = employeeService.currentUser();
        if (current.getRole() == UserRole.ADMIN) {
            return;
        }
        Employee self = employeeRepository.findByUserUsername(current.getUsername()).orElse(null);
        if (self == null || !self.getId().equals(target.getId())) {
            throw new ApiException(HttpStatus.FORBIDDEN, "Không có quyền xem tài liệu");
        }
    }
}
