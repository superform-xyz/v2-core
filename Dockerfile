# CONTAINER FOR BUILDING BINARY
FROM golang:1.22 AS build

WORKDIR $GOPATH/src/github.com/superform-xyz/v2-relayer

# INSTALL DEPENDENCIES
COPY go.mod go.sum ./
RUN go mod download

# BUILD BINARY
COPY . .
RUN make build

# CONTAINER FOR RUNNING BINARY
FROM alpine:3.19.0

# This is needed for the docker compose healthcheck
RUN apk add curl

COPY --from=build /go/src/github.com/superform-xyz/v2-relayer/dist/relayer /app/relayer

CMD ["/app/relayer"]
