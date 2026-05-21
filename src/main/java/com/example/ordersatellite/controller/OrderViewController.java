package com.example.ordersatellite.controller;

import io.micronaut.http.annotation.Controller;
import io.micronaut.http.annotation.Get;
import io.micronaut.views.View;

import java.util.Map;

@Controller("/")
public class OrderViewController {

    @Get
    @View("orders")
    public Map<String, Object> index() {
        return Map.of(
            "title", "Order Satellite Demo"
        );
    }
}
