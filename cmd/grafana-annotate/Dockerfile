# install build tools
ARG GO_VERSION=1.18

ARG REGISTRY="docker.io/library"

FROM ${REGISTRY}/golang:${GO_VERSION} AS builder

# Run the process as an unprivileged user
RUN mkdir /user && \
    echo 'nobody:x:65534:65534:nobody:/:' > /user/passwd && \
    echo 'nobody:x:65534' > /user/group

WORKDIR /src

# See https://www.docker.com/blog/containerize-your-go-developer-environment-part-2/
# TODO - Figure out how to avoid rebuilding at this step
COPY ./ ./

RUN CGO_ENABLED=0 go build \
    -o /grafana-annotate ./cmd/grafana-annotate

FROM scratch AS final

COPY --from=builder /user/group /user/passwd /etc/
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=builder /grafana-annotate /grafana-annotate

USER nobody:nobody

ENTRYPOINT ["/grafana-annotate"]
