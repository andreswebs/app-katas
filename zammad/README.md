## Misc

S3 storage example URL:

```sh
S3_URL="https://key:secret@s3.eu-central-1.amazonaws.com/example-zammad-storage-bucket?region=eu-central-1&force_path_style=true"
```

## Auto-Wizard

<https://community.zammad.org/t/docker-compose-autowizard-json-usage/7689/1>

<https://community.zammad.org/t/docker-compose-autowizard-json-usage/7689/5>

- set up a JSON
- base64 encode the contents
- set it in the `AUTOWIZARD_JSON` env var for the `zammad-init` service
- visit the URL path `/#getting_started/auto_wizard/<token>`, where `<token>` is the value set at the `$.Token` field of the JSON

## References

<https://deepwiki.com/zammad/zammad>

<https://zammad.org/documentation>

<https://github.com/zammad/zammad-docker-compose>

<https://github.com/zammad/zammad>

<https://zammad-foundation.org/>

<https://docs.zammad.org/en/latest/install/docker-compose.html>

<https://docs.zammad.org/en/latest/install/docker-compose/environment.html>

<https://docs.zammad.org/en/latest/appendix/configure-env-vars.html>

<https://docs.zammad.org/en/latest/install/docker-compose/docker-compose-scenarios.html>
