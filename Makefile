
PWD      := ${shell pwd}
REPOHOME := ${PWD}/
TOOLSDIR := ${REPOHOME}tools

include ${REPOHOME}lib/env.mk
include ${REPOHOME}lib/slurm.mk


# /scratch/project_462000963/datasets/HuggingFaceFW/fineweb-edu/350BT/fineweb-edu_350BT_00100.jsonl.gz


SRC ?= eng
TRG ?= fin

LANGPAIR := ${SRC}-${TRG}


## data source
DATA_SOURCE ?= fineweb-edu-10BT
DATA_SAMPLE ?= sample/10BT


## NR_DOCS = number of documents to be read from fineweb-edu (default=0 (no limit))
## SPLIT_SIZE = number of lines per shard
## PART = shard idenitfier (default = aa)

# NR_DOCS    ?= 50000
NR_DOCS    ?= 0
SPLIT_SIZE ?= 1000000
PART       ?= aa



## maximum input length (number sentence piece segments)
## maximum number of sentences to be translated (top N lines)

MAX_LENGTH    ?= 512
MAX_SENTENCES ?= ${SPLIT_SIZE}



## translation job options for a single GPU

TRANSLATE_JOB_OPTIONS := GPUJOB_HPC_MEM=64g GPUJOB_HPC_CORES=8 NR_GPUS=1 HPC_TIME=24:00 MARIAN_BEAM_SIZE=6
TRANSLATE_JOB_TYPE    := submit


## translation job options for a CPU jobs
## NOTE: beam size is reduced to 1
## NOTE: memory will only be sufficient for transformer-base models

# TRANSLATE_JOB_OPTIONS := HPC_CORES=96 HPC_MEM=232g HPC_TIME=24:00 MARIAN_BEAM_SIZE=1 MARIAN_CPU_DECODER_WORKSPACE=1024
# TRANSLATE_JOB_TYPE    := submitcpu

## reduce number of cores to 32 for transformer-big models:

# HPC_CORES=128 HPC_MEM=232g HPC_TIME=24:00 MARIAN_BEAM_SIZE=1 MARIAN_CPU_DECODER_WORKSPACE=1024
# HPC_CORES=32 HPC_MEM=224g HPC_TIME=24:00 MARIAN_BEAM_SIZE=1



##---------------------------------------------------------------
## get the best OPUS-MT model from the dashboard
##---------------------------------------------------------------

# DASHBOARD_TESTSET := newstest2017
# DASHBOARD_METRIC  := spbleu
DASHBOARD_TESTSET := flores200-devtest
DASHBOARD_METRIC  := bleu
DASHBOARD_URL     := https://opus.nlpl.eu/dashboard/api.php
STORAGE_HOME      := https://object.pouta.csc.fi

