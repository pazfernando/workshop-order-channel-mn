package com.example.ordersatellite.dto;

import io.micronaut.serde.annotation.Serdeable;

import java.time.Instant;

@Serdeable
public record OrderResponse(
    String id,
    String orderId,
    String estado,
    String status,
    String productoId,
    String productId,
    Integer cantidad,
    Integer quantity,
    String message,
    Instant createdAt,
    Instant updatedAt
) {
}
