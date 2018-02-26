FROM alpine:3.7
RUN apk add --no-cache ca-certificates
COPY bin/linux/amd64/chartmuseum /chartmuseum
ENTRYPOINT ["/chartmuseum"]
