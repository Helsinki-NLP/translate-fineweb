import argparse
import gzip
import re
import json
import string
import sys

from langcodes import *
from  xml.sax.saxutils import quoteattr, escape
from zipfile import ZipFile, ZIP_DEFLATED

from loomchild.segmenter import LoomchildSegmenter


parser = argparse.ArgumentParser(description='merge translated documents back into jsonl')
parser.add_argument('-j', '--jsonl-file', help='original file in jsonl', type=str,
                    default='/scratch/project_462000963/datasets/HuggingFaceFW/fineweb-edu/350BT/fineweb-edu_350BT_00000.jsonl.gz')
parser.add_argument('-s', '--source-language-file', help='source language file', type=str,
                    default='/users/tiedeman/research/translate-fineweb/fineweb-edu/350BT/txt/fineweb-edu_350BT_00000.txt.gz')
parser.add_argument('-t', '--target-language-file', help='target language file', type=str,
                    default='/users/tiedeman/research/translate-fineweb/fineweb-edu/350BT/eng-deu/opusTCv20210807+bt-2021-12-08/fineweb-edu_350BT_00000.txt.gz')
parser.add_argument('-l', '--lang', help='language ID (default=de)', type=str, default='de')
parser.add_argument('-o', '--output-file', help='output zip-file of all XML documents (default=output.zip', type=str, default='output.zip')
parser.add_argument('-c', '--corpus', help='name of corpus (default=fineweb-edu)', type=str, default='fineweb-edu')
parser.add_argument('-d', '--base-dir', help='base-dir in output zip file (default=350BT/00000)', type=str, default='350BT/00000')
args = parser.parse_args()

lang = args.lang
langid = standardize_tag(lang)

segmenter = LoomchildSegmenter(lang)

docnr = 0
basedir = args.base_dir
corpus = args.corpus

## required directory structure for OPUS:

doczipdir = corpus + '/raw/' + langid + '/' + basedir
docalgdir = langid + '/' + basedir


with gzip.open(args.jsonl_file,'rt', encoding='utf-8', errors='replace') as j:
    with gzip.open(args.source_language_file,'rt', encoding='utf-8', errors='replace') as s:
        with gzip.open(args.target_language_file,'rt', encoding='utf-8', errors='replace') as t:

            with ZipFile(args.output_file, 'w', compression=ZIP_DEFLATED, compresslevel=6) as o:

                for line in j:
                    document = json.loads(line)
                    translations = []
                
                    # doc = document['text']
                    doc = re.sub("([A-Za-z,;])\n([a-z])", r"\1 \2", document['text'])
                    docnr += 1
                    docpath = doczipdir + '/' + str(docnr) + '.xml'
                    docalgpath = docalgdir + '/' + str(docnr) + '.xml'
                    print(f"DOCUMENT {docalgpath}")
                    
                    sentid = 0
                
                    for text in doc.splitlines():
                        text = text.strip()
                        if not text:
                            continue

                        source_text = s.readline().rstrip()

                        try:
                            target_text = t.readline().rstrip()
                        except:
                            target_text = ''
                            print(f"problems reading from target file (1)", file=sys.stderr)

                        ## remove whitespace characters when matching strings
                        textstr = re.sub(r"\s+", "", text, flags=re.UNICODE)
                        source_textstr = re.sub(r"\s+", "", source_text, flags=re.UNICODE)

                        ## sentence split and XMLify
                        ## TODO: use a proper XML generation library

                        try:
                            segments = segmenter.get_segmentation(target_text)
                        except:
                            segments = [target_text]
                            
                        target_sents = []
                        target_sent_ids = []
                        for sent in segments:
                            sentid += 1
                            # xmlstr = sent.replace('&','&amp;').replace('>','&gt;').replace('<','&lt;')
                            xmlstr = escape(sent)
                            target_sents.append(f"<s id=\"{sentid}\">{xmlstr}</s>")
                            target_sent_ids.append(str(sentid))
                        print(' '.join(target_sent_ids))
                    
                    
                        while textstr.startswith(source_textstr):
                            if source_textstr != textstr:

                                ## read the next line and make the same string manipulation as before
                                source_line = s.readline().rstrip()
                                source_linestr = re.sub(r"\s+", "", source_line, flags=re.UNICODE)
                                
                                source_text += ' ' + source_line
                                source_textstr += source_linestr
                                
                                try:
                                    # target_text += ' ' + t.readline().rstrip()
                                    target_text = t.readline().rstrip()
                                    try:
                                        segments = segmenter.get_segmentation(target_text)
                                    except:
                                        segments = [target_text]
                                        
                                    target_sent_ids = []
                                    for sent in segments:
                                        sentid += 1
                                        # xmlstr = sent.replace('&','&amp;').replace('>','&gt;').replace('<','&lt;')
                                        xmlstr = escape(sent)
                                        target_sents.append(f"<s id=\"{sentid}\">{xmlstr}</s>")
                                        target_sent_ids.append(str(sentid))
                                    print(' '.join(target_sent_ids))

                                except:
                                    target_text = ''
                                    print("")
                                    print(f"problems reading from target file (2)", file=sys.stderr)
                            else:
                                translations.append(' '.join(target_sents))
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
                            target_text = ''
                            print("")
                            print(f"problems reading from target file (3)", file=sys.stderr)

                    if source_text != 'END_OF_DOCUMENT':
                        print("strange - this should be the end of the document", file=sys.stderr)
                        print(f"Text to be matched: {text}", file=sys.stderr)
                        print(f"Last line read: {source_text}", file=sys.stderr)
                        while source_text != 'END_OF_DOCUMENT':
                            source_text = s.readline().rstrip()
                            try:
                                target_text = t.readline().rstrip()
                            except:
                                target_text = ''
                                print(f"problems reading from target file (4)", file=sys.stderr)
                            # document['translation'] = "\n".join(translations)
                            # print(document)

                    if 'id' in document:
                        docid = document['id']
                    else:
                        docid = f"{basedir}/{docnr}"
                        
                    attr = ['id=%s' % quoteattr(docid)]
                    if 'metadata' in document:
                        for key, value in document['metadata'].items():
                            attr.append('%s=%s' % (key,quoteattr(str(value))))
                        
                    docstr = '<?xml version="1.0"?>'
                    # docstr += f"\n<doc id=\"{docid}\""
                    attrstr = ' '.join(attr)
                    docstr += f"\n<doc {attrstr}>\n"
                    # docstr += ">\n"
                    docstr += "\n".join(translations)
                    docstr += "\n</doc>"
                    o.writestr(docpath, docstr)
                    
                    # print('<doc url=%s>' % xml.sax.saxutils.quoteattr(document['metadata']['url']))
                    # print("\n".join(translations))
                    # print('</doc>')
                    
            o.close()
