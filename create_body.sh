#!/bin/bash
IMAGE_PATH="$1"
OUTPUT_BODY="body.txt"
FILENAME=$(basename "$IMAGE_PATH")
BOUNDARY="boundary"
[ -f "$IMAGE_PATH" ] || exit 1
{
  echo "--$BOUNDARY"
  echo "Content-Disposition: form-data; name=\"image\"; filename=\"$FILENAME\""
  echo "Content-Type: image/jpeg"
  echo
  cat "$IMAGE_PATH"
  echo
  echo "--$BOUNDARY--"
} > "$OUTPUT_BODY"
