FROM ubuntu:22.04

ARG GOST_VERSION
ARG DNS_PROXY_VERSION
ARG TARGETPLATFORM


COPY entrypoint.sh /entrypoint.sh

# install dependencies
RUN case ${TARGETPLATFORM} in \
      "linux/amd64")   export ARCH="amd64" ;; \
      "linux/arm64")   export ARCH="armv8"; export ARCH_DNS="arm64" ;; \
      *) echo "Unsupported TARGETPLATFORM: ${TARGETPLATFORM}" && exit 1 ;; \
    esac && \
    echo "Building for ${ARCH} with GOST ${GOST_VERSION}" &&\
    apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y curl gnupg lsb-release sudo && \
    curl https://pkg.cloudflareclient.com/pubkey.gpg | gpg --yes --dearmor --output /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/cloudflare-client.list && \
    apt-get update && \
    apt-get install -y cloudflare-warp && \
    echo "Install ping (iputils-ping)" && \
    apt-get install -y iputils-ping && \
    echo "Install nslookup (dnsutils)" && \
    apt-get install dnsutils -y && \
    echo "Install traceroute (traceroute)" && \
    apt-get install traceroute && \
    apt-get clean && \
    apt-get autoremove -y && \
    curl -LO https://github.com/ginuerzh/gost/releases/download/v${GOST_VERSION}/gost-linux-${ARCH}-${GOST_VERSION}.gz && \
    gunzip gost-linux-${ARCH}-${GOST_VERSION}.gz && \
    mv gost-linux-${ARCH}-${GOST_VERSION} /usr/bin/gost && \
    chmod +x /usr/bin/gost && \
    echo "Install dnsproxy" && \
    curl -LO https://github.com/AdguardTeam/dnsproxy/releases/download/v${DNS_PROXY_VERSION}/dnsproxy-linux-${ARCH_DNS}-v${DNS_PROXY_VERSION}.tar.gz && \
    tar xzf dnsproxy-linux-${ARCH_DNS}-v${DNS_PROXY_VERSION}.tar.gz --strip=2 && \
    mv dnsproxy /usr/bin/dnsproxy && \
    chmod +x /usr/bin/dnsproxy && \
    chmod +x /entrypoint.sh && \
    useradd -m -s /bin/bash warp && \
    echo "warp ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/warp

USER warp

# Accept Cloudflare WARP TOS
RUN mkdir -p /home/warp/.local/share/warp && \
    echo -n 'yes' > /home/warp/.local/share/warp/accepted-tos.txt

ENV GOST_ARGS="-L :1080"
ENV WARP_SLEEP=2
ENV DNSPROXY_ARGS="-p 5353"

HEALTHCHECK --interval=15s --timeout=5s --start-period=30s --retries=3 \
  CMD curl -fsS "https://cloudflare.com/cdn-cgi/trace" | grep -qE "warp=(plus|on)" || exit 1

ENTRYPOINT ["/entrypoint.sh"]