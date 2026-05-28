package com.example.ordersatellite.exception;

import com.example.ordersatellite.dto.ApiError;
import io.micronaut.context.annotation.Requires;
import io.micronaut.http.HttpRequest;
import io.micronaut.http.HttpResponse;
import io.micronaut.http.client.exceptions.HttpClientResponseException;
import io.micronaut.http.server.exceptions.ExceptionHandler;
import jakarta.inject.Singleton;

import java.time.Instant;

@Singleton
@Requires(classes = {HttpClientResponseException.class, ExceptionHandler.class})
public class ExternalApiExceptionHandler implements ExceptionHandler<HttpClientResponseException, HttpResponse<ApiError>> {

    @Override
    @SuppressWarnings("rawtypes")
    public HttpResponse<ApiError> handle(HttpRequest request, HttpClientResponseException exception) {
        String remoteBody = exception.getResponse()
            .getBody(String.class)
            .orElse(exception.getMessage());

        ApiError body = new ApiError(
            exception.getStatus().getCode(),
            exception.getStatus().getReason(),
            remoteBody,
            request.getPath(),
            Instant.now()
        );

        return HttpResponse.status(exception.getStatus()).body(body);
    }
}