best-opusmt-model = $(shell \
	wget -qq -O - '${DASHBOARD_URL}?pkg=opusmt&model=all&test=${3}&scoreslang=${1}-${2}&src=${1}&trg=${2}&metric=${4}' \
	| grep -A1 "scores" | tail -1 | cut -f2 -d\" | sed 's/opusmt\\t//' | sed 's/\\\//\//g')

MODEL     := ${call best-opusmt-model,${SRC},${TRG},${DASHBOARD_TESTSET},${DASHBOARD_METRIC}}
MODELZIP  := ${STORAGE_HOME}/${MODEL}.zip
MODELINFO := ${MODELZIP:.zip=.yml}
MODELNAME := ${patsubst %.zip,%,${notdir ${MODELZIP}}}
MODELTYPE := $(word 3,$(subst /, ,${MODELZIP}))
MODELLANG := $(word 4,$(subst /, ,${MODELZIP}))


MULTI_TARGET_MODEL := ${shell wget -qq -O - ${MODELINFO} | grep 'use-target-labels' | wc -l}
ifneq (${MULTI_TARGET_MODEL},0)
  TARGET_LANG_LABEL := ${shell wget -qq -O - ${MODELINFO} | grep -o '>>${TRG}.*<<'}
endif




DATA_DIR     = ${PWD}/fineweb
LANGID       = ${SRC}
OUTPUT_DIR   = ${LANGPAIR}
DATA_TXT     = ${DATA_DIR}/${LANGID}/${DATA_SOURCE}.${PART}.gz
DATA_SRC     = ${OUTPUT_DIR}/${DATA_SOURCE}.${PART}_${MODELNAME}.${LANGPAIR}.${SRC}.gz
DATA_PRE     = ${OUTPUT_DIR}/${DATA_SOURCE}.${PART}_${MODELNAME}.${LANGPAIR}.${SRC}.spm.gz
DATA_TRG     = ${OUTPUT_DIR}/${DATA_SOURCE}.${PART}_${MODELNAME}.${LANGPAIR}.${TRG}.gz

DATA_LATEST_SRC    = ${OUTPUT_DIR}/latest/${DATA_SOURCE}.${PART}.${LANGPAIR}.${SRC}.gz
DATA_LATEST_TRG    = ${OUTPUT_DIR}/latest/${DATA_SOURCE}.${PART}.${LANGPAIR}.${TRG}.gz
DATA_LATEST_README = ${OUTPUT_DIR}/latest/README.md

## list of all shards
PARTS = ${sort ${patsubst ${DATA_DIR}/${LANGID}/${DATA_SOURCE}.%.gz,%,\
		${wildcard ${DATA_DIR}/${LANGID}/${DATA_SOURCE}.??.gz}}}


## targets for all data shards

ALLDATAPARTS_TXT = ${patsubst %,${DATA_DIR}/${LANGID}/${DATA_SOURCE}.%.gz,${PARTS}}
ALLDATAPARTS_SRC = ${patsubst %,${OUTPUT_DIR}/${DATA_SOURCE}.%_${MODELNAME}.${LANGPAIR}.${SRC}.gz,${PARTS}}
ALLDATAPARTS_PRE = ${patsubst %,${OUTPUT_DIR}/${DATA_SOURCE}.%_${MODELNAME}.${LANGPAIR}.${SRC}.spm.gz,${PARTS}}
ALLDATAPARTS_TRG = ${patsubst %,${OUTPUT_DIR}/${DATA_SOURCE}.%_${MODELNAME}.${LANGPAIR}.${TRG}.gz,${PARTS}}

ALLDATAPARTS_LATEST_SRC = ${patsubst %,${OUTPUT_DIR}/latest/${DATA_SOURCE}.%.${LANGPAIR}.${SRC}.gz,${PARTS}}
ALLDATAPARTS_LATEST_TRG = ${patsubst %,${OUTPUT_DIR}/latest/${DATA_SOURCE}.%.${LANGPAIR}.${TRG}.gz,${PARTS}}




## don't delete translated text if the process crashes
.PRECIOUS: ${DATA_TRG} ${ALLDATAPARTS_TRG} ${ALLDATAS_TRG}


ifdef LOCAL_SCRATCH
  TMPDIR = ${LOCAL_SCRATCH}
endif


.PHONY: all translate-job translate-jobs
all: translate

.PHONY: translate-job
translate-job: prepare
	${MAKE} ${TRANSLATE_JOB_OPTIONS} translate.${TRANSLATE_JOB_TYPE}


## create jobs for translating all shards
## (only start the job if the translation file does not exist yet)

TRANSLATE_ALL_JOBS = $(patsubst %,%-translate-job,${PARTS})

.PHONY: translate-jobs
translate-jobs: ${TRANSLATE_ALL_JOBS}

.PHONY: ${TRANSLATE_ALL_JOBS}
${TRANSLATE_ALL_JOBS}:
	if [ ! -e ${OUTPUT_DIR}/${DATA_SOURCE}.$(@:-translate-job=)_${MODELNAME}.${LANGPAIR}.${TRG}.gz ]; then \
	  ${MAKE} PART=$(@:-translate-job=) translate-job; \
	fi



.PHONY: print-modelinfo
print-modelinfo:
	@echo ${MODELTYPE}
	@echo ${MODELNAME}
	@echo ${MODELZIP}
	@echo ${MODELINFO}
	@echo "multi-target model: ${MULTI_TARGET_MODEL}"
	@echo "target language label: ${TARGET_LANG_LABEL}"






#---------------------------------------------------------------
# release data 
#---------------------------------------------------------------

release-all: upload-all
	${MAKE} released-data.txt released-data-size.txt

.PHONY: upload release
release upload: ${DATA_LATEST_README}
	swift upload ${BT_CONTAINER} --changed --skip-identical ${LANGPAIR}/latest
	${MAKE} released-data.txt
	swift post ${BT_CONTAINER} --read-acl ".r:*"

.PHONY: upload-all
upload-all:
	for d in `find . -maxdepth 1 -type d -name '*-*' -printf "%f "`; do \
	  s=`echo $$d | cut -f1 -d'-'`; \
	  t=`echo $$d | cut -f2 -d'-'`; \
	  make SRC=$$s TRG=$$t ${@:-all=}; \
	done

released-data.txt: .
	swift list ${BT_CONTAINER} | grep -v README.md | grep -v '.txt' > $@
	swift upload ${BT_CONTAINER} $@

TODAY := $(shell date +%F)

released-data-size.txt: .
	swift download ${BT_CONTAINER} released-data-size.txt
	mv $@ $@.${TODAY}
	head -n-1 $@.${TODAY} | grep [a-z] > $@.old
	${MAKE} check-latest-all           > $@.new
	cat $@.old $@.new | grep '^[1-9]' | sort -k2,2  > $@
	cat $@ | awk '{ sum += $$1 } END { print sum }' > $@.tmp
	cat $@.tmp >> $@
	swift upload ${BT_CONTAINER} $@
	swift upload ${BT_CONTAINER} $@.${TODAY}
	rm -f $@.tmp $@.${TODAY} $@.new $@.old

# download released data

.PHONY: download
download: ${DATA_DIR}/${SRC}


#---------------------------------------------------------------
# store / fetch translations
# (this is for storing work files and not for releasing data!)
#---------------------------------------------------------------

.PHONY: store
store:
	a-put -b ${BT_WORK_CONTAINER} --nc --follow-links --override ${LANGPAIR}

.PHONY: store-all
store-all:
	for d in `find . -maxdepth 1 -type d -name '*-*' -printf "%f "`; do \
	  s=`echo $$d | cut -f1 -d'-'`; \
	  t=`echo $$d | cut -f2 -d'-'`; \
	  make SRC=$$s TRG=$$t ${@:-all=}; \
	done

.PHONY: retrieve fetch
retrieve fetch:
	cd ${WORK_DESTDIR} && a-get ${WORK_CONTAINER}/${LANGPAIR}.tar






.PHONY: prepare
prepare: ${LANGPAIR}/${MODELNAME}/decoder.yml ${DATA_TXT}

.PHONY: prepare-allwikis
prepare-allwikis: ${LANGPAIR}/${MODELNAME}/decoder.yml ${ALLDATAS_TXT}


## translate one part
.PHONY: translate
translate: ${DATA_LATEST_README} ${DATA_LATEST_TRG}
ifneq (${DATA_LATEST_SRC},)
	${MAKE} ${DATA_LATEST_SRC}
endif

## translate all parts
.PHONY: translate-all
translate-all: ${ALLDATAPARTS_LATEST_TRG}
ifneq (${ALLDATAPARTS_LATEST_SRC},)
	${MAKE} latest-all-source-parts
endif

## create all source language files
.PHONY: latest-all-source
latest-all-source: ${ALLDATAPARTS_LATEST_SRC}




## fetch the latest model

# https://data.statmt.org/hplt-models/translate/v1.0/${MODELLANG}/hplt_opus/model.npz.best-chrf.npz
# https://data.statmt.org/hplt-models/translate/v1.0/${MODELLANG}/hplt_opus/model.${MODELLANG}.spm

${LANGPAIR}/${MODELNAME}/decoder.yml:
ifneq (${MODELZIP},)
ifeq (${MODELTYPE},HPLT-MT-models)
	mkdir -p ${dir $@}
	wget -O ${dir $@}/model.npz https://huggingface.co/HPLT/translate-${MODELLANG}-v1.0-hplt/resolve/main/model.npz.best-chrf.npz?download=true
	wget -O ${dir $@}/model.spm https://huggingface.co/HPLT/translate-${MODELLANG}-v1.0-hplt/resolve/main/model.${MODELLANG}.spm?download=true
	@echo 'relative-paths: true'     > $@
	@echo 'models:'                 >> $@
	@echo '  - model.npz'           >> $@
	@echo 'vocabs:'                 >> $@
	@echo '  - model.spm'           >> $@
	@echo '  - model.spm'           >> $@
	@echo 'beam-size: 6'            >> $@
	@echo 'max-length: 512'         >> $@
	@echo 'max-length-factor: 3'    >> $@
	@echo 'max-length-crop: true'   >> $@
	@echo 'quiet: true'             >> $@
	@echo 'quiet-translation: true' >> $@
	@echo 'mini-batch: 128'         >> $@
	@echo 'maxi-batch: 5'           >> $@
	@echo 'maxi-batch-sort: "src"'  >> $@
else
	mkdir -p ${dir $@}
	wget -O ${dir $@}/model.zip ${MODELZIP}
	cd ${dir $@} && unzip model.zip
	rm -f ${dir $@}/model.zip
	mv ${dir $@}/preprocess.sh ${dir $@}/preprocess-old.sh
	cat ${dir $@}/preprocess-old.sh |\
	sed 's#perl -C -pe.*$$#perl -C -pe  "s/(?!\\n)\\p{C}/ /g;" |#' |\
	sed 's/$${SPMENCODE}/spm_encode/' > ${dir $@}/preprocess.sh
	chmod +x ${dir $@}/preprocess.sh
endif
endif


## pre-process data

ifeq (${MULTI_TARGET_MODEL},1)
  PREPROCESS_ARGS = ${SRC} ${TRG} ${LANGPAIR}/${MODELNAME}/source.spm
else
  PREPROCESS_ARGS = ${SRC} ${LANGPAIR}/${MODELNAME}/source.spm
endif



${DATA_DIR}/${SRC}/${DATA_SOURCE}.${PART}.gz: ${DATA_DIR}/${SRC}/${DATA_SOURCE}.txt.gz
	${GZCAT} $< | split -l ${SPLIT_SIZE} - $(@:${PART}.gz=)
	${GZIP} -f $(@:${PART}.gz=)??


# fetch the data
${DATA_DIR}/${SRC}/${DATA_SOURCE}.txt.gz:
	mkdir -p $(dir $@)
	python prepare_data.py -l ${NR_DOCS} -d $(@:.txt.gz=.docs.gz) -c ${DATA_SAMPLE} | gzip -c > $@



## OPUS-MT models require pre- and post-processing

ifneq (${MODELTYPE},HPLT-MT-models)
  PRE_PROCESS  := ${LANGPAIR}/${MODELNAME}/preprocess.sh ${PREPROCESS_ARGS} |
  POST_PROCESS := sed 's/ //g;s/▁/ /g' | sed 's/^ *//;s/ *$$//' |
endif



# ${OUTPUT_DIR}/%.${PART}_${MODELNAME}.${LANGPAIR}.${SRC}.spm.gz: ${DATA_DIR}/${SRC}/%.${PART}.gz
${OUTPUT_DIR}/%_${MODELNAME}.${LANGPAIR}.${SRC}.spm.gz: ${DATA_DIR}/${SRC}/%.gz
ifneq (${MODELZIP},)
	mkdir -p ${dir $@}
	${MAKE} ${LANGPAIR}/${MODELNAME}/decoder.yml
	${GZCAT} $< |\
	grep -v '[<>{}]' | ${PRE_PROCESS}\
	perl -e 'while (<>){next if (split(/\s+/)>${MAX_LENGTH});print;}' |\
	gzip -f > $@
endif



## merge SentencePiece segments in the source text
## (Why? because we filter out some data from the original wiki text, see above)

# ${DATA_SRC}: ${DATA_PRE}
${OUTPUT_DIR}/${DATA_SOURCE}.%.${LANGPAIR}.${SRC}.gz: ${OUTPUT_DIR}/${DATA_SOURCE}.%.${LANGPAIR}.${SRC}.spm.gz
ifneq (${MODELZIP},)
	mkdir -p ${dir $@}
	${GZCAT} $< | ${POST_PROCESS} \
	sed 's/^>>[a-z]*<< //' |\
	gzip -c > $@
endif




## overwrite the file with the latest translations
## --> this allows multiple translation iterations
##     without duplicating the data we want to use in MT training

${OUTPUT_DIR}/latest/${DATA_SOURCE}.%.${LANGPAIR}.${SRC}.gz: ${OUTPUT_DIR}/${DATA_SOURCE}.%_${MODELNAME}.${LANGPAIR}.${SRC}.gz
	mkdir -p ${dir $@}
	cp $< $@

${OUTPUT_DIR}/latest/${DATA_SOURCE}.%.${LANGPAIR}.${TRG}.gz: ${OUTPUT_DIR}/${DATA_SOURCE}.%_${MODELNAME}.${LANGPAIR}.${TRG}.gz
	mkdir -p ${dir $@}
	cp $< $@

${DATA_LATEST_README}:
	mkdir -p ${dir $@}
	@echo "${MODELZIP}" >$@




## translate

%.${LANGPAIR}.${TRG}.gz: %.${LANGPAIR}.${SRC}.spm.gz
ifneq (${MODELZIP},)
	mkdir -p ${dir $@}
	${MAKE} ${LANGPAIR}/${MODELNAME}/decoder.yml
	${LOAD_ENV} && cd ${LANGPAIR}/${MODELNAME} && ${MARIAN_DECODER} \
		-i ${PWD}/$< \
		-c decoder.yml \
		-d ${MARIAN_GPUS} \
		${MARIAN_DECODER_FLAGS} |\
	${POST_PROCESS} gzip -c > ${PWD}/$@
endif


check-latest:
	@if [ -d ${LANGPAIR}/latest ]; then \
	  for S in `ls ${LANGPAIR}/latest/*.${SRC}.gz`; do \
	    T=`echo $$S | sed 's/.${SRC}.gz/.${TRG}.gz/'`; \
	    a=`${GZCAT} $$S | wc -l`; \
	    b=`${GZCAT} $$T | wc -l`; \
	    if [ $$a != $$b ]; then \
	      echo "$$a != $$b	$$S	$$T"; \
	    else \
	      echo "$$a	$$S	$$T"; \
	    fi \
	  done \
	fi

check-translated:
	@for S in `ls ${LANGPAIR}/*.${SRC}.gz`; do \
	    T=`echo $$S | sed 's/.${SRC}.gz/.${TRG}.gz/'`; \
	    a=`${GZCAT} $$S | wc -l`; \
	    b=`${GZCAT} $$T | wc -l`; \
	    if [ $$a != $$b ]; then \
	      echo "$$a != $$b	$$S	$$T"; \
	    else \
	      echo "$$a	$$S	$$T"; \
	    fi \
	done

check-length:
	@echo "check ${LANGPAIR}"
	@${MAKE} check-translated
	@${MAKE} check-latest


remove-%-all check-%-all:
	for d in `find . -maxdepth 1 -type d -name '*-*' -printf "%f "`; do \
	  s=`echo $$d | cut -f1 -d'-'`; \
	  t=`echo $$d | cut -f2 -d'-'`; \
	  make SRC=$$s TRG=$$t ${@:-all=}; \
	done



remove-incomplete:
	${MAKE} remove-incomplete-translated
	${MAKE} remove-incomplete-latest

remove-incomplete-translated:
	@echo "check ${LANGPAIR}"
	@mkdir -p ${LANGPAIR}/incomplete
	@for S in `ls ${LANGPAIR}/*.${SRC}.gz`; do \
	    T=`echo $$S | sed 's/.${SRC}.gz/.${TRG}.gz/'`; \
	    a=`${GZCAT} $$S | wc -l`; \
	    b=`${GZCAT} $$T | wc -l`; \
	    if [ $$a != $$b ]; then \
	      echo "$$a != $$b	$$S	$$T"; \
	      mv $$S ${LANGPAIR}/incomplete/; \
	      mv $$T ${LANGPAIR}/incomplete/; \
	    fi \
	done


remove-incomplete-latest:
	@echo "check ${LANGPAIR}"
	@mkdir -p ${LANGPAIR}/incomplete/latest
	@if [ -d ${LANGPAIR}/latest ]; then \
	  for S in `ls ${LANGPAIR}/latest/*.${SRC}.gz`; do \
	    T=`echo $$S | sed 's/.${SRC}.gz/.${TRG}.gz/'`; \
	    a=`${GZCAT} $$S | wc -l`; \
	    b=`${GZCAT} $$T | wc -l`; \
	    if [ $$a != $$b ]; then \
	      echo "$$a != $$b	$$S	$$T"; \
	      mv $$S ${LANGPAIR}/incomplete/latest/; \
	      mv $$T ${LANGPAIR}/incomplete/latest/; \
	    fi \
	  done \
	fi

