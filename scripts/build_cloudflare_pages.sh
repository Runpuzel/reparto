#!/usr/bin/env bash
set -euo pipefail

FLUTTER_DIR="${FLUTTER_DIR:-${PWD}/.flutter-sdk}"
FLUTTER_CHANNEL="${FLUTTER_CHANNEL:-stable}"

if [ ! -x "${FLUTTER_DIR}/bin/flutter" ]; then
  git clone \
    --branch "${FLUTTER_CHANNEL}" \
    --depth 1 \
    --single-branch \
    https://github.com/flutter/flutter.git \
    "${FLUTTER_DIR}"
fi

export PATH="${FLUTTER_DIR}/bin:${PATH}"
export FLUTTER_SUPPRESS_ANALYTICS=true

flutter config --no-analytics
flutter --version
flutter pub get
flutter build web --release

test -f build/web/index.html
