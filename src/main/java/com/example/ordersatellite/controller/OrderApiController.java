package com.example.ordersatellite.controller;

import com.example.ordersatellite.client.OrderApiClient;
import com.example.ordersatellite.dto.OrderRequest;
import com.example.ordersatellite.dto.OrderResponse;
import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.Timer;
import io.micronaut.http.HttpStatus;
import io.micronaut.http.annotation.Body;
import io.micronaut.http.annotation.Controller;
import io.micronaut.http.annotation.Get;
import io.micronaut.http.annotation.PathVariable;
import io.micronaut.http.annotation.Post;
import io.micronaut.http.annotation.Status;
import io.micronaut.scheduling.TaskExecutors;
import io.micronaut.scheduling.annotation.ExecuteOn;
import io.micronaut.validation.Validated;
import jakarta.validation.Valid;

@Validated
@ExecuteOn(TaskExecutors.BLOCKING)
@Controller("/api/orders")
public class OrderApiController {

    private final OrderApiClient orderApiClient;
    private final MeterRegistry meterRegistry;

    public OrderApiController(OrderApiClient orderApiClient, MeterRegistry meterRegistry) {
        this.orderApiClient = orderApiClient;
        this.meterRegistry = meterRegistry;
    }

    @Post
    @Status(HttpStatus.CREATED)
    public OrderResponse crearOrden(@Valid @Body OrderRequest request) {
        Timer.Sample sample = Timer.start(meterRegistry);
        try {
            OrderResponse response = orderApiClient.crearOrden(request);
            registrarCreacion("success", request.productoId());
            return response;
        } catch (RuntimeException exception) {
            registrarCreacion("error", request.productoId());
            throw exception;
        } finally {
            sample.stop(Timer.builder("orders.processing.duration")
                .description("Duracion del procesamiento de ordenes")
                .tag("operation", "create")
                .register(meterRegistry));
        }
    }

    @Get("/{orderId}")
    public OrderResponse obtenerOrden(@PathVariable String orderId) {
        Timer.Sample sample = Timer.start(meterRegistry);
        try {
            return orderApiClient.obtenerOrden(orderId);
        } finally {
            sample.stop(Timer.builder("orders.processing.duration")
                .description("Duracion del procesamiento de ordenes")
                .tag("operation", "search")
                .register(meterRegistry));
        }
    }

    private void registrarCreacion(String status, String productId) {
        Counter.builder("orders.created.total")
            .description("Total de ordenes creadas")
            .tag("status", status)
            .tag("productId", productId)
            .register(meterRegistry)
            .increment();
    }
}
