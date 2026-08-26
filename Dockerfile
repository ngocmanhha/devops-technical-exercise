# syntax=docker/dockerfile:1.7

# Build stage
FROM --platform=$BUILDPLATFORM golang:1.25-alpine AS builder

ARG TARGETOS
ARG TARGETARCH

WORKDIR /src

# Copy dependency files first to maximize Docker layer caching.
COPY app/go.mod app/go.sum* ./

RUN go mod download

# Copy application source.
COPY app/ ./

# Run tests before producing the binary.
RUN CGO_ENABLED=0 go test ./...

# Build a static binary for the target platform.
#
# CGO_ENABLED=0:
# - avoids macOS/cgo compatibility issues
# - produces a statically linked binary
# - makes the runtime image independent of libc
#
# TARGETOS / TARGETARCH are automatically supplied by BuildKit.
RUN CGO_ENABLED=0 \
    GOOS=${TARGETOS:-linux} \
    GOARCH=${TARGETARCH} \
    go build \
      -trimpath \
      -ldflags="-s -w" \
      -o /out/greeter \
      .

# Runtime stage
FROM alpine:3.22

# CA certificates are commonly needed by production applications
# making outbound HTTPS requests.
RUN apk add --no-cache ca-certificates \
    && addgroup -S app \
    && adduser -S -G app -u 10001 app

WORKDIR /app

COPY --from=builder --chown=app:app /out/greeter /app/greeter

USER 10001:10001

EXPOSE 8080

ENTRYPOINT ["/app/greeter"]
