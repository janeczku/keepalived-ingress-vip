FROM alpine:3.12.0

ENV GOMPLATE_VERSION=v3.7.0 \
    GOMPLATE_BASEURL=https://github.com/hairyhenderson/gomplate/releases/download \
    DUMBINIT_VERSION=v1.2.2 \
    DUMBINIT_BASEURL=https://github.com/Yelp/dumb-init/releases/download/ \
    KEEPALIVED_VERSION=2.0.20-r0   
ARG TARGETARCH

# Install keepalived
RUN apk add --no-cache file ca-certificates bash coreutils curl net-tools jq keepalived=${KEEPALIVED_VERSION} \
  && rm -f /etc/keepalived/keepalived.conf \
  && addgroup -S keepalived_script && adduser -D -S -G keepalived_script keepalived_script

# Install gomplate
RUN curl -sL ${GOMPLATE_BASEURL}/${GOMPLATE_VERSION}/gomplate_linux-${TARGETARCH} --output /bin/gomplate \
  && chmod +x /bin/gomplate

# Install dumb-init
RUN curl -sL ${DUMBINIT_BASEURL}/${DUMBINIT_VERSION}/dumb-init_1.2.2_${TARGETARCH} --output /bin/dumb-init \
  && chmod +x /bin/dumb-init

COPY keepalived.conf.tmpl /etc/keepalived/keepalived.conf.tmpl
COPY vrrp_check.sh /opt/bin/vrrp_check.sh

ENTRYPOINT ["/bin/dumb-init", "--", \
            "/bin/gomplate", "-f", "/etc/keepalived/keepalived.conf.tmpl", "-o", "/etc/keepalived/keepalived.conf", "--" \
]

CMD [ "/usr/sbin/keepalived", "-l", "-n", "-f", "/etc/keepalived/keepalived.conf" ]
