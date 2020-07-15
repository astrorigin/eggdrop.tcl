#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os.path
import sys
import tempfile
import subprocess

url = sys.argv[-1]
if not url.startswith('http'):
    print('error: invalid url')
    sys.exit(1)

# download file using wget
fd, fpath = tempfile.mkstemp(suffix='.urltitle')
if not os.path.exists(fpath):
    print('error: cant create temp file')
    sys.exit(1)
wget = ['wget', '--timeout=3', '--tries=1', '-qO', fpath, url]
try:
    sub = subprocess.run(wget, check=True)
except subprocess.CalledProcessError:
    os.remove(fpath)
    print('error: cant retrieve url')
    sys.exit(1)

# check file type
sub = subprocess.run(['file', fpath], stdout=subprocess.PIPE)
info = str(sub.stdout)
if info.find('%s: gzip compressed data' % fpath) != -1:
    # gzipped html/xml?
    fd, fpath2 = tempfile.mkstemp(suffix='.urltitle')
    os.system('gzip -d -S .urltitle -c %s > %s' (fpath, fpath2))
    sub2 = subprocess.run(['file', fpath2], stdout=subprocess.PIPE)
    info2 = str(sub2.stdout)
    if info2.find('%s: HTML ' % fpath2) != -1 \
            or info2.find('%s: XML ' % fpath2) != -1:
        os.remove(fpath)
        fpath = fpath2
        info = info2
    else:
        os.remove(fpath2)
if info.find('%s: HTML ' % fpath) == -1 \
        and info.find('%s: XML ' % fpath) == -1:
    # not html/xml
    info = sub.stdout.strip().split(b': ')[1]
    sub = subprocess.run(['du', '-h', fpath], stdout=subprocess.PIPE)
    os.remove(fpath)
    info += b', %s' % sub.stdout.split(b'\t')[0]
    print('\x1FFile info:\x1F %s' % info.decode('utf-8'), flush=True)
    sys.exit(0)

# analyze html file
f = open(fpath, 'rb')
data = f.read()
f.close()
os.remove(fpath)

from bs4 import UnicodeDammit
from lxml import html

encoding = UnicodeDammit(data, is_html=True).original_encoding
parser = html.HTMLParser(encoding=encoding)
root = html.document_fromstring(data, parser=parser)

try:
    title = root.xpath(".//meta[@name='title']/@content")[0].strip()
except:
    title = root.find('.//title').text_content().strip()

if title:
    print('\x1FTitle:\x1F %s' % title, flush=True)

# vi: sw=4 ts=4 et
