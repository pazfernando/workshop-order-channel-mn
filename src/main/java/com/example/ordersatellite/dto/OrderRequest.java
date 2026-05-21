package com.example.ordersatellite.dto;

import io.micronaut.serde.annotation.Serdeable;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

@Serdeable
public record OrderRequest(
    @NotBlank String productoId,
    @NotNull @Min(1) Integer cantidad
) {
}
