Check health:

```sh
curl http://localhost:9999/health
```

Signup:

```sh
curl -s -X POST "${AUTH_SERVER_URL}/signup" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "testuser@example.com",
    "password": "Test1234!"
  }' | jq .
```

## References

<https://github.com/supabase/auth>

<https://supabase.com/docs/guides/self-hosting/docker#configuring-and-securing-supabase>

<https://github.com/supabase/supabase/blob/master/docker/README.md>

<https://github.com/supabase/auth/blob/master/example.env>

<https://github.com/supabase/auth/blob/master/example.docker.env>

<https://github.com/Razikus/UNDERBASE/blob/main/docker-compose.yml>

<https://github.com/supabase-community/auth-go>
