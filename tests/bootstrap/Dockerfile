ARG UBUNTU_VERSION=24.04
FROM ubuntu:${UBUNTU_VERSION}

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends \
        openssh-server \
        python3 \
        sudo \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir --parents /run/sshd /root/.ssh \
    && chmod 0700 /root/.ssh

COPY entrypoint.sh /usr/local/bin/bootstrap-test-sshd
RUN chmod 0755 /usr/local/bin/bootstrap-test-sshd

ENTRYPOINT ["/usr/local/bin/bootstrap-test-sshd"]
