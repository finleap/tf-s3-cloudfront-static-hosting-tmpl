#!/usr/bin/env bash

set -eu

# This script uploads an artifact of a static files based application.

BUCKET=""
SOURCE_FOLDER=""
NO_DELETE=""
HELP=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    -b) BUCKET="$2"; shift 2;;
    -s) SOURCE_FOLDER="$2"; shift 2;;
    -n) NO_DELETE="true"; shift 1;;
    -h) HELP="true"; shift 1;;

    --bucket=*) BUCKET="${1#*=}"; shift 1;;
    --source-folder=*) SOURCE_FOLDER="${1#*=}"; shift 1;;
    --no-delete) NO_DELETE="true"; shift 1;;
    --help) HELP="true"; shift 1;;
    *) echo "unknown option: $1" >&2; exit 1;;
  esac
done

help () {
  cat <<EOF
Usage: $(basename "$0") -pbsnh [args]

This script uploads an artifact of a static files based application.

Options:
  -b / --bucket=         Target bucket for the release candidate
  -s / --source-folder=  Source folder where the release candidate is located
  -n / --no-delete       Sync files but don't delete files from S3
  -h / --help            Show this help

Example:

  λ $(basename "$0") --bucket=sample-bucket --source-folder=build
EOF
  exit 1
}

if [ "$HELP" == "true" ]
  then
    help
fi

if [ -z "$BUCKET" ]
  then
    echo "missing -b / --bucket" >&2;
    exit 1
fi

if [ -z "$SOURCE_FOLDER" ]
  then
    echo "missing -s / --source-folder" >&2;
    exit 1
fi

BUCKET="s3://${BUCKET}"

HEADER_CACHE_ENABLED="public, max-age=2678400, s-maxage=2678400"
HEADER_CACHE_DISABLED="public, must-revalidate, proxy-revalidate, max-age=0, s-maxage=0, no-store, no-cache"

echo "deploying from ${SOURCE_FOLDER} to ${BUCKET}"

# Copy src to build dir, as we gonna modify files
BUILD_FOLDER=$(mktemp -d)
cp -r "${SOURCE_FOLDER}/." "${BUILD_FOLDER}"

echo 'Gzipping all html, css, js and json files'
find "${BUILD_FOLDER}" \( -iname '*.html' -o -iname '*.css' -o -iname '*.js' -o -iname '*.json' \) -exec gzip -f -9 -n {} \; -exec mv {}.gz {} \;

# Sync files that are supposed to be cached indefinitely, as they have checksum hash in filename
echo 'Uploading css files'
aws s3 sync --exclude '*.*' --include '*.css' --content-type 'text/css' --content-encoding 'gzip' --cache-control "${HEADER_CACHE_ENABLED}" "${BUILD_FOLDER}" "${BUCKET}"
echo 'Uploading js files'
aws s3 sync --exclude '*.*' --include '*.js' --exclude 'service-worker.js' --content-type 'application/javascript' --content-encoding 'gzip' --cache-control "${HEADER_CACHE_ENABLED}" "${BUILD_FOLDER}" "${BUCKET}"
echo 'Uploading images (jpg, png, ico, svg)'
aws s3 sync --exclude '*.*' --include '*.png' --include '*.jpg' --include '*.ico' --include '*.svg' --exclude 'android-chrome*.png' --exclude 'apple-touch-icon.png' --exclude 'favicon*' --exclude 'mstile*' --exclude 'safari-pinned-tab.svg' --cache-control "${HEADER_CACHE_ENABLED}" "${BUILD_FOLDER}" "${BUCKET}"
echo 'Uploading xml files'
aws s3 sync --exclude '*.*' --include '*.xml' --exclude 'browserconfig.xml' --content-type 'application/xml' --cache-control "${HEADER_CACHE_ENABLED}" "${BUILD_FOLDER}" "${BUCKET}"
echo 'Uploading js.map files'
aws s3 sync --exclude '*.*' --include '*.map' --content-type 'application/octet-stream' --content-encoding 'gzip' --cache-control "${HEADER_CACHE_ENABLED}" "${BUILD_FOLDER}" "${BUCKET}"


# Sync files that are not supposed to be cached
echo 'Uploading icon files'
aws s3 sync --exclude '*.*' --include 'android-chrome*.png' --include 'apple-touch-icon.png' --include 'favicon*' --include 'mstile*' --include 'safari-pinned-tab.svg' --cache-control "${HEADER_CACHE_DISABLED}" "${BUILD_FOLDER}" "${BUCKET}"
echo 'Uploading json files'
aws s3 sync --exclude '*.*' --include '*.json' --exclude 'manifest.json' --content-type 'application/json' --content-encoding 'gzip' --cache-control "${HEADER_CACHE_DISABLED}" "${BUILD_FOLDER}" "${BUCKET}"
echo 'Uploading html files'
aws s3 sync --exclude '*.*' --include '*.html' --content-type 'text/html' --content-encoding 'gzip' --cache-control "${HEADER_CACHE_DISABLED}" "${BUILD_FOLDER}" "${BUCKET}"
echo 'Uploading configuration files'
aws s3 sync --exclude '*.*' --include 'browserconfig.xml' --content-type 'application/xml' --cache-control "${HEADER_CACHE_DISABLED}" "${BUILD_FOLDER}" "${BUCKET}"
aws s3 sync --exclude '*.*' --include 'site.webmanifest' --cache-control "${HEADER_CACHE_DISABLED}" "${BUILD_FOLDER}" "${BUCKET}"
aws s3 sync --exclude '*.*' --include 'manifest.json' --content-type 'application/json' --cache-control "${HEADER_CACHE_DISABLED}" "${BUILD_FOLDER}" "${BUCKET}"
aws s3 sync --exclude '*.*' --include 'asset-manifest.json' --content-type 'application/json' --cache-control "${HEADER_CACHE_DISABLED}" "${BUILD_FOLDER}" "${BUCKET}"
echo 'Uploading service worker'
aws s3 sync --exclude '*.*' --include 'service-worker.js' --content-type 'application/javascript' --content-encoding 'gzip' --cache-control "${HEADER_CACHE_DISABLED}" "${BUILD_FOLDER}" "${BUCKET}"

# Sync everything else (Cache: 15 mins)
echo 'Syncing everything else'
SYNC_WITH_DELETE=""
if [ -z "$NO_DELETE" ]
  then
    SYNC_WITH_DELETE="--delete"
fi

aws s3 sync ${SYNC_WITH_DELETE} --cache-control "${HEADER_CACHE_ENABLED}" "${BUILD_FOLDER}" "${BUCKET}"

# Purge old build
rm -rf "${BUILD_FOLDER}"
