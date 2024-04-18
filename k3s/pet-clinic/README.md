# Elastic Agent on Spring Pet Clinic - example

## Pre-requisites

An Elastic Cloud instance is assumed to be available.

Install kube-state-metrics via Helm:

```sh
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install kube-state-metrics prometheus-community/kube-state-metrics -n kube-system
```

## Install Elastic Agent

Download the Elastic Agent manifest (adjustments to the file will be needed):

```sh
curl -L -O https://raw.githubusercontent.com/elastic/elastic-agent/8.12/deploy/kubernetes/elastic-agent-managed-kubernetes.yaml
```

There are two values from Elastic Cloud needed for the agent configuration:

- `FLEET_URL`: get it from the Fleet UI
- `FLEET_ENROLLMENT_TOKEN`: generate first (see steps below for agent policy and
  k8s integration)

These values should be stored in a secret in the cluster. (Note: the official
guide in Kibana hardcodes them in the generated manifest.)

Configure agent policy and k8s integration:

1. create agent policy
2. add kubernetes integration (use the "skip agent installation" option)
3. create enrollment token

Create the Kubernetes secret:

```sh
FLEET_URL="https://1234567890thisisarandomvalue.fleet.us-east-2.aws.elastic-cloud.com:443" # example
FLEET_ENROLLMENT_TOKEN="inserttheenrollmenttokenhere"
kubectl create secret generic --namespace kube-system elastic-agent-fleet-enrollment \
    --from-literal="FLEET_URL=${FLEET_URL}" \
    --from-literal="FLEET_ENROLLMENT_TOKEN=${FLEET_ENROLLMENT_TOKEN}"
```

And update the values in the manifest:

```yaml
- name: FLEET_URL
  valueFrom:
    secretKeyRef:
      name: elastic-agent-fleet-enrollment
      key: FLEET_URL
- name: FLEET_ENROLLMENT_TOKEN
  valueFrom:
    secretKeyRef:
      name: elastic-agent-fleet-enrollment
      key: FLEET_ENROLLMENT_TOKEN
```

Finally apply the updated manifest.

## Install APM agent

Configure the APM integration and retrieve the values for these variables from
the APM integration page in Kibana:

- `ELASTIC_APM_SERVER_URL`
- `ELASTIC_APM_SECRET_TOKEN`

Create a Kubernetes secret (note the namespace, it must be on the application
namespace):

```sh
# examples
APP_NAMESPACE="app"
ELASTIC_APM_SERVER_URL="https://9876543210thisisanotherrandomvalue.apm.us-east-2.aws.elastic-cloud.com:443"
ELASTIC_APM_SECRET_TOKEN="inserttheAPMtokenhere"
```

```sh
kubectl create secret generic --namespace "${APP_NAMESPACE}" elastic-apm \
    --from-literal="ELASTIC_APM_SERVER_URL=${ELASTIC_APM_SERVER_URL}" \
    --from-literal="ELASTIC_APM_SECRET_TOKEN=${ELASTIC_APM_SECRET_TOKEN}"
```

And update the values in the application manifest:

```yaml
- name: ELASTIC_APM_SERVER_URL
  valueFrom:
    secretKeyRef:
      name: elastic-apm
      key: ELASTIC_APM_SERVER_URL
- name: ELASTIC_APM_SECRET_TOKEN
  valueFrom:
    secretKeyRef:
      name: elastic-apm
      key: ELASTIC_APM_SECRET_TOKEN
```

Finally apply the updated manifest.

## Testing

Generate some load with the [`artificial-load.sh`](artificial-load.sh) script.

```sh
export API_URL="https://petclinic.example.com/petclinic/api"
./artificial-load.sh
```

## References

<https://www.elastic.co/guide/en/fleet/current/running-on-kubernetes-managed-by-fleet.html>

<https://spring-petclinic.github.io/>

<https://github.com/spring-petclinic/spring-petclinic-rest>

<https://github.com/spring-petclinic/spring-petclinic-angular>

<https://izekchen.medium.com/setup-elastic-apm-with-elasticsearch-operator-and-test-9b988fdb33ec>

<https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-state-metrics>

<https://www.elastic.co/guide/en/fleet/current/agent-environment-variables.html>

<https://www.elastic.co/guide/en/apm/agent/java/1.x/configuration.html>

<https://www.elastic.co/guide/en/observability/current/traces-get-started.html>
