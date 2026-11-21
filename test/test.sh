#!/usr/bin/env bash
# Tries an image out before it is published:
#
#   test/test.sh <image>
#
# 1. The optimizer starts with the tasks file that is in the image. A mistake
#    in config/tasks.yaml (bad YAML, an unknown placeholder) stops it here.
# 2. The tools the bundled tasks call are there.
#
# It needs no Immich and no graphics card, and it does not convert anything:
# whether a task of yours does what you want, you see with a real file.
set -euo pipefail

IMAGE="${1:?usage: test/test.sh <image>}"

echo "== the optimizer and its tasks file"
docker run --rm "$IMAGE" immich-optimizer -version
# Proxy mode needs nothing but an address. It keeps running when the tasks
# file is fine, so being stopped by the timeout (exit 124) is the good result.
set +e
out=$(docker run --rm -e IO_MODE=proxy -e IO_IMMICH_URL=http://127.0.0.1:9 "$IMAGE" timeout 5 immich-optimizer 2>&1)
code=$?
set -e
if [ "$code" != 124 ]; then
  echo "$out"
  echo "the optimizer did not start with the tasks file in the image (exit $code)" >&2
  exit 1
fi

echo "== the tools the tasks call"
docker run --rm --entrypoint sh "$IMAGE" -c '
  for tool in ffmpeg cjxl djxl exiftool magick; do
    command -v "$tool" >/dev/null || { echo "missing: $tool" >&2; exit 1; }
  done'

echo "OK"
