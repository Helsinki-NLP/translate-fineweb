#!/usr/bin/env python3

import sys

from pathlib import Path
from fastzip.read import RZipStream
from fastzip.write import WZip

files = sys.argv[1:]
output = files.pop(0)

with WZip(Path(output)) as z:
    for f in files:
        for entry in RZipStream(f).entries():
            z.enqueue_precompressed(*entry)
