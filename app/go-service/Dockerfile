FROM golang:1.26-alpine AS builder
WORKDIR /src
# copy go.mod first so we can download deps (go.sum may not exist yet)
COPY go.mod ./
# install git for fetching modules and download deps
RUN apk add --no-cache git && go env -w GOPROXY=https://proxy.golang.org,direct && go mod download
# now copy the rest of the source
COPY . .
# static build, optimized
ENV CGO_ENABLED=0
RUN go build -ldflags "-s -w" -o /bff-app

# Minimal runtime using scratch
FROM scratch
COPY --from=builder /bff-app /bff-app
EXPOSE 8080
ENTRYPOINT ["/bff-app"]
