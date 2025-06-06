

import argparse
import gzip
import re

from datatrove.pipeline.readers import ParquetReader
from loomchild.segmenter import LoomchildSegmenter
# from mosestokenizer import MosesSentenceSplitter


parser = argparse.ArgumentParser(description='fetch fineweb data and prepare for translation')
parser.add_argument('-d', '--document-file', help='filename for writing original documents (default=fineweb.txt.gz)', type=str, default='fineweb.txt.gz')
parser.add_argument('-l', '--limit', help='reader limit (default=100)', type=int, default=100)
parser.add_argument('-L', '--lang', help='document languages (default=en)', type=str, default='en')
parser.add_argument('-m', '--max-length', help='length threshold in characters (default=1000)', type=int, default=1000)
parser.add_argument('-s', '--segment-into-sentences', help='split documents into sentences', action='store_true')
parser.add_argument('-c', '--corpus-selection', help='corpus selection, e.g. sample/100BT or CC-MAIN-2024-10 (default=all)', type=str, default='all')
args = parser.parse_args()


lang = args.lang

## segmenter for splitting into sentences

sentsplit = args.segment_into_sentences
segmenter = LoomchildSegmenter(lang)
# moses_segmenter = MosesSentenceSplitter(lang)


# "limit" determines how many documents will be streamed (remove for all)

if args.corpus_selection != 'all':
    if args.limit:
        data_reader = ParquetReader(f"hf://datasets/HuggingFaceFW/fineweb-edu/{args.corpus_selection}", limit=args.limit)
    else:
        data_reader = ParquetReader(f"hf://datasets/HuggingFaceFW/fineweb-edu/{args.corpus_selection}")
elif args.limit:
    data_reader = ParquetReader("hf://datasets/HuggingFaceFW/fineweb-edu", glob_pattern="data/*/*.parquet", limit=args.limit)
else:
    data_reader = ParquetReader("hf://datasets/HuggingFaceFW/fineweb-edu", glob_pattern="data/*/*.parquet")



## max line length: split into sentences if this limit is exceeded
## (this does nothing when sentence splitting is activated, no cutting or leaving out long sentences!)
max_length = args.max_length

docprint = 0
if args.document_file:
    df = gzip.open(args.document_file,'wt')
    docprint = 1

for document in data_reader():
    if document.metadata['language'] == lang:

        if docprint:
            print(document, file=df)

        ## a little trick to remove some newlines in the middle of a sentence
        ## TODO: does this break things more than it actually helps?
        text = re.sub("([A-Za-z,;])\n([a-z])", r"\1 \2", document.text)
        # text = document.text
            
        if sentsplit:
            segments = segmenter.get_document_segmentation(text)
            # segments = moses_segmenter(document.text)
        elif len(text) > max_length:
            segments = segmenter.get_document_segmentation(text)
            # segments = moses_segmenter(document.text)            
        else:
            segments = text.splitlines()
            
        print("\n".join(segments))        
        print("END_OF_DOCUMENT")
