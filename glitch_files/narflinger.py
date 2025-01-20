# MIT License
#
# Copyright (c) 2023 wh0
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

import contextlib
import email.parser
import email.policy
import errno
import http.client
import json
import os
import os.path
import struct
import sys
import tempfile
import urllib.parse

get_connections = {}

def get_scheme_host_target(url):
  parts = urllib.parse.urlsplit(url)
  scheme = parts.scheme
  host = parts.netloc
  target = urllib.parse.urlunsplit(parts._replace(scheme='', netloc='', fragment=''))
  return scheme, host, target

def get_ok(url):
  scheme, host, target = get_scheme_host_target(url)
  if scheme != 'https':
    raise Exception('unsupported scheme %r', scheme)
  if host not in get_connections:
    get_connections[host] = http.client.HTTPSConnection(host)
  conn = get_connections[host]
  conn.request('GET', target)
  res = conn.getresponse()
  if 300 <= res.status < 400:
    redir_url = res.headers['Location']
    return get_ok(redir_url)
  if res.status < 200 or res.status >= 400:
    raise Exception('%s status %d not ok' % (url, res.status))
  return res

narinfo_parser = email.parser.BytesHeaderParser(policy=email.policy.strict)

def basename_hash(basename):
  return basename[:32]

def reader_read_limit(r, size):
  return r.read1(size)

def reader_read_exact(r, size):
  piece = r.read1(size)
  piece_len = len(piece)
  if piece_len == size:
    return piece
  remaining = size - piece_len
  pieces = [piece]
  while remaining:
    piece = r.read1(remaining)
    pieces.append(piece)
    remaining -= len(piece)
  return b''.join(pieces)

def reader_skip_exact(r, size):
  remaining = size
  while remaining:
    piece = r.read1(remaining)
    remaining -= len(piece)

def nar_read_int(r):
  b = reader_read_exact(r, 8)
  return struct.unpack('<Q', b)[0]

def nar_skip_padding(r, length):
  modulo = length & 7
  if modulo:
    reader_skip_exact(r, 8 - modulo)

def nar_read_bytes(r):
  length = nar_read_int(r)
  if not length:
    return b''
  b = reader_read_exact(r, length)
  nar_skip_padding(r, length)
  return b

def nar_generate_binary(r):
  length = nar_read_int(r)
  remaining = length
  while remaining:
    piece = reader_read_limit(r, remaining)
    yield piece
    remaining -= len(piece)
  nar_skip_padding(r, length)

def nar_expect_bytes(r, expected):
  b = nar_read_bytes(r)
  if b != expected:
    raise Exception('unexpected %r, expected %r' % (b, expected))

def nar_generate_pair_keys(r):
  nar_expect_bytes(r, b'(')
  while True:
    k = nar_read_bytes(r)
    if k == b')':
      break
    yield k

def nar_unpack_dir_entry(dst, r):
  name = None
  for k in nar_generate_pair_keys(r):
    if k == b'name':
      name = nar_read_bytes(r)
    elif k == b'node':
      nar_unpack_node(os.path.join(dst, str(name, 'utf-8')), r)
    else:
      raise Exception('dir entry unrecognized key %r' % k)

def nar_unpack_node(dst, r):
  type = None
  executable = False
  for k in nar_generate_pair_keys(r):
    if k == b'type':
      type = nar_read_bytes(r)
      if type == b'regular':
        pass
      elif type == b'symlink':
        pass
      elif type == b'directory':
        os.mkdir(dst)
      else:
        raise Exception('unrecognized type %r' % type)
    elif k == b'executable':
      nar_expect_bytes(r, b'')
      executable = True
    elif k == b'contents':
      dst_fd = os.open(dst, os.O_WRONLY | os.O_CREAT, 0o777 if executable else 0o666)
      for b in nar_generate_binary(r):
        os.write(dst_fd, b)
      os.close(dst_fd)
    elif k == b'target':
      target = nar_read_bytes(r)
      os.symlink(target, dst)
    elif k == b'entry':
      nar_unpack_dir_entry(dst, r)
    else:
      raise Exception('node unrecognized key %r' % k)

def nar_unpack(dst, reader):
  nar_expect_bytes(reader, b'nix-archive-1')
  nar_unpack_node(dst, reader)

decompress_empty = b''

class DecompressReader:
  def __init__(self, r, decompressor):
    self.r = r
    self.decompressor = decompressor
  def read1(self, size):
    while self.decompressor.needs_input:
      piece_in = self.r.read1(8192)
      piece = self.decompressor.decompress(piece_in, size)
      if piece:
        return piece
    piece = self.decompressor.decompress(decompress_empty, size)
    return piece
  def finish(self):
    piece_in = self.r.read()
    if not self.decompressor.eof:
      self.decompressor.decompress(piece_in)
  def close(self):
    self.r.close()

class IdentityReader:
  def __init__(self, r):
    self.r = r
  def read1(self, size):
    return self.r.read1(size)
  def finish(self):
    self.r.read()
  def close(self):
    self.r.close()

