# Order Satellite Demo

Aplicacion demo Micronaut que expone una interfaz HTML sin autenticacion para crear y buscar ordenes delegando en la API externa de ordenes publicada en AWS API Gateway + Lambda.

## Componentes

- Vista Thymeleaf en `/` con formulario de creacion, busqueda por ID y salida JSON formateada.
- API local en `/api/orders` que delega al cliente HTTP declarativo.
- Cliente Micronaut `@Client` apuntando a `https://z410yhtm4c.execute-api.us-east-1.amazonaws.com`.
- Contrato IDP de observabilidad en `contracts/observability/observability-contract.yaml`.
- Catalogo complementario de metricas/logs en `contracts/observability/order-satellite-metrics-catalog.yaml`, alineado con el preset `monolith-business-app`.
- Instrumentacion OpenTelemetry Java agent para metricas HTTP/JVM estandar exportadas por OTLP.
- Metricas Micrometer locales:
  - `orders.created.total`
  - `orders.processing.duration`

## Ejecutar

Este repositorio incluye archivos Gradle estandar. En una maquina con Gradle instalado:

```bash
gradle run
```

Luego abrir:

```text
http://localhost:8080
```

La URL base de la API target puede cambiarse con:

```bash
ORDER_API_BASE_URL=https://otro-host.example.com gradle run
```

## CI/CD

El repositorio define tres workflows de GitHub Actions:

- `CI`: compila y prueba la aplicacion, construye la imagen Docker y valida Terraform.
- `Deploy`: se ejecuta manualmente, consume `contracts/observability/observability-contract.yaml` con el IDP de observabilidad, publica la imagen en ECR y despliega la app en ECS/Fargate detras de un Application Load Balancer.
- `Teardown`: destruye el stack ECS/Fargate asociado al prefijo indicado.

El despliegue es manual-only y siempre usa un prefijo. El input `resource_prefix` tiene default `aws-dev-mn`.

Inputs principales de `Deploy`:

- `resource_prefix`: prefijo de recursos y estado Terraform.
- `vpc_id`: VPC destino obligatoria para ejecuciones manuales. Terraform auto-detecta las subredes publicas buscando route tables con ruta `0.0.0.0/0` hacia un Internet Gateway.
- `log_retention_in_days`: retencion de logs de CloudWatch.
- `export_strategy`: `collector` o `direct`; el workflow genera un contrato efectivo antes de llamar al IDP. `collector` reutiliza la management suite del IDP cuando no se proveen overrides, mientras que `direct` despliega solo contra AWS sin suite administrada ni endpoints OTLP externos.
- `collector_endpoint`, `collector_traces_endpoint`, `collector_metrics_endpoint`: overrides OTLP opcionales para collector mode. Si se provee `collector_endpoint`, este endpoint explicito toma precedencia sobre la management suite.

Secrets requeridos en GitHub Actions, configurados en el environment `aws-dev` o a nivel de repositorio:

- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_SESSION_TOKEN`

Variables opcionales:

- `AWS_REGION` default `us-east-1`
- `STACK_NAME` default `order-satellite-service`
- `RESOURCE_PREFIX` default `aws-dev-mn`
- `TF_STATE_BUCKET` y `TF_STATE_KEY` para usar un backend remoto existente
- `ORDER_API_BASE_URL`

El workflow de observabilidad usa `pazfernando/workshop-idp-o11y/.github/actions/contract-consumer@main` sobre el contrato efectivo. Para ECS/Fargate no se generan bindings Lambda; se usa el IDP para validacion, plan y resolucion del endpoint del collector administrado cuando `export_strategy=collector`. Cuando `export_strategy=direct`, el workflow no intenta resolver la management suite y Terraform no configura endpoints OTLP de collector.

La instrumentacion de este workload no es configurable desde el workflow: la imagen incluye el OpenTelemetry Java agent y Terraform lo habilita siempre con `javaagent`.

## Estructura

```text
src/main/java/com/example/ordersatellite
  client/OrderApiClient.java
  controller/OrderApiController.java
  controller/OrderViewController.java
  dto/OrderRequest.java
  dto/OrderResponse.java
contracts/observability/observability-contract.yaml
contracts/observability/order-satellite-metrics-catalog.yaml
infra/terraform
.github/workflows
```

Nota: el contrato declara `spec.telemetry.signals.metrics.catalog` con metricas OpenTelemetry soportadas por el preset `monolith-business-app`. El archivo complementario conserva el mismo catalogo para lectura rapida.
