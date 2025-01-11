#!/bin/bash

version=v$(node -p "require('$(dirname $0)/../phase-1/package.json').version")
platform=$(uname -s | tr '[A-Z]' '[a-z]')
arch=${TARGET_ARCH:-$(uname -m | tr '[A-Z]' '[a-z]')}

asset=libwebrtc-${platform}-${arch}.tar.gz

if [ -e $(dirname $0)/../phase-1/build/stage/${version}/${asset} ]; then
  echo Using asset from phase-1/build/stage/${version}/${asset}
  cp $(dirname $0)/../phase-1/build/stage/${version}/${asset} .
fi

BASE_URL=https://github.com/koush/node-webrtc/releases/download

set -e

set -v

if [ ! -e ${asset} ]; then
  URL=${BASE_URL}/${version}/${asset}

  echo Downloading "${URL}"
  wget "$URL"
fi

echo Unpacking "${asset}"
tar xf "${asset}"
