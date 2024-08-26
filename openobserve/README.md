# OpenObserve

## Notes

### Docker:

```sh
docker run -d \
      --name openobserve \
      -v "$(pwd)/data:/data" \
      -p 5080:5080 \
      -e ZO_ROOT_USER_EMAIL \
      -e ZO_ROOT_USER_PASSWORD \
      public.ecr.aws/zinclabs/openobserve:latest
```

### Authentication:

Initial root user is created on first run from env vars:

- `ZO_ROOT_USER_EMAIL` - On first run Email of first/root user
- `ZO_ROOT_USER_PASSWORD` - On first run Password for first/root user

Basic auth over HTTPS - Header creation (pseudocode):

```txt
Authorization: Basic base64("username:password")
```

### Ports:

- `ZO_HTTP_PORT` - Default 5080
- `ZO_GRPC_PORT` - Default 5081

### Telemetry

- `ZO_TELEMETRY` - Default true -	Send anonymous telemetry info for improving
  OpenObserve. Can be disabled by setting to false.
- `ZO_TELEMETRY_URL` - OpenTelemetry report URL.

### Env vars:

<https://openobserve.ai/docs/environment-variables/>

Notice:

- `ZO_WEB_URL` - UI access URL, eg: http://localhost:5080, used for redirect url
  and alert url.

- `ZO_PROMETHEUS_ENABLED` - Default false - Enables prometheus metrics on
  /metrics endpoint

### Storage:

<https://openobserve.ai/docs/storage/>

- `ZO_LOCAL_MODE_STORAGE` - Default disk - disk or s3, applicable only for local
  mode.

Using AWS S3, provide AWS credentials normally (through env vars, or IAM role on
an EC2 instance). Other S3-compatible stores can be used.

### Healthcheck:

```txt
/healthz
```

### OpenTelemetry

GRPC:

```yaml
exporters:
  otlp/openobserve:
      endpoint: example.com:5081
      headers:
        Authorization: "Basic cm9v****************************************Ng=="
        organization: default
        stream-name: default
      tls:
        insecure: false
```

HTTP:

```yaml
exporters:
  otlphttp/openobserve:
    ## https://example.com/api/<myorg>
    endpoint: https://example.com/api/default  # Endpoint cannot have a trailing slash; <myorg> = default
    headers:
      Authorization: Basic cm9v****************************************Ng==
      stream-name: default
```

## References

<https://github.com/openobserve/openobserve>

<https://openobserve.ai/docs>

<https://openobserve.ai/blog/launching-openobserve>
