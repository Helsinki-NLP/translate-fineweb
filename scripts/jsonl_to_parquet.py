
import argparse
import json
import pandas as pd

parser = argparse.ArgumentParser(description='convert jsonl to parquet')
parser.add_argument('-i', '--jsonl-file', help='input file in jsonl format', type=str)
parser.add_argument('-o', '--parquet-file', help='output file in parquet format', type=str)
args = parser.parse_args()

with pd.read_json(args.jsonl_file,lines=True, chunksize=10000) as reader:
    for chunk in reader:
        chunk.to_parquet(args.parquet_file, engine='fastparquet') 
        
