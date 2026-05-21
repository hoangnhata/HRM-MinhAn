package com.minhan.hrm.dto.announcement;

import com.minhan.hrm.entity.AnnouncementPriority;
import jakarta.validation.constraints.NotBlank;
import lombok.Data;

import java.time.Instant;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;

@Data
public class AnnouncementRequest {

    @NotBlank
    private String title;

    @NotBlank
    private String body;

    /** Tên enum {@link com.minhan.hrm.entity.AnnouncementCategory} */
    private String category;

    /** Ngày hiển thị (dòng đỏ); null = theo ngày đăng */
    private LocalDate displayDate;

    private AnnouncementPriority priority = AnnouncementPriority.NORMAL;

    private Instant expiresAt;

    /** Cùng thứ tự với từng file khi upload multipart */
    private List<String> linkLabels = new ArrayList<>();
}
