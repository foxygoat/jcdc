FROM golang:1.15-alpine AS builder

ARG COMMIT_SHA
ARG SEMVER
ENV COMMIT_SHA=${COMMIT_SHA}
ENV SEMVER=${SEMVER}

WORKDIR /src
COPY go.mod go.sum Makefile main.go ./
RUN apk add make
RUN make install

FROM alpine:3.12
WORKDIR /app
COPY --from=builder /go/bin/jcdc .
CMD /app/jcdc
