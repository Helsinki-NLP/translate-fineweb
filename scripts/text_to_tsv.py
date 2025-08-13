import argparse
import gzip
import re
import json
import csv
import string
import sys

parser = argparse.ArgumentParser(description='merge translated documents back into jsonl')
parser.add_argument('-j', '--jsonl-file', help='original file in jsonl', type=str,
                    default='/scratch/project_462000963/datasets/HuggingFaceFW/fineweb-edu/350BT/fineweb-edu_350BT_00000.jsonl.gz')
parser.add_argument('-s', '--source-language-file', help='source language file', type=str,
                    default='/users/tiedeman/research/translate-fineweb/fineweb-edu/350BT/txt/fineweb-edu_350BT_00000.txt.gz')
parser.add_argument('-t', '--target-language-file', help='target language file', type=str,
                    default='/users/tiedeman/research/translate-fineweb/fineweb-edu/350BT/eng-deu/opusTCv20210807+bt-2021-12-08/fineweb-edu_350BT_00000.txt.gz')
parser.add_argument('-l', '--lang', help='language ID (default=en)', type=str, default='en')
args = parser.parse_args()

lang = args.lang
tsv_output = csv.writer(sys.stdout, delimiter='\t')


with gzip.open(args.jsonl_file,'rt', encoding='utf-8', errors='replace') as j:
    with gzip.open(args.source_language_file,'rt', encoding='utf-8', errors='replace') as s:
        with gzip.open(args.target_language_file,'rt', encoding='utf-8', errors='replace') as t:

            for line in j:
                document = json.loads(line)
                translations = []
                
                # doc = document['text']
                doc = re.sub("([A-Za-z,;])\n([a-z])", r"\1 \2", document['text'])
                for text in doc.splitlines():
                    text = text.strip()
                    if not text:
                        continue

                    source_text = s.readline().rstrip()

                    try:
                        target_text = t.readline().rstrip()
                    except:
                        print(f"problems reading from source/target", file=sys.stderr)

                    ## remove whitespace characters when matching strings
                    textstr = re.sub(r"\s+", "", text, flags=re.UNICODE)
                    source_textstr = re.sub(r"\s+", "", source_text, flags=re.UNICODE)

                    while textstr.startswith(source_textstr):
                        if source_textstr != textstr:

                            ## read the next line and make the same string manipulation as before
                            source_line = s.readline().rstrip()
                            source_linestr = re.sub(r"\s+", "", source_line, flags=re.UNICODE)
                                
                            source_text += ' ' + source_line
                            source_textstr += source_linestr
                                
                            try:
                                target_text += ' ' + t.readline().rstrip()
                            except:
                                print(f"problems reading from source/target", file=sys.stderr)
                        else:
                            translations.append(target_text)
                            break

                    if source_textstr != textstr:
                        print(f"strings don't match!", file=sys.stderr)
                        print(f"{source_text} != {text}", file=sys.stderr)
                        print(f"{source_textstr} != {textstr}", file=sys.stderr)
                            
                if not source_text.endswith('END_OF_DOCUMENT'):
                    source_text = s.readline().rstrip()
                    try:
                        target_text = t.readline().rstrip()
                    except:
                        print(f"problems reading from source/target", file=sys.stderr)

                if source_text != 'END_OF_DOCUMENT':
                    print("strange - this should be the end of the document", file=sys.stderr)
                    print(f"Text to be matched: {text}", file=sys.stderr)
                    print(f"Last line read: {source_text}", file=sys.stderr)
                    while source_text != 'END_OF_DOCUMENT':
                        source_text = s.readline().rstrip()
                        try:
                            target_text = t.readline().rstrip()
                        except:
                            print(f"problems reading from source/target", file=sys.stderr)
                        # document['translation'] = "\n".join(translations)
                        # print(document)
                        
                document['translation'] = "\n".join(translations)
                document['language'] = lang
                
                tsv_output.writerow([document['text'].replace("\n",'<br/>'),document['translation'].replace("\n",'<br/>')])

                    
