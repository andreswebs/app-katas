FROM jenkins/jenkins:latest

ARG LOCAL_UID=2000
ARG LOCAL_GID=2000

USER root

RUN \
    usermod --uid "${LOCAL_UID}" jenkins && \
    groupmod --gid "${LOCAL_GID}" jenkins && \
    chown -R jenkins:jenkins "${JENKINS_HOME}" && \
    chown -R jenkins:jenkins /usr/share/jenkins

RUN \
    apt-get update > /dev/null && \
    apt-get install --yes --quiet apt-transport-https ca-certificates gnupg rsync zip unzip && \
    echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" > /etc/apt/sources.list.d/google-cloud-sdk.list && \
    curl https://packages.cloud.google.com/apt/doc/apt-key.gpg > /usr/share/keyrings/cloud.google.gpg && \
    apt-get update > /dev/null && \
    apt-get install --yes --quiet google-cloud-sdk && \
    rm -rf /var/lib/apt/lists/*

USER jenkins
