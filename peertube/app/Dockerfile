FROM chocobozzz/peertube:production-bullseye

ARG LOCAL_UID=2000
ARG LOCAL_GID=2000

USER root

RUN \
    usermod --uid "${LOCAL_UID}" peertube && \
    groupmod --gid "${LOCAL_GID}" peertube && \
    chown -R peertube:peertube /home/peertube && \
    chown -R peertube:peertube /app && \
    chown -R peertube:peertube /data && \
    chown -R peertube:peertube /config

USER peertube

# https://github.com/Chocobozzz/PeerTube/blob/master/support/docker/production/Dockerfile.bullseye
