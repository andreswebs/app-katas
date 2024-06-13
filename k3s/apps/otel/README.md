# o11y

```sh
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo update
helm search repo opentelemetry
helm show values open-telemetry/opentelemetry-collector
```

```sh
KUSTOMIZATION_DIR="$(pwd)/overlays/nu"

kustomize build --load-restrictor LoadRestrictionsNone --enable-helm "${KUSTOMIZATION_DIR}" | kubectl apply --filename -
```

## References

<https://opentelemetry.io/docs/kubernetes/helm/collector/>

<https://github.com/open-telemetry/opentelemetry-helm-charts/blob/main/charts/opentelemetry-collector/values.yaml>
