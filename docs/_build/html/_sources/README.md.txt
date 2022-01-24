# Astrolabe

## Intro

This is an application to discover Kubernetes Cluster resource metrics, in
particular memory and disk usage across nodes.

Most available tools focus on memory and cpu, and not the physical/virtual disk
usage.

This tool uses krew kubectl plugins, resource-capacity and df-pv as well as
deploying a daemonset to all nodes that runs commands, the data is then pulled
from the logs and displayed to the user.

- This link provides lots of useful info about pulling resources: <https://github.com/kubernetes/kubernetes/issues/17512>

In verbose mode a number of additional plugins are used to provide more
information.

Effectively this is a docker image that when deployed executes a bash script
`astrolabe.sh` that executes the kubectl plugins, and also deploys a
daemonset to gather the data. `astrolabe.sh` contains logic to wait for the
daemonset to deploy and log, and logic to display the output in a readible
manner.

The output can be scaled to be very high verbosity or the default. The inputs
accepted by Astrolabe and therefore the docker run command are:

- VERBOSE - true/false - turn on and report from every tool (default false)

## Usage

The user needs no access to the source code, just the docker run command below.

The assumption is that the user is running somewhere with access to
./kube/config and the user has ssh access to all the nodes.

### No Verbosity - runs disk and memory daemonset

```bash
sudo docker run \
-it --rm \
--volume ${SSH_AUTH_SOCK}:/ssh-agent --env SSH_AUTH_SOCK=/ssh-agent \
--volume ${HOME}/.ssh/:/root/.ssh \
--volume ${HOME}/.kube/:/root/.kube \
rwellum/astrolabe:latest
```

### Medium Verbosity - runs disk and memory daemonset, metrics server and df-pv

```bash
sudo docker run \
-it --rm \
--volume ${SSH_AUTH_SOCK}:/ssh-agent --env SSH_AUTH_SOCK=/ssh-agent \
--volume ${HOME}/.ssh/:/root/.ssh \
--volume ${HOME}/.kube/:/root/.kube \
-e VERBOSE='v' \
rwellum/astrolabe:latest
```

### High Verbosity - runs every tool

```bash
sudo docker run \
-it --rm \
--volume ${SSH_AUTH_SOCK}:/ssh-agent --env SSH_AUTH_SOCK=/ssh-agent \
--volume ${HOME}/.ssh/:/root/.ssh \
--volume ${HOME}/.kube/:/root/.kube \
-e VERBOSE='vv' \
rwellum/astrolabe:latest
```

### Defaults - Explicit

```bash
sudo docker run \
-it --rm \
--volume ${SSH_AUTH_SOCK}:/ssh-agent --env SSH_AUTH_SOCK=/ssh-agent \
--volume ${HOME}/.ssh/:/root/.ssh \
--volume ${HOME}/.kube/:/root/.kube \
-e DEBUG='false' -e VERBOSE='false' \
rwellum/astrolabe:latest
```

## For the package maintainer

### Building docker image

```bash
sudo docker build -t rwellum/astrolabe:latest .
```

### Pushing docker image

```bash
sudo docker push rwellum/astrolabe:latest
```

### Cleanup, build and push - expensive but saves on tags

```bash
sudo docker system prune -f
sudo docker rmi --force rwellum/astrolabe:latest
sudo docker build -t rwellum/astrolabe:latest . --no-cache
sudo docker push rwellum/astrolabe:latest
```

### Debugging disk-checker

#### Check status of daemonset

```bash
kubectl describe daemonset disk-checker
kubectl get nodes
kubectl get nodes -o json
kubectl get no,ds,po -o json
```

### Sphinx generating docs

This repo uses Sphinx for documentation.

### Generating html

```bash
cd docs
make html
```

Built in: `_build/html`

### Generating pdf

```bash
cd docs
make latexpdf
```

Built in: `_build/latex`
