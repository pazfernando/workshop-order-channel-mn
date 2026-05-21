package com.example.ordersatellite.client;

import com.example.ordersatellite.dto.OrderRequest;
import com.example.ordersatellite.dto.OrderResponse;
import io.micronaut.http.MediaType;
import io.micronaut.http.annotation.Body;
import io.micronaut.http.annotation.Consumes;
import io.micronaut.http.annotation.Get;
import io.micronaut.http.annotation.PathVariable;
import io.micronaut.http.annotation.Post;
import io.micronaut.http.annotation.Produces;
import io.micronaut.http.client.annotation.Client;

@Client("${order.api.base-url}")
public interface OrderApiClient {

    @Post("/orders")
    @Consumes(MediaType.APPLICATION_JSON)
    @Produces(MediaType.APPLICATION_JSON)
    OrderResponse crearOrden(@Body OrderRequest request);

    @Get("/orders/{orderId}")
    @Produces(MediaType.APPLICATION_JSON)
    OrderResponse obtenerOrden(@PathVariable String orderId);
}
