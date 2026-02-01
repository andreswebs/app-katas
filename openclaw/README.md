generate tokens:

```sh
openssl rand -hex 32
```

onboard

```sh
mkdir -p .openclaw/workspace

docker run -it --rm \
    --name openclaw-cli \
    --volume "${LOCAL_OPENCLAW_CONFIG_DIR:-/home/openclaw/.openclaw}:/home/openclaw/.openclaw" \
    --volume "${LOCAL_OPENCLAW_WORKSPACE_DIR:-/home/openclaw/.openclaw/workspace}:/home/openclaw/.openclaw/workspace" \
    --env BROWSER=echo \
    docker.io/andreswebs/openclaw onboard
```

ssh tunnel:

```sh
ssh -N -L 18789:127.0.0.1:18789 root@bot
```
