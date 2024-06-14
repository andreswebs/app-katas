# Vector

```sh
helm repo add vector https://helm.vector.dev
helm repo update
```

```sh
helm search repo vector
helm show values vector/vector
```

```sh
kubectl create secret generic \
    --namespace o11y \
    elastic \
    --from-literal="ELASTIC_URL=${ELASTIC_URL}" \
    --from-literal="ELASTIC_API_KEY=${ELASTIC_API_KEY}"
```

```sh
KUSTOMIZATION_DIR="$(pwd)/overlays/mu"

kustomize build \
    --load-restrictor LoadRestrictionsNone \
    --enable-helm "${KUSTOMIZATION_DIR}" | \
kubectl apply --filename -
```

## References

<https://vector.dev/docs/setup/installation/package-managers/helm/>

<https://github.com/vectordotdev/helm-charts>

<https://blog.palark.com/vector-log-collection-kubernetes/>
