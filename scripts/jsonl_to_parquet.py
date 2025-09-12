
import argparse
import json
import pandas as pd
from pathlib import Path


parser = argparse.ArgumentParser(description='convert jsonl to parquet')
parser.add_argument('-i', '--jsonl-file', help='input file in jsonl format', type=str)
parser.add_argument('-o', '--parquet-file', help='output file in parquet format', type=str)
args = parser.parse_args()

source=Path(args.jsonl_file)
target=Path(args.parquet_file)

with pd.read_json(source,lines=True, chunksize=10000) as reader:
    for chunk in reader:
        if not target.exists():
            chunk.to_parquet(target, engine='fastparquet', compression='zstd')
        else:
            chunk.to_parquet(target,
                             engine='fastparquet',
                             compression='zstd',
                             append=True)                    
