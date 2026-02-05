# Global arguments
ARG APP_UID=1000
ARG APP_GID=1000

# Bitcoin Core Release Keys as of 4/Sep/2024
# - https://github.com/bitcoin-core/guix.sigs/tree/main/builder-keys
# - https://api.github.com/repos/bitcoin-core/guix.sigs/contents/builder-keys
ARG KEYS="\
  # 0xb10c:
  982A193E3CE0EED535E09023188CBB2648416AD5 \
  # CoinForensics:
  101598DC823C1B5F9A6624ABA5E0907A0380E6C3 \
  # Emzy:
  9EDAFF80E080659604F4A76B2EBB056FD847F8A7 \
  # Sjors:
  ED9BDF7AD6A55E232E84524257FF9BDBCC301009 \
  # TheCharlatan:
  A8FC55F3B04BA3146F3492E79303B33A305224CB \
  # achow101:
  152812300785C96444D3334D17565732E08E5E41 \
  # benthecarman:
  0AD83877C1F0CD1EE9BD660AD7CC770B81FD22A8 \
  # cfields:
  C060A6635913D98A3587D7DB1C2491FFEB0EF770 \
  # darosior:
  590B7292695AFFA5B672CBB2E13FC145CD3F4304 \
  # davidgumberg:
  41E442A14C342C877AE4DC8F3B6305FA06DE51D5 \
  # dunxen:
  948444FCE03B05BA5AB0591EC37B1C1D44C786EE \
  # fanquake:
  E777299FC265DD04793070EB944D35F9AC3DB76A \
  # glozow:
  6B002C6EA3F91B1B0DF0C9BC8F617F1200A6D25C \
  # guggero:
  F4FC70F07310028424EFC20A8E4256593F177720 \
  # hebasto:
  D1DBF2C4B96F2DEBF4C16654410108112E7EA81F \
  # jackielove4u:
  287AE4CA1187C68C08B49CB2D11BD4F33F1DB499 \
  # josibake:
  616516B8EB6ED02882FC4A7A8ADCB558C4F33D65 \
  # kvaciral:
  C388F6961FB972A95678E327F62711DBDCA8AE56 \
  # laanwj:
  71A3B16735405025D447E8F274810B012346C9A6 \
  # luke-jr:
  1A3E761F19D2CC7785C5502EA291A2C45D0C504A \
  # m3dwards:
  E86AE73439625BBEE306AAE6B66D427F873CB1A3 \
  # pinheadmz:
  E61773CD6E01040E2F1BD78CE7E2984B6289C93A \
  # satsie:
  2F78ACF677029767C8736F13747A7AE2FB0FD25B \
  # sipa:
  133EAC179436F14A5CF1B794860FEB804E669320 \
  # svanstaa:
  9ED99C7A355AE46098103E74476E74C8529A9006 \
  # theStack:
  6A8F9C266528E25AEB1D7731C2371D91CB716EA7 \
  # vertiond:
  28E72909F1717FE9607754F8A7BEB2621678D37D \
  # willcl-ark:
  67AA5B46E7AF78053167FE343B8F814A784218F8 \
  # willyko:
  79D00BAC68B56D422F945A8F8E3A8F3247DBCBBF \
  "

FROM ghcr.io/eudaldgr/scratchless AS scratchless

# Build stage
FROM docker.io/alpine AS build
ARG APP_VERSION \
  APP_ROOT \
  TARGETARCH \
  TARGETVARIANT

ARG KEYS

RUN set -ex; \
  apk --no-cache --update add \
  build-base \
  cmake \
  linux-headers \
  pkgconf \
  python3 \
  libevent-dev \
  boost-dev \
  zeromq-dev \
  gnupg \
  wget \
  tar;

RUN set -ex; \
  wget https://bitcoincore.org/bin/bitcoin-core-${APP_VERSION}/bitcoin-${APP_VERSION}.tar.gz \
  https://bitcoincore.org/bin/bitcoin-core-${APP_VERSION}/SHA256SUMS \
  https://bitcoincore.org/bin/bitcoin-core-${APP_VERSION}/SHA256SUMS.asc;

