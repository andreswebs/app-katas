FROM mariadb:latest

ARG LOCAL_UID=1000
ARG LOCAL_GID=1000

USER root

RUN \
    usermod --uid "${LOCAL_UID}" mysql && \
    groupmod --gid "${LOCAL_GID}" mysql

USER mysql
