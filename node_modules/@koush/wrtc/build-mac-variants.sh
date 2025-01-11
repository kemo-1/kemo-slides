cd $(dirname $0)
ARCH=$(arch)
if [ "$ARCH" == "arm64" ]
then
    ./clean.sh
    env /usr/bin/arch -x86_64 /bin/zsh --login -c "npm run build && npm run node-pre-gyp-package"
    ./clean.sh
    npm run build && npm run node-pre-gyp-package
else
    ./clean.sh
    TARGET_ARCH=arm64 npm run build && TARGET_ARCH=arm64 npm run node-pre-gyp-package-arch
    ./clean.sh
    npm run build && npm run node-pre-gyp-package
fi
