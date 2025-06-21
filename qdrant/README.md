## Qdrant env vars

> Environment variables follow this format: they should be prefixed with QDRANT\_\_, and nested properties should be separated by double underscores (\_\_).

## Set up certs

### Prerequisites

These only need to be run once:

```sh
brew install mkcert nss
```

```sh
mkcert -install
```

```sh
mkdir "$(pwd)/certs"
```

### New cert

```sh
pushd certs
```

```sh
mkcert localhost 127.0.0.1 ::1
```

## References

<https://medium.com/@fadil.parves/qdrant-self-hosted-28a30106e9dd>

<https://qdrant.tech/documentation/guides/configuration/>
