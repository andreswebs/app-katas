# o11y

```sh
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo update
```

```sh
helm search repo opentelemetry # get chart version
helm show values open-telemetry/opentelemetry-collector # get default chart values.yaml
```

```sh
kubectl create secret generic \
    --namespace o11y \
    elastic-apm \
    --from-literal="ELASTIC_APM_ENDPOINT=${ELASTIC_APM_ENDPOINT}" \
    --from-literal="ELASTIC_APM_SECRET_TOKEN=${ELASTIC_APM_SECRET_TOKEN}"
```

```sh
KUSTOMIZATION_DIR="$(pwd)/overlays/nu"

kustomize build \
    --load-restrictor LoadRestrictionsNone \
    --enable-helm "${KUSTOMIZATION_DIR}" | \
kubectl apply --filename -
```

## References

<https://opentelemetry.io/docs/kubernetes/helm/collector/>

<https://github.com/open-telemetry/opentelemetry-helm-charts/blob/main/charts/opentelemetry-collector/values.yaml>

<https://www.elastic.co/observability-labs/blog/opentelemetry-observability>

<https://github.com/elastic/opentelemetry-demo>

<https://github.com/elastic/opentelemetry-demo/blob/main/kubernetes/elastic-helm/values.yaml>
