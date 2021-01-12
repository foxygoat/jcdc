# JCDC

[![CI/CD](https://github.com/foxygoat/jcdc/workflows/CI/CD/badge.svg?branch=master)](https://github.com/foxygoat/jcdc/actions?query=workflow%3ACI%2FCD+branch%3Amaster)
[![PkgGoDev](https://pkg.go.dev/badge/mod/foxygo.at/jcdc)](https://pkg.go.dev/mod/foxygo.at/jcdc)
[![Slack chat](https://img.shields.io/badge/slack-gophers-795679?logo=slack)](https://gophers.slack.com/messages/foxygoat)

JCDC is a web server providing a webhook for externally triggered
commands, e.g. a deployment triggered by successful GitHub actions
workflow. It is intended to be used with
[kubecfg](https://github.com/bitnami/kubecfg) provided in its image and
Kubernetes deployments.

### Development

- Pre-requisites: [go](https://golang.org), [golangci-lint](https://github.com/golangci/golangci-lint/releases/tag/v1.33.2), GNU make
- Build with `make`
- View build options with `make help`

### Deployment

Kubernetes deployment targets for deploying to clusters created with
[k3sinst](https://github.com/foxygoat/k3sinst) are provided in the
Makefile where LABEL becomes a subdirectory of `deployment/`. Run

    make deploy-LABEL

and follow instructions.

Retrieve the secret API key with

    make show-secret

Test your deployment with

    curl https://<HOSTNAME>/version
    curl https://<HOSTNAME>/run -d '{"apiKey": <SECRET>, "command": "echo hello world" }'
