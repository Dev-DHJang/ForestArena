FROM ubuntu:24.04

ARG TARGETARCH
ARG GODOT_VERSION=4.7.1
ARG GODOT_ARM64_SHA512=de64efe4d936ac0403769e078a73d961a9c647cab04168c5fb5a7fe33728e200a67324ed99368eeb27964e205e72a61e48efb63b52d5de34d12dd6a95ca0fc45
ARG GODOT_AMD64_SHA512=4ccdab7a48eeccbe8819a2fc1f6262f8d72065d98601bcb3743fcbd7ebd39f373758a788ee3293a05ec5b2c48538266c437404312e372225cd2df273945a2de9

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      ca-certificates curl unzip netcat-openbsd libfontconfig1 libx11-6 libxcursor1 libxinerama1 libgl1 libasound2t64 libpulse0 && \
    rm -rf /var/lib/apt/lists/* && \
    BUILD_ARCH="${TARGETARCH:-$(dpkg --print-architecture)}" && \
    case "$BUILD_ARCH" in \
      arm64|aarch64) GODOT_ARCH=arm64; GODOT_SHA512="$GODOT_ARM64_SHA512" ;; \
      amd64|x86_64) GODOT_ARCH=x86_64; GODOT_SHA512="$GODOT_AMD64_SHA512" ;; \
      *) echo "unsupported architecture: $BUILD_ARCH" >&2; exit 1 ;; \
    esac && \
    GODOT_ZIP="Godot_v${GODOT_VERSION}-stable_linux.${GODOT_ARCH}.zip" && \
    curl -fsSLO "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/${GODOT_ZIP}" && \
    echo "${GODOT_SHA512}  ${GODOT_ZIP}" | sha512sum -c - && \
    unzip "$GODOT_ZIP" -d /usr/local/bin && \
    mv "/usr/local/bin/Godot_v${GODOT_VERSION}-stable_linux.${GODOT_ARCH}" /usr/local/bin/godot && \
    chmod 0755 /usr/local/bin/godot && rm "$GODOT_ZIP"

RUN useradd --create-home --uid 10001 --shell /usr/sbin/nologin forestarena
WORKDIR /game
COPY --chown=forestarena:forestarena . .
COPY --chown=forestarena:forestarena server/game/project.server.godot /game/project.godot
RUN chown forestarena:forestarena /game
USER forestarena
RUN godot --headless --path /game --editor --quit
EXPOSE 7777
CMD ["godot", "--headless", "--path", "/game", "res://server/game/game_server.tscn"]
