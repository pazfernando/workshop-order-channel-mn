FROM gradle:8.9-jdk21 AS build

WORKDIR /workspace
COPY --chown=gradle:gradle settings.gradle build.gradle gradle.properties ./
COPY --chown=gradle:gradle src ./src
RUN gradle --no-daemon clean shadowJar

FROM eclipse-temurin:21-jre

ARG OTEL_JAVA_AGENT_VERSION=2.10.0

RUN apt-get update \
    && apt-get install -y --no-install-recommends curl ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /app /otel
ADD https://github.com/open-telemetry/opentelemetry-java-instrumentation/releases/download/v${OTEL_JAVA_AGENT_VERSION}/opentelemetry-javaagent.jar /otel/opentelemetry-javaagent.jar

WORKDIR /app
COPY --from=build /workspace/build/libs/*-all.jar /app/app.jar

EXPOSE 8080
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
