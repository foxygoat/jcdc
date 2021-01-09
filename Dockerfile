FROM golang:1.15-alpine AS builder

WORKDIR /src
RUN apk add git make

# Build master of kubecfg for unreleased 32 bit changes
RUN git clone https://github.com/bitnami/kubecfg
RUN make -C kubecfg

ARG COMMIT_SHA
ARG SEMVER
ENV COMMIT_SHA=${COMMIT_SHA}
ENV SEMVER=${SEMVER}

COPY go.mod go.sum Makefile main.go jcdc/
RUN make -C jcdc install

FROM alpine:3.12
WORKDIR /app
COPY --from=builder /src/kubecfg/kubecfg /bin/
COPY --from=builder /go/bin/jcdc .
ENTRYPOINT ["/app/jcdc"]
