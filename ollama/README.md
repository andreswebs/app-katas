Examples:

1. Choose a model

```sh
MODEL="phi3.5"
```

```sh
MODEL="nomic-embed-text"
```

(etc.)

2. Pull

```sh
docker exec -it ollama ollama pull "${MODEL}"
```

3. Access

```sh
TXT_PROMPT="What are some important things I should know about the language before I start to learn Chinese?"

JSON_PROMPT='
{
  "model": "'${MODEL}'",
  "prompt": "'${TXT_PROMPT}'",
  "stream": false
}
'
```

```sh
curl --fail --silent localhost:11434/api/generate -d "${JSON_PROMPT}"
```

or for embeddings:

```sh
JSON_PROMPT='
{
  "model": "'${MODEL}'",
  "prompt": "'${TXT_PROMPT}'"
}
'
```

```sh
curl --fail --silent http://localhost:11434/api/embeddings -d "${JSON_PROMPT}"
```