def cache_get_narinfo(base, hash):
  with get_ok('%s/%s.narinfo' % (base, hash)) as r:
    return narinfo_parser.parse(r)

def cache_file_url(base, narinfo):
  return urllib.parse.urljoin(base + '/', narinfo['URL'])

def cache_get_nar_reader(base, narinfo):
  compression = narinfo.get('Compression', 'none')
  if compression == 'bzip2':
    import bz2
    decompressor = bz2.BZ2Decompressor()
  elif compression == 'xz':
    import lzma
    decompressor = lzma.LZMADecompressor(lzma.FORMAT_XZ)
  elif compression == 'none':
    decompressor = None
  else:
    raise Exception('narinfo unsupported compression %s' % compression)
  file_url = cache_file_url(base, narinfo)

  file_reader = get_ok(file_url)

  if decompressor is None:
    nar_reader = IdentityReader(file_reader)
  else:
    nar_reader = DecompressReader(file_reader, decompressor)

  return nar_reader

installation_encountered_hashes = set()
installation_bin_dir = os.path.join(os.environ['HOME'], '.local', 'bin')

def installation_collect_recursive(store_prefix, base, basename):
  hash = basename_hash(basename)
  if hash in installation_encountered_hashes:
    return
  installation_encountered_hashes.add(hash)
  store_path = os.path.join(store_prefix, basename)
  if os.path.lexists(store_path):
    print(store_path, 'exists', file=sys.stderr, flush=True) # %%%
    return
  narinfo = cache_get_narinfo(base, hash)
  for refs_header in narinfo.get_all('references', ()):
    for ref in refs_header.split():
      yield from installation_collect_recursive(store_prefix, base, ref)
  yield basename, narinfo

def installation_download_one(temp, store_prefix, base, basename, narinfo):
  unpack_dst = os.path.join(temp, basename)
  print('downloading', basename, file=sys.stderr, flush=True) # %%%
  with contextlib.closing(cache_get_nar_reader(base, narinfo)) as nar_reader:
    nar_unpack(unpack_dst, nar_reader)
    nar_reader.finish()
  os.rename(unpack_dst, os.path.join(store_prefix, basename))

def installation_maybe_link(store_prefix, target, link_path):
  existing_target = None
  try:
    existing_target = os.readlink(link_path)
  except FileNotFoundError:
    pass
  except OSError as e:
    if e.errno == errno.EINVAL:
      print('not clobbering non-symlink %s' % link_path, file=sys.stderr, flush=True) # %%%
      return
    else:
      raise
  if existing_target is not None:
    if existing_target == target:
      print('symlink %s -> %s exists' % (link_path, target), file=sys.stderr, flush=True) # %%%
      return
    if not existing_target.startswith(store_prefix):
      print('not clobbering external symlink %s -> %s' % (link_path, existing_target), file=sys.stderr, flush=True) # %%%
      return
    print('deleting old symlink %s -> %s' % (link_path, existing_target), file=sys.stderr, flush=True) # %%%
    os.unlink(link_path)
  print('creating symlink %s -> %s' % (link_path, target), file=sys.stderr, flush=True) # %%%
  os.symlink(target, link_path)

def installation_link_bin(store_prefix, basename):
  bin_dir = os.path.join(store_prefix, basename, 'bin')
  try:
    bin_names = os.listdir(bin_dir)
  except FileNotFoundError:
    return
  for bin_name in bin_names:
    bin_path = os.path.join(bin_dir, bin_name)
    link_path = os.path.join(installation_bin_dir, bin_name)
    installation_maybe_link(store_prefix, bin_path, link_path)

def installation_link(store_prefix, basename):
  installation_link_bin(store_prefix, basename)

def installation_install_closure(temp, store_prefix, base, top_basename):
  for basename, narinfo in installation_collect_recursive(store_prefix, base, top_basename):
    installation_download_one(temp, store_prefix, base, basename, narinfo)
  installation_link(store_prefix, top_basename)

def installation_main(store_prefix, base, basenames):
  os.makedirs(store_prefix, exist_ok=True)
  os.makedirs(installation_bin_dir, exist_ok=True)
  with tempfile.TemporaryDirectory(prefix='install-', dir=store_prefix) as temp:
    for basename in basenames:
      installation_install_closure(temp, store_prefix, base, basename)

print('NAR Flinger 1.2', file=sys.stderr, flush=True)
with open('package.json', 'r') as f:
  package = json.load(f)
if 'narflinger' not in package:
  print('package.json `narflinger` unset', file=sys.stderr, flush=True)
  sys.exit(0)
opts = package['narflinger']
if 'basenames' not in opts:
  print('package.json `narflinger.basenames` unset', file=sys.stderr, flush=True)
  sys.exit(0)
if not opts['basenames']:
  print('package.json `narflinger.basenames` empty', file=sys.stderr, flush=True)
  sys.exit(0)
installation_main(
  opts.get('store_prefix', '/tmp/nix/store'),
  opts.get('base', 'https://cdn.glitch.me/35f4f809-f949-484d-af9c-269b3b7abc78'),
  opts['basenames'],
)
