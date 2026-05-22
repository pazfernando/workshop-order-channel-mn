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
import io.micronaut.validation.Validated;
import jakarta.validation.Valid;
import reactor.core.publisher.Mono;

@Validated
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
    public Mono<OrderResponse> crearOrden(@Valid @Body OrderRequest request) {
        Timer.Sample sample = Timer.start(meterRegistry);
        return orderApiClient.crearOrden(request)
            .doOnSuccess(response -> registrarCreacion("success", request.productoId()))
            .doOnError(exception -> registrarCreacion("error", request.productoId()))
            .doFinally(signalType -> sample.stop(Timer.builder("orders.processing.duration")
                .description("Duracion del procesamiento de ordenes")
                .tag("operation", "create")
                .register(meterRegistry)));
    }

    @Get("/{orderId}")
    public Mono<OrderResponse> obtenerOrden(@PathVariable String orderId) {
        Timer.Sample sample = Timer.start(meterRegistry);
        return orderApiClient.obtenerOrden(orderId)
            .doFinally(signalType -> sample.stop(Timer.builder("orders.processing.duration")
                .description("Duracion del procesamiento de ordenes")
                .tag("operation", "search")
                .register(meterRegistry)));
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
