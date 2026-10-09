package com.minhan.hrm.repository;

import com.minhan.hrm.entity.NursingEvaluationTemplateRevision;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface NursingEvaluationTemplateRevisionRepository
        extends JpaRepository<NursingEvaluationTemplateRevision, Long> {

    @EntityGraph(attributePaths = "createdBy")
    Optional<NursingEvaluationTemplateRevision> findFirstByTemplateCodeOrderByVersionDesc(String templateCode);

    @EntityGraph(attributePaths = "createdBy")
    List<NursingEvaluationTemplateRevision> findByTemplateCodeOrderByVersionDesc(String templateCode);

    Optional<NursingEvaluationTemplateRevision> findByIdAndTemplateCode(Long id, String templateCode);
}
