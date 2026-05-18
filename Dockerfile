FROM alpine:3.23.4

RUN apk update && \
    apk upgrade && \
    apk --no-cache add curl==8.19.0-r0 jq==1.8.1-r0 bash==5.3.3-r1 && \
    rm -rf /var/cache/apk/*

COPY src /

ENTRYPOINT ["/restart_kafka_connectors.sh"]