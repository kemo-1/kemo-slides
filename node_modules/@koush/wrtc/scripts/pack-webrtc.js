// this script os windows only. needs to be updated for other platforms.

const os = require('os');
const path = require('path');
const fs = require('fs');
const mkdirp = require('mkdirp');
const findit = require('findit2');
const { once } = require('events');
const tar = require('tar');
const rimraf = require('rimraf');

const version = 'v' + require(path.join(__dirname, '../phase-1/package.json')).version;
const platform = os.platform();
const arch = os.arch();

const download = path.join(process.cwd(), '../../download');
const subdirs = ['api', 'rtc_base', 'modules', 'system_wrappers', 'p2p', 'common_video', 'common_audio', 'media', 'logging', 'call', 'pc'];

const stageDir = path.join(process.env.STAGE_DIR, version);
const outDir = path.join(process.env.STAGE_DIR, version + '-out');
mkdirp.sync(stageDir);
rimraf.sync(outDir);

mkdirp.sync(outDir);

fs.copyFileSync(path.join(process.cwd(), 'obj/pc', 'peerconnection.lib'), path.join(outDir, 'peerconnection.lib'));
fs.copyFileSync(path.join(process.cwd(), 'obj', 'webrtc.lib'), path.join(outDir, 'webrtc.lib'));

const subFinder = findit(download);
const subHeaders = [];
subFinder.on('file', file => {
    for (const subdir of subdirs) {
        const p = path.join(download, 'src', subdir);
        if (file.startsWith(p) && file.endsWith('.h')) {
            const header = path.join('webrtc', subdir, file.substring(p.length));
            const f = path.join(outDir, header);
            const d = path.dirname(f);
            mkdirp.sync(d);
            fs.copyFileSync(file, f);
            subHeaders.push(header);
            return;
        }
    }
});
const subPromise = once(subFinder, 'end');

async function findHeaders(dir, subdir) {
    subdir = subdir || '.';
    const finder = findit(dir);
    const headers = [];
    finder.on('file', file => {
        const p = path.join(dir, subdir);
        if (file.startsWith(p) && file.endsWith('.h')) {
            const header = path.join(subdir, file.substring(p.length));
            mkdirp.sync(path.join(outDir, subdir));
            headers.push(header);

            const f = path.join(outDir, header);
            const d = path.dirname(f);
            mkdirp.sync(d);
            fs.copyFileSync(file, f);

            return;
        }
    })

    await once(finder, 'end');
    return headers;
}

const abseilDir = path.join(download, 'src/third_party/abseil-cpp');
const abseilPromise = findHeaders(abseilDir, 'absl');
const libyuvDir = path.join(download, 'src/third_party/libyuv/include');
const libyuvPromise = findHeaders(libyuvDir);


Promise.all([subPromise, abseilPromise, libyuvPromise]).then(([_, abseil, libyuv]) => {
    if (!subHeaders.length)
        throw new Error('no subproject headers?');

    if (!abseil.length)
        throw new Error('no abseil headers?');

    if (!libyuv.length)
        throw new Error('no libyuv headers?');

    const tarpath = path.join(stageDir, `libwebrtc-${platform}-${arch}.tar.gz`);
    tar.c({
        gzip: true,
        cwd: outDir,
        file: tarpath,
    }, ['.']);
});
