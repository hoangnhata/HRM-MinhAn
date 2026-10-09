package com.minhan.hrm.repository;

import com.minhan.hrm.entity.SeminarProposalAttachment;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface SeminarProposalAttachmentRepository extends JpaRepository<SeminarProposalAttachment, Long> {

    List<SeminarProposalAttachment> findByProposal_IdOrderByIdAsc(Long proposalId);

    long countByProposal_Id(Long proposalId);
}
