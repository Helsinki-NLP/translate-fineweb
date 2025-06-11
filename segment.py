
import sys, argparse, re, string, signal
from loomchild.segmenter import LoomchildSegmenter

signal.signal(signal.SIGPIPE, signal.SIG_DFL)

parser = argparse.ArgumentParser(description='fetch fineweb data and prepare for translation')
parser.add_argument('-l', '--lang', help='document languages (default=en)', type=str, default='en')
parser.add_argument('-m', '--max-length', help='length threshold in characters (default=1024)', type=int, default=1024)
parser.add_argument('-s', '--segment-into-sentences', help='split documents into sentences', action='store_true')
args = parser.parse_args()

lang = args.lang

## segmenter for splitting into sentences

sentsplit = args.segment_into_sentences
segmenter = LoomchildSegmenter(lang)


## max line length: split into sentences if this limit is exceeded
## (this does nothing when sentence splitting is activated, no cutting or leaving out long sentences!)
max_length = args.max_length


for text in sys.stdin:

    if not text:
        continue
    
    if sentsplit:
        segments = segmenter.get_document_segmentation(text)
    elif len(text) > max_length:
        segments = segmenter.get_document_segmentation(text)
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


# try:

#     for text in sys.stdin:

#         if not text:
#             continue
    
#         if sentsplit:
#             try:
#                 segments = segmenter.get_document_segmentation(text)
#             except:
#                 segments = [text]
#         elif len(text) > max_length:
#             try:
#                 segments = segmenter.get_document_segmentation(text)
#             except:
#                 segments = [text]
#         else:
#             segments = text.splitlines()

#             # print("\n".join(segments))
#             for s in segments:
#                 try: 
#                     if len(s) > max_length:
#                         # p=re.findall('[^\s][^.?,;:]+.?', s)
#                         p=re.findall('[^\s][^'+ string.punctuation +']+.?', s)
#                         print("\n".join(p))
#                     else:
#                         print(s)
#                 except BrokenPipeError:
#                     sys.exit(0)

# except KeyboardInterrupt:
#     sys.exit(0)
# except BrokenPipeError:
#     sys.exit(0)
