FROM alpine:3.12.0

ENV ENTRYKIT_VERSION=0.4.0 \
    ENTRYKIT_BASEURL=https://github.com/progrium/entrykit/releases/download

RUN apk add --no-cache ca-certificates bash coreutils curl net-tools jq keepalived \
  && rm -f /etc/keepalived/keepalived.conf \
  && addgroup -S keepalived_script && adduser -D -S -G keepalived_script keepalived_script

RUN curl -sL ${ENTRYKIT_BASEURL}/v${ENTRYKIT_VERSION}/entrykit_${ENTRYKIT_VERSION}_Linux_x86_64.tgz | tar zx \
  && mv entrykit /bin/entrykit \
  && chmod +x /bin/entrykit \
  && entrykit --symlink
  
COPY keepalived.conf.tmpl /etc/keepalived/keepalived.conf.tmpl
COPY vrrp_check.sh /opt/bin/vrrp_check.sh

ENTRYPOINT [ \
  "render", "/etc/keepalived/keepalived.conf", "--", \
  "switch", \
    "shell=/bin/sh", \
    "debug=/usr/sbin/keepalived -l -D -n -f /etc/keepalived/keepalived.conf", "--", \
  "/usr/sbin/keepalived", "-l", "-n", "-f", "/etc/keepalived/keepalived.conf" ]
