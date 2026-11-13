# syntax=docker/dockerfile:1

FROM golang:1.22-alpine AS builder
WORKDIR /src

COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o /out/prodifolio ./cmd/server

FROM gcr.io/distroless/static-debian12:nonroot
WORKDIR /app

COPY --from=builder /out/prodifolio /app/prodifolio

EXPOSE 8080
USER nonroot:nonroot
ENTRYPOINT ["/app/prodifolio"]
