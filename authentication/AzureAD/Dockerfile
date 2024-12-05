FROM alpine

RUN set -e; \
  apk update; \
  apk upgrade; \
  apk add bash curl jq; \
  apk cache purge; \
  set +e
