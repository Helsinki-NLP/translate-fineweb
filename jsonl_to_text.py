

import argparse
import gzip
import re
import json
import string

from loomchild.segmenter import LoomchildSegmenter
# from mosestokenizer import MosesSentenceSplitter


parser = argparse.ArgumentParser(description='fetch fineweb data and prepare for translation')
parser.add_argument('-i', '--input-file', help='input-file', type=str, default='fineweb-edu_350BT_00001.jsonl.gz')
parser.add_argument('-l', '--lang', help='document languages (default=en)', type=str, default='en')
parser.add_argument('-m', '--max-length', help='length threshold in characters (default=1024)', type=int, default=1024)
parser.add_argument('-s', '--segment-into-sentences', help='split documents into sentences', action='store_true')
args = parser.parse_args()

lang = args.lang

## segmenter for splitting into sentences

sentsplit = args.segment_into_sentences
segmenter = LoomchildSegmenter(lang)
# moses_segmenter = MosesSentenceSplitter(lang)


## max line length: split into sentences if this limit is exceeded
## (this does nothing when sentence splitting is activated, no cutting or leaving out long sentences!)
max_length = args.max_length

with gzip.open(args.input_file,'rt') as i:
    for line in i:
        document = json.loads(line)
        if document['metadata']['language'] == lang:

            # text = document['text']
            
            ## a little trick to remove some newlines in the middle of a sentence
            ## TODO: does this break things more than it actually helps?
            text = re.sub("([A-Za-z,;])\n([a-z])", r"\1 \2", document['text'])
            if len(text) > max_length:
                text = document['text']
            
            if sentsplit:
                segments = segmenter.get_document_segmentation(text)
                # segments = moses_segmenter(document.text)
            elif len(text) > max_length:
                segments = segmenter.get_document_segmentation(text)
                # segments = moses_segmenter(document.text)            
            else:
                segments = text.splitlines()

            # print("\n".join(segments))
            for s in segments:
                if len(s) > max_length:
                    # p=re.findall('[^\s][^.?,;:]+.?', s)
                    p=re.findall('[^\s][^'+ string.punctuation +']+.?', s)
                    print("\n".join(p))
                else:
                    print(s)
                    
            print("END_OF_DOCUMENT")
