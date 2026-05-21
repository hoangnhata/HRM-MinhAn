package com.minhan.hrm.controller;

import com.minhan.hrm.entity.Position;
import com.minhan.hrm.repository.PositionRepository;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/api/v1/positions")
@RequiredArgsConstructor
@SecurityRequirement(name = "bearerAuth")
@Tag(name = "Positions")
public class PositionController {

    private final PositionRepository positionRepository;

    @GetMapping
    public List<Position> list() {
        return positionRepository.findAll();
    }
}
