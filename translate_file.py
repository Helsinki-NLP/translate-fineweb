

import sys
import argparse
import ctranslate2
import sentencepiece as spm


parser = argparse.ArgumentParser(description='translate fineweb-edu')
parser.add_argument('-i', '--input-file', help='input-file', type=str, default='fineweb-edu_350BT_00001.txt.gz')
parser.add_argument('-o', '--output-file', help='output-file', type=str, default='fineweb-edu_350BT_00001.translation.gz')
parser.add_argument('-s', '--sentence-piece-model', help='sentence piece model', type=str)
parser.add_argument('-m', '--model', help='translation model', type=str)
parser.add_argument('-b', '--beam-size', help='beam size (default=4)', type=int, default=4)
parser.add_argument('-d', '--device', help='device to use (default=cpu)', type=str, default='cpu')
parser.add_argument('-w', '--workers', help='number of workers (default=1)', type=int, default=1)
parser.add_argument('-n', '--batch-size', help='batch size (default=64)', type=int, default=64)
parser.add_argument('-x', '--preload-batches', help='number of preloaded batches (default=4)', type=int, default=4)
args = parser.parse_args()


print(f"load sentence piece model {args.sentence_piece_model} ",file=sys.stderr)
sp = spm.SentencePieceProcessor()
sp.load(args.sentence_piece_model)


beam_size = args.beam_size
batch_size = args.batch_size


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


translator.translate_file(source_path=args.input_file,
                          output_path=args.output_file,
                          max_batch_size=batch_size,
                          beam_size=beam_size)
