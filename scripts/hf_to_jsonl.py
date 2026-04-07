
import argparse

parser = argparse.ArgumentParser(description='convert HF dataset to jsonl')
parser.add_argument('-d', '--dataset', help='HF dataset', type=str, default="MultiSynt/Nemotron-CC-sample-2")
parser.add_argument('-s', '--shards', help='number of output shards', type=int, default=500)
parser.add_argument('-o', '--output', help='output file in jsonl', type=str, default='HF/maxidl/nemotron-cc-english-run2/nemotron-cc-english-run2-train-')
args = parser.parse_args()

from datasets import load_dataset

# dataset = load_dataset(args.dataset, split='train', streaming=True)
# dataset = load_dataset(args.dataset, split='train')

dataset_dict = load_dataset(args.dataset)
num_shards = args.shards

for split, dataset in dataset_dict.items():
    for i in range(num_shards):
        shard = dataset.shard(num_shards=num_shards, index=i)
        shard.to_json(f"{args.output}{split}-{i:05d}.jsonl.gz",orient="records",lines=True,compression="gzip")
#        shard.to_json(f"{args.output}{split}-{i:05d}.jsonl")

