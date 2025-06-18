

import sys
import argparse
import gzip
import re
import json

from loomchild.segmenter import LoomchildSegmenter
# from mosestokenizer import MosesSentenceSplitter

import ctranslate2
import sentencepiece as spm


parser = argparse.ArgumentParser(description='translate fineweb-edu')
parser.add_argument('-i', '--input-file', help='input-file', type=str, default='fineweb-edu_350BT_00001.jsonl.gz')
parser.add_argument('-l', '--lang', help='document languages (default=en)', type=str, default='en')
parser.add_argument('-m', '--max-length', help='length threshold in characters (default=1024)', type=int, default=1024)
parser.add_argument('-s', '--segment-into-sentences', help='split documents into sentences', action='store_true')
parser.add_argument('-S', '--sentence-piece-model', help='sentence piece model', type=str)
parser.add_argument('-M', '--model', help='translation model', type=str)
parser.add_argument('-B', '--beam-size', help='beam size (default=4)', type=int, default=4)
parser.add_argument('-D', '--device', help='device to use (default=cpu)', type=str, default='cpu')
parser.add_argument('-W', '--workers', help='number of workers (default=1)', type=int, default=1)
parser.add_argument('-N', '--batch-size', help='batch size (default=64)', type=int, default=64)
parser.add_argument('-X', '--preload-batches', help='number of preloaded batches (default=4)', type=int, default=4)
args = parser.parse_args()

lang = args.lang

## segmenter for splitting into sentences

sentsplit = args.segment_into_sentences
segmenter = LoomchildSegmenter(lang)
# moses_segmenter = MosesSentenceSplitter(lang)

print(f"load sentence piece model {args.sentence_piece_model} ",file=sys.stderr)
sp = spm.SentencePieceProcessor()
sp.load(args.sentence_piece_model)


beam_size = args.beam_size,
batch_size = args.batch_size,


print(f"load translation model {args.model} ",file=sys.stderr)
if args.device == 'cpu':
    translator = ctranslate2.Translator(args.model,
                                        device=args.device,
                                        inter_threads=args.workers,
                                        intra_threads=1)
else:
    device_index = numbers = [x for x in range(args.workers)]
    translator = ctranslate2.Translator(args.model,
                                        device=args.device,
                                        device_index=device_index)


## max line length: split into sentences if this limit is exceeded
## (this does nothing when sentence splitting is activated, no cutting or leaving out long sentences!)
max_length = args.max_length


data = []
data_size = args.workers*args.batch_size*args.preload_batches
print(f"data size to load: {data_size}",file=sys.stderr)

with gzip.open(args.input_file,'rt') as i:
    for line in i:
        document = json.loads(line)
        if document['metadata']['language'] == lang:

            ## a little trick to remove some newlines in the middle of a sentence
            ## TODO: does this break things more than it actually helps?
            text = re.sub("([A-Za-z,;])\n([a-z])", r"\1 \2", document['text'])
            # text = document['text']
            
            if sentsplit:
                segments = segmenter.get_document_segmentation(text)
                # segments = moses_segmenter(document.text)
            elif len(text) > max_length:
                segments = segmenter.get_document_segmentation(text)
                # segments = moses_segmenter(document.text)            
            else:
                segments = text.splitlines()

            for s in segments:
                data.append(sp.encode(s, out_type=str))

            if len(data) > data_size:
                results = translator.translate_batch(data, max_batch_size=batch_size, beam_size=beam_size)
                for r in results:
                    print(sp.decode(r.hypothesis[0]))    
                data = []
            

if len(data):
    results = translator.translate_batch(data, max_batch_size=batch_size, beam_size=beam_size)
    for r in results:
        print(sp.decode(r.hypothesis[0]))
