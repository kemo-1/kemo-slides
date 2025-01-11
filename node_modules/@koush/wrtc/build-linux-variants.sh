cd $(dirname $0)
./clean.sh
npm run build
npm run node-pre-gyp-package
./clean.sh
TARGET_ARCH=arm npm run build
TARGET_ARCH=arm npm run node-pre-gyp-package-arch
./clean.sh
TARGET_ARCH=arm64 npm run build
TARGET_ARCH=arm64 npm run node-pre-gyp-package-arch
