FROM golang:1.20-alpine AS builder
WORKDIR /src
COPY . .
RUN go build -o /bff-app

FROM alpine:3.18
COPY --from=builder /bff-app /bff-app
EXPOSE 8080
ENTRYPOINT ["/bff-app"]
