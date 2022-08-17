FROM alpine:3.16.0

ENV GOMPLATE_VERSION=3.10.0-r8 \
  DUMBINIT_VERSION=1.2.5-r1 \
  KEEPALIVED_VERSION=2.2.7-r1
ARG TARGETARCH

# Install keepalived
RUN apk add --no-cache file ca-certificates bash coreutils curl net-tools jq keepalived=${KEEPALIVED_VERSION} dumb-init=${DUMBINIT_VERSION} gomplate=${GOMPLATE_VERSION} \
  && rm -f /etc/keepalived/keepalived.conf \
  && addgroup -S keepalived_script && adduser -D -S -G keepalived_script keepalived_script

COPY keepalived.conf.tmpl /etc/keepalived/keepalived.conf.tmpl
COPY vrrp_check.sh /opt/bin/vrrp_check.sh

ENTRYPOINT ["/bin/dumb-init", "--", \
            "/bin/gomplate", "-f", "/etc/keepalived/keepalived.conf.tmpl", "-o", "/etc/keepalived/keepalived.conf", "--" \
]

CMD [ "/usr/sbin/keepalived", "-l", "-n", "-f", "/etc/keepalived/keepalived.conf" ]
