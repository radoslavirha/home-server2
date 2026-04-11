# Helm charts

## IoT applications

Environment-agnostic chart. All values live in `helm-values/iot/`.

### Interactive map feeder

Deploy to sandbox environment

```sh
helm upgrade interactive-map-feeder iot-applications \
    --values ../../helm-values/iot/interactive-map-feeder.yaml \
    --values ../../helm-values/iot/sandbox/interactive-map-feeder.yaml \
    --values ../../helm-values/iot/sandbox/variables.yaml \
    --namespace sandbox \
    --install \
    --atomic \
    --cleanup-on-fail \
    --timeout 2m
```

Uninstall from sandbox environment

```sh
helm uninstall interactive-map-feeder \
    --namespace sandbox
```

Deploy to production environment

```sh
helm upgrade interactive-map-feeder iot-applications \
    --values ../../helm-values/iot/interactive-map-feeder.yaml \
    --values ../../helm-values/iot/production/interactive-map-feeder.yaml \
    --values ../../helm-values/iot/production/variables.yaml \
    --namespace production \
    --install \
    --atomic \
    --cleanup-on-fail \
    --timeout 2m
```

Uninstall from production environment

```sh
helm uninstall interactive-map-feeder \
    --namespace production
```

### Miot bridge

Deploy to sandbox environment

```sh
helm upgrade miot-bridge iot-applications \
    --values ../../helm-values/iot/miot-bridge.yaml \
    --values ../../helm-values/iot/sandbox/miot-bridge.yaml \
    --values ../../helm-values/iot/sandbox/variables.yaml \
    --namespace sandbox \
    --install \
    --atomic \
    --cleanup-on-fail \
    --timeout 2m
```

Deploy to production environment

```sh
helm upgrade miot-bridge iot-applications \
    --values ../../helm-values/iot/miot-bridge.yaml \
    --values ../../helm-values/iot/production/miot-bridge.yaml \
    --values ../../helm-values/iot/production/variables.yaml \
    --namespace production \
    --install \
    --atomic \
    --cleanup-on-fail \
    --timeout 2m
```

#### Show kubernetes objects

```sh
helm template iot-applications \
    --values ../../helm-values/iot/miot-bridge.yaml \
    --values ../../helm-values/iot/sandbox/miot-bridge.yaml \
    --values ../../helm-values/iot/sandbox/variables.yaml \
    --namespace sandbox
```
