
import argparse
import sys
import json

parser = argparse.ArgumentParser(description='fetch data from HF')

parser.add_argument('-d', '--dataset', help='HF dataset', type=str, default='spyysalo/nemotron-cc-10K-sample')
parser.add_argument('-s', '--datasplit', help='dataset split (default=train)', type=str, default='train')

args = parser.parse_args()

from datasets import load_dataset
ds = load_dataset(args.dataset, split=args.datasplit, num_proc=16)

for d in ds:
    json.dump(d, sys.stdout,ensure_ascii=False)
    print("")
    # print(d)
