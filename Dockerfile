FROM alpine:3.22.0

RUN apk update && \
    apk upgrade && \
    apk --no-cache add curl==8.14.1-r1 jq==1.8.0-r0 bash==5.2.37-r0 && \
    rm -rf /var/cache/apk/*

COPY src /

ENTRYPOINT ["/restart_kafka_connectors.sh"]