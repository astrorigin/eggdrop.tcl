#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os.path
import sys
import tempfile

url = sys.argv[-1]
if not url.startswith('http'):
    print('error: invalid url', end='')
    sys.exit(1)

# download file using wget
fd, fpath = tempfile.mkstemp()
if not os.path.exists(fpath):
    print('error: cant create temp file', end='')
    sys.exit(1)
os.system('wget --timeout=3 -qO %s %s' % (fpath, url))

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
title = root.find('.//title').text_content()

if title:
    print(title, end='')

# vi: sw=4 ts=4 et
