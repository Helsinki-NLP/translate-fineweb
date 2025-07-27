#!/usr/bin/env python3

import sys
import gzip

srcfile = sys.argv[1]
trgfile = sys.argv[2]

print('<?xml version="1.0"?>')
print('<!DOCTYPE cesAlign PUBLIC "-//CES//DTD XML cesAlign//EN" "">')
print('<cesAlign version="1.0">')

openDoc = 0
linkID = 0

with gzip.open(srcfile,'rt') as s:
    with gzip.open(trgfile,'rt') as t:
        for srcline in s:
            srcline = srcline.rstrip()
            trgline = t.readline().rstrip()
            if trgline.startswith('DOCUMENT'):
                while not srcline.startswith('DOCUMENT'):
                    srcline = s.readline().rstrip()
            if srcline.startswith('DOCUMENT'):
                while not trgline.startswith('DOCUMENT'):
                    trgline = t.readline().rstrip()
                if openDoc:
                    print('</linkGrp>')
                openDoc = 1
                fromDoc = srcline.split(' ')[1]
                toDoc = trgline.split(' ')[1]
                print(f"<linkGrp targType=\"s\" fromDoc=\"{fromDoc}.gz\" toDoc=\"{toDoc}.gz\">")
            else:
                linkID += 1
                print(f"<link xtargets=\"{srcline};{trgline}\" id=\"{linkID}\" />")
                
if openDoc:
    print('</linkGrp>')
    
print('</cesAlign>')
