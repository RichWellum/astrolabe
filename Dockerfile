FROM ubuntu:latest

# Verbosity levels (false, v, vv)
ENV VERBOSE "false"
ENV PRETTY "true"
ENV LOW_DATA "false"

ADD astrolabe.sh /app/
ADD disk_use_daemonset.yml /app/

RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    curl \
    ca-certificates \
    boxes \
    bc \
    less \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install kubectl from Docker Hub.
# COPY --from=lachlanevenson/k8s-kubectl:v1.20.1 /usr/local/bin/kubectl /usr/local/bin/kubectl
RUN curl -LO https://storage.googleapis.com/kubernetes-release/release/`curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt`/bin/linux/amd64/kubectl; chmod +x ./kubectl; mv ./kubectl /usr/local/bin/kubectl

# Installing Krew and associated tools
RUN curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/latest/download/krew.{tar.gz,yaml}" && \
    tar zxvf krew.tar.gz && \
    KREW=./krew-"$(uname | tr '[:upper:]' '[:lower:]')_amd64" && \
    "$KREW" install --manifest=krew.yaml --archive=krew.tar.gz && \
    "$KREW" install view-utilization && \
    "$KREW" install view-allocations && \
    "$KREW" install resource-capacity && \
    "$KREW" install sick-pods && \
    "$KREW" install popeye && \
    "$KREW" install resource-snapshot && \
    "$KREW" install df-pv && \
    "$KREW" install node-shell && \
    "$KREW" install debug-shell && \
    "$KREW" install cost && \
    "$KREW" update

# Install helm
RUN curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
RUN chmod 700 get_helm.sh
RUN ./get_helm.sh

# Run Astrolabe
CMD /app/astrolabe.sh ${VERBOSE} ${PRETTY} ${LOW_DATA}