RUN set -ex; \
  gpg --keyserver hkps://keyserver.ubuntu.com --recv-keys $KEYS; \
  gpgconf --kill all; \
  gpg --verify SHA256SUMS.asc 2>&1 >/dev/null | grep "^gpg: Good signature from" || { echo "No valid signature"; exit 1; };

RUN set -ex; \
  [ -f SHA256SUMS ] && cp SHA256SUMS sha256sums || cp SHA256SUMS.asc sha256sums

RUN set -ex; \
  grep "bitcoin-${APP_VERSION}.tar.gz" sha256sums | sha256sum -c

RUN set -ex; \
  tar xzf bitcoin-${APP_VERSION}.tar.gz;

ENV BITCOIN_GENBUILD_NO_GIT=1
RUN set -ex; \
  cd bitcoin-${APP_VERSION}; \
  cmake -S . -B build \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=/usr \
  -DBUILD_BITCOIN_BIN=OFF \
  -DBUILD_DAEMON=ON \
  -DBUILD_GUI=OFF \
  -DBUILD_CLI=OFF \
  -DBUILD_TX=OFF \
  -DBUILD_UTIL=OFF \
  -DBUILD_UTIL_CHAINSTATE=OFF \
  -DBUILD_WALLET_TOOL=OFF \
  -DENABLE_WALLET=OFF \
  -DENABLE_IPC=OFF \
  -DENABLE_EXTERNAL_SIGNER=OFF \
  -DBUILD_TESTS=OFF \
  -DBUILD_GUI_TESTS=OFF \
  -DBUILD_BENCH=OFF \
  -DBUILD_FUZZ_BINARY=OFF \
  -DBUILD_FOR_FUZZING=OFF \
  -DBUILD_KERNEL_LIB=OFF \
  -DWITH_ZMQ=ON \
  -DWITH_USDT=OFF \
  -DWITH_QRENCODE=OFF \
  -DWITH_DBUS=OFF \
  -DREDUCE_EXPORTS=ON \
  -DWERROR=OFF \
  -DWITH_CCACHE=OFF \
  -DINSTALL_MAN=OFF;

RUN set -ex; \
  cd bitcoin-${APP_VERSION}; \
  cmake --build build --target bitcoind -j "$(nproc)";

RUN set -ex; \
  cd bitcoin-${APP_VERSION}; \
  strip build/bin/bitcoind;

COPY --from=scratchless / ${APP_ROOT}/

RUN set -ex; \
  mkdir -p \
  ${APP_ROOT}/bin \
  ${APP_ROOT}/data \
  ${APP_ROOT}/etc \
  ${APP_ROOT}/lib;

RUN set -ex; \
  cd bitcoin-${APP_VERSION}; \
  cp build/bin/bitcoind ${APP_ROOT}/bin/;

RUN set -ex; \
  ldd ${APP_ROOT}/bin/bitcoind | awk '{if (match($3,"/")) print $3}' | xargs -I '{}' cp -v '{}' ${APP_ROOT}/lib/ || true;

RUN set -ex; \
  cp /lib/ld-musl-*.so.1 ${APP_ROOT}/lib/;

# Final scratch image
FROM scratch

ARG TARGETPLATFORM \
  TARGETOS \
  TARGETARCH \
  TARGETVARIANT \
  APP_IMAGE \
  APP_NAME \
  APP_VERSION \
  APP_ROOT \
  APP_UID \
  APP_GID \
  APP_NO_CACHE

ENV APP_IMAGE=${APP_IMAGE} \
  APP_NAME=${APP_NAME} \
  APP_VERSION=${APP_VERSION} \
  APP_ROOT=${APP_ROOT}

COPY --from=build ${APP_ROOT}/ /

ENV HOME=/data
VOLUME /data/.bitcoin

# 8332  Mainnet RPC
# 8333  Mainnet P2P
# 18332 Testnet3 RPC
# 18333 Testnet3 P2P
# 48332 Testnet4 P2P
# 48333 Testnet4 RPC
# 38332 Signet RPC
# 38333 Signet P2P
# 18443 Regtest RPC
# 18444 Regtest P2P
EXPOSE 8332 8333 18332 18333 48332 48333 38332 38333 18443 18444

USER ${APP_UID}:${APP_GID} 
ENTRYPOINT ["/bin/bitcoind"]