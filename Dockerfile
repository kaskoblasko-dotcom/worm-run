# Runs the Worm Run game server (headless Godot) on Render.
# If your Godot editor is a different version, change GODOT_VERSION to match.
FROM debian:bookworm-slim

ARG GODOT_VERSION=4.3

RUN apt-get update && apt-get install -y --no-install-recommends \
    wget unzip ca-certificates libfontconfig1 libx11-6 libxcursor1 \
    libxinerama1 libxi6 libxrandr2 libgl1 libasound2 libudev1 \
    && rm -rf /var/lib/apt/lists/*

RUN wget -q "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip" -O /tmp/godot.zip \
    && unzip /tmp/godot.zip -d /tmp \
    && mv "/tmp/Godot_v${GODOT_VERSION}-stable_linux.x86_64" /usr/local/bin/godot \
    && chmod +x /usr/local/bin/godot \
    && rm /tmp/godot.zip

WORKDIR /app
COPY . /app

# Render gives the port in the PORT environment variable; the game reads it.
CMD ["godot", "--headless", "--path", "/app", "--", "--server"]
