#!/bin/bash
###############################################
# Usage:
#   ./make.gfortran.docset.sh [version]
#
# e.g.
#   ./make.gfortran.docset.sh 5.1.0
###############################################

GFORTRAN_VERSION=$1
: ${GFORTRAN_VERSION:="5.1.0"}
CONTENTS_DIR=gfortran_${GFORTRAN_VERSION}.docset/Contents/
RES_DIR=${CONTENTS_DIR}/Resources/
DOC_DIR=${RES_DIR}/Documents/
HTML_FILE=gfortran-html.${GFORTRAN_VERSION}.tar.gz
FORTRAN_DOC_URL=https://gcc.gnu.org/onlinedocs/gcc-${GFORTRAN_VERSION}/gfortran-html.tar.gz

#
# Download gfortran manual
#
if [ ! -f "$HTML_FILE" ]; then
    echo "Download GNU Fortran $GFORTRAN_VERSION manual"
    wget ${FORTRAN_DOC_URL} -O ${HTML_FILE}
    if [ ! $? ]; then exit 1; fi
fi

#
# Uncompress document file
#
echo "Uncompress document file"
if [ -f "$HTML_FILE" ]; then
    mkdir -p ${DOC_DIR}
    tar xf ${HTML_FILE} -C $DOC_DIR --strip-components=1
else
    echo ${HTML_FILE} NOT exist!
    exit 1
fi

#
# Generate Info.plist file
#
echo "Generate Info.plist file"
tee ${CONTENTS_DIR}/Info.plist >/dev/null <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>gfortran</string>
    <key>CFBundleName</key>
    <string>GNU Fortran ${GFORTRAN_VERSION}</string>
    <key>DocSetPlatformFamily</key>
    <string>gfortran</string>
    <key>isDashDocset</key>
    <true/>
</dict>
</plist>
EOF

#
# Generate index database
#
echo "Generate index database"
python <<EOF
#!/usr/bin/env python

import os
import re
import sqlite3
from bs4 import BeautifulSoup

conn = sqlite3.connect('${RES_DIR}/docSet.dsidx')
cur = conn.cursor()

try:
    cur.execute('DROP TABLE searchIndex;')
except:
    pass

cur.execute('CREATE TABLE searchIndex(id INTEGER PRIMARY KEY, name TEXT, '
            'type TEXT, path TEXT);')
cur.execute('CREATE UNIQUE INDEX anchor ON searchIndex (name, type, path);')

docpath = '${DOC_DIR}'

page = open(os.path.join(docpath, 'index.html')).read()
soup = BeautifulSoup(page, 'lxml')

intrinsic = re.compile('toc_Intrinsic-Procedures')
intrin_procedures = soup.find('a', {'name': intrinsic}).parent.select('li > a')

for tag in intrin_procedures:
    if tag.code:
        name = tag.code.text.strip()
        path = tag.attrs['href'].strip()
        cur.execute('INSERT OR IGNORE INTO searchIndex(name, type, path)'
                    ' VALUES (?,?,?)', (name, 'func', path))
        # print 'name: %s, path: %s' % (name, path)

conn.commit()
conn.close()
EOF
