Example config for `WORDPRESS_CONFIG_EXTRA`:

<https://github.com/docker-library/wordpress/pull/142>

Secrets:

<https://docs.docker.com/compose/use-secrets/>

Volumes:

- Themes go in a subdirectory in `/var/www/html/wp-content/themes/`
- Plugins go in a subdirectory in `/var/www/html/wp-content/plugins/`

PHP extensions:

<https://make.wordpress.org/hosting/handbook/server-environment/#php-extensions>

Salts:

```sh
curl "https://api.wordpress.org/secret-key/1.1/salt/" -sSo salts
```
