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

# check file
sub = subprocess.run(['file', fpath], stdout=subprocess.PIPE)
info = str(sub.stdout)
if info.find('%s: HTML ' % fpath) == -1:
    os.remove(fpath)
    print('error: invalid url')
    sys.exit(1)

# analyze file
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
    print(title, flush=True)

# vi: sw=4 ts=4 et
