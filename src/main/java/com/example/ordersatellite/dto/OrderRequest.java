package com.example.ordersatellite.dto;

import io.micronaut.serde.annotation.Serdeable;
import jakarta.validation.Valid;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;

import java.math.BigDecimal;
import java.util.List;

@Serdeable
public record OrderRequest(
    @NotBlank String customerId,
    @Valid @NotEmpty List<OrderItem> items,
    @NotBlank String currency
) {
    @Serdeable
    public record OrderItem(
        @NotBlank String sku,
        @NotNull @Min(1) Integer quantity,
        @NotNull @DecimalMin(value = "0.0", inclusive = false) BigDecimal unitPrice
    ) {
    }
}
