Start `ollama`:

```sh
export OLLAMA_DIR="${HOME}/.ollama"
```

```sh
docker compose up -d
```

Examples:

1. Choose a model

```sh
# MODEL="phi3.5"
MODEL="deepseek-r1:1.5b"
```

```sh
MODEL="nomic-embed-text"
```

(etc.)

2. Pull

```sh
docker exec --interactive --tty ollama ollama pull "${MODEL}"
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
curl --fail --silent --data "${JSON_PROMPT}" http://localhost:11434/api/generate
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
curl --fail --silent --data "${JSON_PROMPT}" http://localhost:11434/api/embeddings
```
