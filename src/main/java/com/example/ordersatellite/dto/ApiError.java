package com.example.ordersatellite.dto;

import io.micronaut.serde.annotation.Serdeable;

import java.time.Instant;

@Serdeable
public record ApiError(
    int status,
    String error,
    String message,
    String path,
    Instant timestamp
) {
}
