package com.example.ordersatellite.dto;

import io.micronaut.serde.annotation.Serdeable;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;

@Serdeable
public record OrderResponse(
    String id,
    String orderId,
    String estado,
    String status,
    String customerId,
    String productoId,
    String productId,
    Integer cantidad,
    Integer quantity,
    List<OrderRequest.OrderItem> items,
    String currency,
    BigDecimal totalAmount,
    String paymentStatus,
    String message,
    Instant createdAt,
    Instant updatedAt
) {
}
