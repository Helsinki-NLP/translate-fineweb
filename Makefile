
PWD      := ${shell pwd}
REPOHOME := ${PWD}/
TOOLSDIR := ${REPOHOME}tools

include ${REPOHOME}lib/env.mk
include ${REPOHOME}lib/slurm.mk


## project number for allas storage
STORAGE_PROJECT := project_2005815
STORAGE_URL     := https://object.pouta.csc.fi/OELLM-synthetic/

ifdef LOCAL_SCRATCH
  TMPDIR = ${LOCAL_SCRATCH}
endif


## select input and output language
## (SRC needs to be eng for now)

SRC ?= eng
TRG ?= deu

LANGPAIR := ${SRC}-${TRG}


## maximum input length (number sentence piece segments)

MARIAN_MAX_LENGTH := 512


## set to 1 to activate splitting into sentences
## when preparing the data
## otherwise: keep lines and only split long lines

SENTENCE_SPLIT := 0


## select fineweb shards to be used (start and end, starting with 1)

# DATASET     := spyysalo/nemotron-cc-10K-sample
DATASET       := fineweb-edu/350BT
FINEWEB_START := 1
FINEWEB_END   := 50

## data sources (in original jsonl and in plain text for translation)
## (only selected shards)

# FINEWEB_DIR     := /scratch/project_462000963/datasets/HuggingFaceFW/${DATASET}
FINEWEB_DIR     := ${PWD}/HF/${DATASET}
FINEWEB_JSONL   := $(wordlist ${FINEWEB_START},${FINEWEB_END},\
			$(sort $(notdir $(wildcard ${FINEWEB_DIR}/*.gz))))

FINEWEB_TXT_DIR := ${DATASET}/txt
FINEWEB_TXT     := $(sort \
			$(patsubst %.jsonl.gz,${FINEWEB_TXT_DIR}/%.txt.gz,${FINEWEB_JSONL}) \
			$(wildcard ${FINEWEB_TXT_DIR}/*.txt.gz))




## run targets for nemotron10K
## NOTE: sentence splitting is activated!

.PHONY: %_nemotron10K
%_nemotron10K:
	${MAKE} SENTENCE_SPLIT=1 DATASET=spyysalo/nemotron-cc-10K-sample $(@:_nemotron10K=)


OELLM_LANGS = 	deu fin nob nno spa mlt ukr \
		gle glg cat ces swe tur bul \
		lav lit slk nld dan ell est fra \
		hrv hun ita pol por ron \
		slv eus bos isl kat \
		mkd sqi srp_Cyrl

# sqi = als in FLORES200
# lav = lvs in FLORES200 (not on dashboard?)

nemotron10K:
	for l in ${OELLM_LANGS}; do \
	  ${MAKE} TRG=$$l prepare_nemotron10K; \
	done
	for l in ${OELLM_LANGS}; do \
	  ${MAKE} TRG=$$l translate-jobs_nemotron10K; \
	done

nemotron10K-release:
	for l in ${OELLM_LANGS}; do \
	  ${MAKE} TRG=$$l release-data_nemotron10K; \
	done


fineweb-prepare:
	for l in ${OELLM_LANGS}; do \
	  ${MAKE} TRG=$$l prepare-job; \
	done

fineweb-translate:
	for l in ${OELLM_LANGS}; do \
	  ${MAKE} TRG=$$l translate-jobs; \
	done


## new version of text extraction
## (OBSOLETE)

FINEWEB_TEXT_DIR := ${DATASET}/txt

.PHONY: %_newtext
%_newtext:
	${MAKE} FINEWEB_TXT_DIR=${DATASET}/txt $(@:_newtext=)

## old version of text extraction
## (OBSOLETE)

.PHONY: %_oldtext
%_oldtext:
	${MAKE} FINEWEB_TXT_DIR=${DATASET}/${SRC} $(@:_oldtext=)


.PHONY: %_newtext2
%_newtext2:
	${MAKE} FINEWEB_TXT_DIR=${DATASET}/txt2 $(@:_newtext2=)



##---------------------------------------------------------------
## top-level targets
##
## all: run translations for all shards (not very useful)
## prepare: fetch best OPUS-MT model and prepare all input data
## prepare-model: fetch best OPUS-MT model
## prepare-first: fetch best OPUS-MT model and prepare the first data shard
## translate: translate all data shards
## translate-first: translate first shard only
##
## print-modelinfo: print information about the model selected from the dashboard
##---------------------------------------------------------------

.PHONY: all translate-job translate-jobs
all: translate


.PHONY: upload
upload:
	swift upload OELLM-synthetic --changed --skip-identical --use-slo --segment-size 5G ${DATASET}/translated/txt/${TRG}
	swift upload OELLM-synthetic --changed --skip-identical --use-slo --segment-size 5G ${DATASET}/translated/jsonl/${TRG}
	mkdir -p data
	swift list OELLM-synthetic --prefix ${DATASET}/translated/ \
	| sed 's#^#* ${STORAGE_URL}#' > data/$(subst /,-,${DATASET}).md
	grep -v '${DATASET}' README.md | awk -v RS='\n\n\n' 1  > README.new
	echo ""                                               >> README.new
	echo "## release files for ${DATASET}"                >> README.new
	echo ""                                               >> README.new
	for f in `find ${DATASET}/translated -name 'README.md' | sort`; do \
	  echo "* [$$f]($$f)"                                 >> README.new; \
	done
	mv README.md README.$(shell date +%F)
	mv README.new README.md
	git add data/$(subst /,-,${DATASET}).md
	find ${DATASET}/translated -name '*.md' | xargs git add


#	grep -v '${FINEWEB_TRANS_RELEASE_INFO}' README.md                        > README.new
#	echo '* [${FINEWEB_TRANS_RELEASE_INFO}](${FINEWEB_TRANS_RELEASE_INFO})' >> README.new
#	mv README.md README.$(shell date +%F)
#	mv README.new README.md



##---------------------------------------------------------------
## submit SLURM jobs
##
## prepare-job: submit SLURM job to prepare all data shards
## translate-job: submit a slurm job for the first shard
## translate-jobs: submit slurm jobs for all shard
## translate-job-NR: submit slurm job for shard number NR (replace with number)
##---------------------------------------------------------------

.PHONY: prepare-job
prepare-job: prepare-model 
	${MAKE} HPC_MEM=64g HPC_CORES=32 prepare.submitcpu

prepare-job-%:
	${MAKE} HPC_CORES=1 HPC_MEM=4g HPC_TIME=2:00 \
		$(patsubst prepare-job-%,%-prepare,$@).submitcpu


.PHONY: translate-job
translate-job: prepare-first
	${MAKE} ${TRANSLATE_JOB_OPTIONS} translate-first.${TRANSLATE_JOB_TYPE}

.PHONY: translate-job-%
translate-job-%:
	${MAKE} ${TRANSLATE_JOB_OPTIONS} $(patsubst translate-job-%,%-translate,$@).${TRANSLATE_JOB_TYPE}

translate-jobtest:
	${MAKE} GPUJOB_HPC_MEM=64g GPUJOB_HPC_CORES=4 NR_GPUS=1 HPC_TIME=30 HPC_GPUQUEUE=dev-g translate-first.${TRANSLATE_JOB_TYPE}

translate-jobtest4:
	${MAKE} GPUJOB_HPC_MEM=64g GPUJOB_HPC_CORES=8 NR_GPUS=4 MARIAN_GPUS='0 1 2 3' HPC_TIME=30 HPC_GPUQUEUE=dev-g translate-first.${TRANSLATE_JOB_TYPE}


.PHONY: release-job
release-job:
	${MAKE} HPC_MEM=64g HPC_CORES=32 release-data.submitcpu





## find incomplete translation files
## and create input file for translating them

.PHONY: find-missing-translations
find-missing-translations:
	${MAKE} $(patsubst %,%-check-length,$(shell seq $(words ${FINEWEB_TRANS})))

## translate missing translation lines and merge with existing ones

.PHONY: translate-missing-jobs
translate-missing-jobs:
	for t in ${FINEWEB_MISSING_TRANS}; do \
	  if [ ! -e $$t ]; then \
	    ${MAKE} MARIAN_MINI_BATCH=32 ${TRANSLATE_JOB_OPTIONS} $$t.${TRANSLATE_JOB_TYPE}; \
	  fi \
	done



## translate with quantized model

.PHONY: translate-int8-job
translate-int8-job: prepare-first
	${MAKE} ${TRANSLATE_JOB_OPTIONS} translate-int8-first.${TRANSLATE_JOB_TYPE}

.PHONY: translate-int8-job-%
translate-int8-job-%:
	${MAKE} ${TRANSLATE_JOB_OPTIONS} \
		$(patsubst translate-int8-job-%,%-translate-int8,$@).${TRANSLATE_JOB_TYPE}

.PHONY: translate-int8-cpujob-%
translate-int8-cpujob-%:
	${MAKE} ${TRANSLATE_CPUJOB_OPTIONS} \
		$(patsubst translate-int8-cpujob-%,%-translate-int8,$@).submitcpu



## translate with ctranslate2

.PHONY: ct2-job
ct2-job: prepare-model convert-model
	${MAKE} ${CT2_JOB_OPTIONS} ct2-first.${CT2_JOB_TYPE}

.PHONY: ct2-jobs
ct2-jobs: ${FINEWEB_CT2_JOBS}

.PHONY: ct2-job-%
ct2-job-%:
	${MAKE} ${CT2_JOB_OPTIONS} $(patsubst ct2-job-%,%-ct2,$@).${CT2_JOB_TYPE}


##---------------------------------------------------------------
## get the best OPUS-MT model from the dashboard
##---------------------------------------------------------------

# DASHBOARD_TESTSET := newstest2017
# DASHBOARD_METRIC  := spbleu
DASHBOARD_TESTSET := flores200-devtest
DASHBOARD_METRIC  := bleu
DASHBOARD_URL     := https://opus.nlpl.eu/dashboard/api.php
STORAGE_HOME      := https://object.pouta.csc.fi

ifeq (${TRG},lav)
  DASHBOARD_TESTSET := flores101-devtest
endif

ifeq (${TRG},sqi)
  DASHBOARD_TESTSET := ntrex128
endif


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
#  TARGET_LANG_LABEL := ${shell wget -qq -O - ${MODELINFO} | grep -o '>>${TRG}.*<<'}
  TARGET_LANG_LABEL := '>>${TRG}<<'
endif


.PHONY: print-modelinfo
print-modelinfo:
	@echo ${MARIAN_HOME}
	@echo ${MODELTYPE}
	@echo ${MODELNAME}
	@echo ${MODELZIP}
	@echo ${MODELINFO}
	@echo "multi-target model: ${MULTI_TARGET_MODEL}"
	@echo "target language label: ${TARGET_LANG_LABEL}"



## translation targets (using marian-decoder)

FINEWEB_TRANS_DIR  := ${DATASET}/${LANGPAIR}/${MODELNAME}
FINEWEB_INPUT      := $(patsubst ${FINEWEB_TXT_DIR}/%.txt.gz,${FINEWEB_TRANS_DIR}/%.input.gz,${FINEWEB_TXT})
FINEWEB_TRANS      := $(patsubst ${FINEWEB_TXT_DIR}/%,${FINEWEB_TRANS_DIR}/%,${FINEWEB_TXT})

FINEWEB_INPUT_JOBS := $(addsuffix -job,${FINEWEB_INPUT})
FINEWEB_TRANS_JOBS := $(addsuffix -job,${FINEWEB_TRANS})


## in case of broken translation jobs: missing translations are created here

FINEWEB_MISSING_DIR   := ${DATASET}/missing/${LANGPAIR}/${MODELNAME}
FINEWEB_MISSING_INPUT := $(wildcard ${FINEWEB_MISSING_DIR}/*.input.gz)
FINEWEB_MISSING_TRANS := $(patsubst %.input.gz,%.translated.gz,$(FINEWEB_MISSING_INPUT))


## release data (which is parallel and completely translated

FINEWEB_TRANS_RELEASE_DIR  := ${DATASET}/translated
FINEWEB_TRANS_RELEASE_SRC  := $(patsubst ${FINEWEB_TXT_DIR}/%,${FINEWEB_TRANS_RELEASE_DIR}/txt/${SRC}/%,${FINEWEB_TXT})
FINEWEB_TRANS_RELEASE_TRG  := $(patsubst ${FINEWEB_TRANS_DIR}/%,${FINEWEB_TRANS_RELEASE_DIR}/txt/${TRG}/%,${FINEWEB_TRANS})
FINEWEB_TRANS_RELEASE_JSON := $(patsubst ${FINEWEB_TRANS_DIR}/%.txt.gz,${FINEWEB_TRANS_RELEASE_DIR}/jsonl/${TRG}/%.jsonl.gz,${FINEWEB_TRANS})
FINEWEB_TRANS_RELEASE_PARQUET := $(patsubst %.jsonl.gz,%.parquet,${FINEWEB_TRANS_RELEASE_JSON})
FINEWEB_TRANS_RELEASE_EXAMPLE := $(patsubst %.txt.gz,%.md,${FINEWEB_TRANS_RELEASE_TRG})
FINEWEB_TRANS_RELEASE_INFO := ${FINEWEB_TRANS_RELEASE_DIR}/txt/${TRG}/README.md


## translation targets for quantized models

FINEWEB_INT8       := $(patsubst ${FINEWEB_TXT_DIR}/%.txt.gz,${FINEWEB_TRANS_DIR}/%.int8.gz,${FINEWEB_TXT})
FINEWEB_INT8_JOBS  := $(addsuffix -job,${FINEWEB_INT8})


## translation targets for ctranslate2

FINEWEB_CT2_DIR  := ${DATASET}/ct2/${LANGPAIR}/${MODELNAME}
FINEWEB_CT2      := $(patsubst ${FINEWEB_TXT_DIR}/%,${FINEWEB_CT2_DIR}/%,${FINEWEB_TXT})
FINEWEB_CT2_JOBS := $(addsuffix -ct2-job,${FINEWEB_CT2})


## make sure that translation files are not deleted
## in case the job times out

.PRECIOUS: ${FINEWEB_TRANS} ${FINEWEB_MISSING_TRANS} ${FINEWEB_INT8} ${FINEWEB_CT2}


## auxiliary targets to submit SLURM jobs for translating each data shard

.PHONY: translate-jobs
translate-jobs: ${FINEWEB_TRANS_JOBS}

.PHONY: ${FINEWEB_TRANS_JOBS}
${FINEWEB_TRANS_JOBS}:
	${MAKE} ${TRANSLATE_JOB_OPTIONS} $(@:-job=).${TRANSLATE_JOB_TYPE}

.PHONY: ${FINEWEB_INPUT_JOBS}
${FINEWEB_INPUT_JOBS}:
	${MAKE} HPC_CORES=1 HPC_MEM=4g HPC_TIME=2:00 $(@:-job=).submitcpu


.PHONY: translate-int8-jobs
translate-int8-jobs: ${FINEWEB_INT8_JOBS}

.PHONY: ${FINEWEB_INT8_JOBS}
${FINEWEB_INT8_JOBS}:
	${MAKE} ${TRANSLATE_JOB_OPTIONS} $(@:-job=).${TRANSLATE_JOB_TYPE}


## high-level targets for creating parallel release data
## (this checks for completeness by counting the number of lines for input/output)

.PHONY: release-data
release-data: 	${FINEWEB_TRANS_RELEASE_SRC} ${FINEWEB_TRANS_RELEASE_TRG} \
		${FINEWEB_TRANS_RELEASE_JSON} ${FINEWEB_TRANS_RELEASE_PARQUET} \
		${FINEWEB_TRANS_RELEASE_EXAMPLE}
	${MAKE} ${FINEWEB_TRANS_RELEASE_INFO}

.PHONY: release-first
release-first:  $(firstword ${FINEWEB_TRANS_RELEASE_SRC}) \
		$(firstword ${FINEWEB_TRANS_RELEASE_TRG}) \
		$(firstword ${FINEWEB_TRANS_RELEASE_JSON})



## targets for fetching the translation model
## and extracting the data for translation

.PHONY: prepare
prepare: prepare-model # ${FINEWEB_TXT}
	${MAKE} prepare-input

.PHONY: prepare-first
prepare-first: prepare-model # $(firstword ${FINEWEB_TXT})
	${MAKE} $(firstword ${FINEWEB_INPUT})

.PHONY: %-prepare
%-prepare: prepare-model
	${MAKE} $(word $(@:-prepare=),${FINEWEB_INPUT})
# 	${MAKE} $(word $(@:-prepare=),${FINEWEB_TXT})

.PHONY: prepare-txt
prepare-txt: ${FINEWEB_TXT}

.PHONY: prepare-input
prepare-input: ${FINEWEB_INPUT}

.PHONY: prepare-jobs
prepare-jobs: ${FINEWEB_INPUT_JOBS}




.PHONY: prepare-model
prepare-model: ${LANGPAIR}/${MODELNAME}/decoder.yml

.PHONY: quantize-model
quantize-model: ${LANGPAIR}/${MODELNAME}/model.intgemm8.bin

${LANGPAIR}/${MODELNAME}/model.intgemm8.bin: ${LANGPAIR}/${MODELNAME}/decoder.yml
	${BROWSERMT_CONVERT} -g intgemm8 -f $(wildcard ${LANGPAIR}/${MODELNAME}/*.npz) -t $@
	sed 's/- .*\.npz/- model.intgemm8.bin/' \
		< ${LANGPAIR}/${MODELNAME}/decoder.yml \
		> ${LANGPAIR}/${MODELNAME}/decoder-int8.yml




##---------------------------------------
## targets for translating (with OPUS-MT)
##---------------------------------------

.PHONY: translate
translate: ${FINEWEB_TRANS}

.PHONY: translate-first
translate-first: $(firstword ${FINEWEB_TRANS})

.PHONY: %-translate
%-translate: prepare-model
	${MAKE} $(word $(@:-translate=),${FINEWEB_TRANS})


# translate missing lines

.PHONY: translate-missing
translate-missing: ${FINEWEB_MISSING_TRANS}

.PHONY: %-translate-missing
%-translate-missing:
	${MAKE} MARIAN_MINI_BATCH=32 $(word $(@:-translate-missing=),${FINEWEB_MISSING_TRANS})


##---------------------------------------
## targets for translating with quantized models
##---------------------------------------

.PHONY: translate-int8
translate-int8: ${FINEWEB_INT8}

.PHONY: translate-int8-first
translate-int8-first: $(firstword ${FINEWEB_INT8})

.PHONY: %-translate-int8
%-translate-int8: prepare-model quantize-model
	${MAKE} $(word $(@:-translate-int8=),${FINEWEB_INT8})


##---------------------------------------
## targets for translating with ctransate2
##---------------------------------------

.PHONY: convert-model
convert-model: ct2/${LANGPAIR}/${MODELNAME}/model.bin

.PHONY: ct2
ct2: prepare-model convert-model ${FINEWEB_CT2}

.PHONY: ct2-first
ct2-first: prepare-model convert-model $(firstword ${FINEWEB_CT2})

.PHONY: %-ct2
%-ct2: prepare-model convert-model
	${MAKE} $(word $(@:-ct2=),${FINEWEB_CT2})

.PHONY: ${FINEWEB_CT2_JOBS}
${FINEWEB_CT2_JOBS}:
	${MAKE} ${CT2_JOB_OPTIONS} $(@:-job=).${CT2_JOB_TYPE}



##---------------------------------------
## translate with Marian-NMT (and OPUS-MT)
##---------------------------------------


ifeq (${SENTENCE_SPLIT},1)
  JSONL2TEXT_ARGS = -s
endif

## preparing a data file for translation
## (a) with dependency on the original jsonl file:
#
# ${FINEWEB_TXT}: ${FINEWEB_TXT_DIR}/%.txt.gz: ${FINEWEB_DIR}/%.jsonl.gz
# 	mkdir -p $(dir $@)
# 	python scripts/jsonl_to_text.py -i $< -l en ${JSONL2TEXT_ARGS} | gzip -c > $@


## (b) without dependency

${FINEWEB_TXT}:
	mkdir -p $(dir $@)
	python scripts/jsonl_to_text.py -l en ${JSONL2TEXT_ARGS} \
		-i $(patsubst ${FINEWEB_TXT_DIR}/%.txt.gz,${FINEWEB_DIR}/%.jsonl.gz,$@) \
	| gzip -c > $@



## fetch the selected model

${LANGPAIR}/${MODELNAME}/decoder.yml:
ifneq (${MODELZIP},)
ifeq (${MODELTYPE},HPLT-MT-models)
	mkdir -p ${dir $@}
	wget -O ${dir $@}/model.npz https://huggingface.co/HPLT/translate-${MODELLANG}-v1.0-hplt/resolve/main/model.npz.best-chrf.npz?download=true
	wget -O ${dir $@}/source.spm https://huggingface.co/HPLT/translate-${MODELLANG}-v1.0-hplt/resolve/main/model.${MODELLANG}.spm?download=true
	@echo 'relative-paths: true'     > $@
	@echo 'models:'                 >> $@
	@echo '  - model.npz'           >> $@
	@echo 'vocabs:'                 >> $@
	@echo '  - source.spm'          >> $@
	@echo '  - source.spm'          >> $@
	@echo 'beam-size: 4'            >> $@
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


## prepare input data for NMT decoder
## - OPUS-MT models require to run a pre-processing script
## - HPLT-MT models don't need further pre-processing: just link the file

ifeq (${MULTI_TARGET_MODEL},1)
  PREPROCESS_ARGS = ${SRC} ${TRG} ${LANGPAIR}/${MODELNAME}/source.spm
else
  PREPROCESS_ARGS = ${SRC} ${LANGPAIR}/${MODELNAME}/source.spm
endif

${FINEWEB_TRANS_DIR}/%.input.gz: ${FINEWEB_TXT_DIR}/%.txt.gz
	mkdir -p ${dir $@}
ifeq (${MODELTYPE},HPLT-MT-models)
	cd $(dir $@) && ln -s $(PWD)/$< $(notdir $@)
else
	gzip -cd < $< | ${LANGPAIR}/${MODELNAME}/preprocess.sh ${PREPROCESS_ARGS} | gzip -c > $@
endif



## OPUS-MT models require post-processing (merging subword-tokens)
## (also add a script for converting hexcodes that happen with some models)

ifneq (${MODELTYPE},HPLT-MT-models)
  POST_PROCESS := sed 's/ //g;s/▁/ /g' | sed 's/^ *//;s/ *$$//' | perl ${PWD}/scripts/convert_hexcodes.pl |
endif


## finally: target for translating a file

${FINEWEB_TRANS}: %.txt.gz: %.input.gz
	${MAKE} prepare-model
	${LOAD_ENV} && cd ${LANGPAIR}/${MODELNAME} && ${MARIAN_DECODER} \
		-i ${PWD}/$< \
		-c decoder.yml \
		${MARIAN_DECODER_FLAGS} |\
	${POST_PROCESS} gzip -c > ${PWD}/$@


${FINEWEB_INT8}: %.int8.gz: %.input.gz
	${MAKE} prepare-model
	${LOAD_ENV} && cd ${LANGPAIR}/${MODELNAME} && ${MARIAN_DECODER} \
		-i ${PWD}/$< \
		-c decoder-int8.yml \
		--int8 \
		${MARIAN_DECODER_FLAGS} |\
	${POST_PROCESS} gzip -c > ${PWD}/$@


## translate missing lines (from incomplete jobs)

${FINEWEB_MISSING_TRANS}: %.translated.gz: %.input.gz
	${MAKE} prepare-model
	${LOAD_ENV} && cd ${LANGPAIR}/${MODELNAME} && ${MARIAN_DECODER} \
		-i ${PWD}/$< \
		-c decoder.yml \
		${MARIAN_DECODER_FLAGS} |\
	${POST_PROCESS} gzip -c > ${PWD}/$@
	zcat ${FINEWEB_TRANS_DIR}/$(notdir $(@:.translated.gz=.txt.gz)) | head -n -1 > $(@:.translated.gz=.txt)
	zcat $@ >> $(@:.translated.gz=.txt)
	gzip -f $(@:.translated.gz=.txt)
	mv -f ${FINEWEB_TRANS_DIR}/$(notdir $(@:.translated.gz=.txt.gz)) $(@:.translated.gz=.incomplete.gz)
	mv $(@:.translated.gz=.txt.gz) ${FINEWEB_TRANS_DIR}/



##---------------------------------------
## translate files with ctranslate2
##---------------------------------------


## convert to ctranslate2
## TODO: does the conversion from spm to vocab.yml work correctly?

ct2/${LANGPAIR}/${MODELNAME}/model.bin: ${LANGPAIR}/${MODELNAME}/decoder.yml
ifneq (${MODELZIP},)
	mkdir -p ct2/${LANGPAIR}
ifeq (${MODELTYPE},HPLT-MT-models)
	spm_export_vocab --model ${LANGPAIR}/${MODELNAME}/source.spm > ${LANGPAIR}/${MODELNAME}/vocab.txt
	cut -f1 ${LANGPAIR}/${MODELNAME}/vocab.txt | scripts/vocab2yaml.py > ${LANGPAIR}/${MODELNAME}/vocab.yml
	ct2-marian-converter \
		--quantization int8 \
		--model_path ${LANGPAIR}/${MODELNAME}/model.npz \
		--vocab_paths ${LANGPAIR}/${MODELNAME}/vocab.yml ${LANGPAIR}/${MODELNAME}/vocab.yml \
		--output_dir $(dir $@)
else
	ct2-opus-mt-converter --quantization int8 --model_dir $(dir $<) --output_dir $(dir $@)
endif
endif


## tokenize source language (input files)

${TMPDIR}/${FINEWEB_CT2_DIR}/%.input: ${FINEWEB_TXT_DIR}/%.txt.gz
	mkdir -p ${dir $@}
ifeq (${MODELTYPE},HPLT-MT-models)
	gzip -cd < $< | spm_encode --model ${LANGPAIR}/${MODELNAME}/source.spm > $@
else
	gzip -cd < $< | ${LANGPAIR}/${MODELNAME}/preprocess.sh ${PREPROCESS_ARGS} > $@
endif


## translate

MODEL_CT2_DIR := ct2/${LANGPAIR}/${MODELNAME}
MODEL_SRC_SPM := ${LANGPAIR}/${MODELNAME}/source.spm


CT2_WORKERS    ?= 4
CT2_DEVICE     ?= cpu
CT2_BEAM_SIZE  ?= 4
CT2_BATCH_SIZE ?= 64

${FINEWEB_CT2}: %.txt.gz: ${TMPDIR}/%.input
	${MAKE} prepare-model
	${MAKE} convert-model
	mkdir -p ${TMPDIR}/$(dir $@)
	${LOAD_CT2_ENV} python3 scripts/translate_file.py \
		-i $< \
		-o ${TMPDIR}/${@:.gz=} \
		-m ${MODEL_CT2_DIR} \
		-s ${MODEL_SRC_SPM} \
		-d ${CT2_DEVICE} \
		-w ${CT2_WORKERS} \
		-b ${CT2_BEAM_SIZE} \
		-n ${CT2_BATCH_SIZE}
	mkdir -p $(dir $@)
	cat ${TMPDIR}/${@:.gz=} | sed 's/ //g;s/▁/ /g' | sed 's/^ *//;s/ *$$//' | gzip -c > $@
	rm -f ${TMPDIR}/${@:.gz=}



##---------------------------------------
## create release-data
## - check length (compare number of lines in input and output)
## - post-process input files to create regular text files
## - move the translated file and create a symbolic link to the original location
##
## This will skip the file if the translation is incomplete (different number of lines)
## TODO: do we need to create a source language file for each language pair?
##---------------------------------------


${FINEWEB_TRANS_RELEASE_TRG}: # ${FINEWEB_TRANS_RELEASE_DIR}/txt/${TRG}/%: ${FINEWEB_TRANS_DIR}/%
	@( O=$(patsubst ${FINEWEB_TRANS_RELEASE_DIR}/txt/${TRG}/%.txt.gz,${FINEWEB_TRANS_DIR}/%.txt.gz,$@); \
	   I=$(patsubst ${FINEWEB_TRANS_RELEASE_DIR}/txt/${TRG}/%.txt.gz,${FINEWEB_TRANS_DIR}/%.input.gz,$@); \
	   T=$(patsubst ${FINEWEB_TRANS_RELEASE_DIR}/txt/${TRG}/%.txt.gz,${FINEWEB_TXT_DIR}/%.txt.gz,$@); \
	   if [ -e $$I ] && [ -e $$O ] && [ -e $$T ]; then \
	     echo "check output length for $$O"; \
	     i=`gzip -cd $$I | wc -l`; \
	     o=`gzip -cd $$O | wc -l`; \
	     if [ $$i -eq $$o ]; then \
	       echo "- translations are complete ($(notdir $@))"; \
	       t=`gzip -cd $$T | wc -l`; \
	       if [ $$o -eq $$t ]; then \
	         echo "- translations in $(notdir $@) have the same length as original text data"; \
	         mkdir -p $(dir $@); \
	         rsync $$O $@; \
	       else \
	         echo "- different lengths ($$t != $$o) for $$T and $$O"; \
	       fi \
	     else \
	         echo "- incomplete translations ($$i != $$o) for $$I and $$O"; \
	     fi \
	   fi )


${FINEWEB_TRANS_RELEASE_SRC}: ${FINEWEB_TRANS_RELEASE_DIR}/txt/${SRC}/%: ${FINEWEB_TXT_DIR}/%
	mkdir -p $(dir $@)
	rsync $< $@


## translations merged into jsonl files
## TODO: do we need to keep the original text in the same jsonl document?

${FINEWEB_TRANS_RELEASE_JSON}: ${FINEWEB_TRANS_RELEASE_DIR}/jsonl/${TRG}/%.jsonl.gz: ${FINEWEB_TRANS_RELEASE_DIR}/txt/${TRG}/%.txt.gz
	if [ -e $< ]; then \
	  mkdir -p $(dir $@); \
	  python3 scripts/text_to_jsonl.py \
		-j $(patsubst ${FINEWEB_TRANS_RELEASE_DIR}/txt/${TRG}/%.txt.gz,${FINEWEB_DIR}/%.jsonl.gz,$<) \
		-s $(patsubst ${FINEWEB_TRANS_RELEASE_DIR}/txt/${TRG}/%.txt.gz,${FINEWEB_TXT_DIR}/%.txt.gz,$<) \
		-t $< -l ${TRG} \
	  | gzip -c > $@; \
	fi

#	python3 scripts/merge.py

%.parquet: %.jsonl.gz
	if [ -e $< ]; then \
	  ${PYTHONENV} python scripts/jsonl_to_parquet.py -i $< -o $@; \
	fi

${FINEWEB_TRANS_RELEASE_EXAMPLE}: %.md: %.txt.gz
	if [ -e $< ]; then \
	  mkdir -p $(dir $@); \
	  ${PYTHONENV} python scripts/translation_examples.py \
		-j $(patsubst ${FINEWEB_TRANS_RELEASE_DIR}/txt/${TRG}/%.txt.gz,${FINEWEB_DIR}/%.jsonl.gz,$<) \
		-s $(patsubst ${FINEWEB_TRANS_RELEASE_DIR}/txt/${TRG}/%.txt.gz,${FINEWEB_TXT_DIR}/%.txt.gz,$<) \
		-t $< -l ${TRG} | head -10 > $@; \
	fi



## readme file for the released translations

${FINEWEB_TRANS_RELEASE_INFO}: ${FINEWEB_TRANS_RELEASE_TRG} ${FINEWEB_TRANS_RELEASE_JSON} ${FINEWEB_TRANS_RELEASE_EXAMPLE}
	mkdir -p $(dir $@)
	@echo "# ${DATASET} translated into ${TRG}"        > $@
	@echo ""                                          >> $@
	@echo "* translation model: ${MODEL}"             >> $@
ifeq (${MODELTYPE},HPLT-MT-models)
	@echo "* model URL: https://huggingface.co/HPLT/translate-${MODELLANG}-v1.0-hplt" >> $@
else
	@echo "* model URL: ${MODELZIP}"                  >> $@
endif
	@echo "* decoding beam size: ${MARIAN_BEAM_SIZE}" >> $@
	@echo ""                                          >> $@
	@echo "## release files"                          >> $@
	@echo ""                                          >> $@
	@echo "Translated documents in parquet:"          >> $@
	@for d in ${FINEWEB_TRANS_RELEASE_PARQUET}; do \
	   if [ -e $$d ]; then \
	     echo "* [$$d](${STORAGE_URL}$$d)"            >> $@; \
	   fi \
	done
	@echo ""                                          >> $@
	@echo "Translated documents in JSONL:"            >> $@
	@for d in ${FINEWEB_TRANS_RELEASE_JSON}; do \
	   if [ -e $$d ]; then \
	     echo "* [$$d](${STORAGE_URL}$$d)"            >> $@; \
	   fi \
	done
	@echo ""                                          >> $@
	@echo "Translations in plain text format:"        >> $@
	@for d in ${FINEWEB_TRANS_RELEASE_TRG}; do \
	   if [ -e $$d ]; then \
	     echo -n "* [$$d](${STORAGE_URL}$$d): "       >> $@; \
	     echo "get stats for $$d"; \
	     zcat $$d | wc -lw  >> $@; \
	   fi \
	done
	@echo ""                                          >> $@
	@echo "Original data in plain text format:"       >> $@
	@for d in ${FINEWEB_TRANS_RELEASE_SRC}; do \
	   if [ -e $$d ]; then \
	     echo -n "* [$$d](${STORAGE_URL}$$d): "       >> $@; \
	     echo "get stats for $$d"; \
	     zcat $$d | wc -lw  >> $@; \
	   fi \
	done
	@echo ""                                          >> $@
	@echo "## Example translations"                   >> $@
	@echo ""                                          >> $@
	@for d in $(notdir ${FINEWEB_TRANS_RELEASE_EXAMPLE}); do \
	   if [ -e ${FINEWEB_TRANS_RELEASE_DIR}/txt/${TRG}/$$d ]; then \
	     echo "* [$$d]($$d)"                          >> $@; \
	   fi \
	done



##---------------------------------------
## create files with job stats
##---------------------------------------

JOBINFO_FILES = $(addsuffix .info,$(filter-out %.info,$(wildcard ${FINEWEB_TRANS_DIR}/*.out.*)))

.PHONY: jobinfo
jobinfo: ${JOBINFO_FILES}
	git add ${FINEWEB_TRANS_DIR}/*.submit
	git add ${FINEWEB_TRANS_DIR}/*.out.*
	git add ${FINEWEB_TRANS_DIR}/*.err.*
	git commit -am 'logfiles added for ${FINEWEB_TRANS_DIR}'

${JOBINFO_FILES}: %.info: %
	seff $(lastword $(subst ., ,$<)) > $@


##---------------------------------------
## show translations for a certain shard number
## together with the original input
##---------------------------------------

%-show-translations:
	@paste -d "\n" \
		<(gzip -cd $(word $(@:-show-translations=),${FINEWEB_INPUT})) \
		<(gzip -cd $(word $(@:-show-translations=),${FINEWEB_TRANS})) \
	| perl -pe 'if (/▁/){s/ //g;s/▁/ /g;s/^ *//;s/ *$$//;}' \
	| sed 'n;G' | sed 's/>>...<< //' \
	| perl ${PWD}/scripts/convert_hexcodes.pl


##---------------------------------------
## count the number of lines in input and translations
## in order to find incomplete translations
## --> move input for those missing lines (+1 extra line)
##     to prepare for translation jobs for those missing lines
##---------------------------------------

%-check-length:
	@( I=$(word $(@:-check-length=),${FINEWEB_INPUT}); \
	   O=$(word $(@:-check-length=),${FINEWEB_TRANS}); \
	   T=$(word $(@:-check-length=),${FINEWEB_TXT}); \
	   i=`gzip -cd $$I | wc -l`; \
	   o=`gzip -cd $$O | wc -l`; \
	   t=`gzip -cd $$T | wc -l`; \
	   if [ $$i -eq $$o ] && [  $$o -eq $$t ]; then \
	     echo "$$O is complete"; \
	   else \
	     echo "$$O is incomplete"; \
	     echo "$$i $$I"; \
	     echo "$$o $$O"; \
	     echo "$$t $$T"; \
	     echo "missing: $$(( $$i-$$o ))"; \
	     mkdir -p ${FINEWEB_MISSING_DIR}; \
	     M=$(patsubst ${FINEWEB_TRANS_DIR}/%,${FINEWEB_MISSING_DIR}/%,$(word $(@:-check-length=),${FINEWEB_INPUT})); \
	     zcat $$I | tail -n $$(( $$i-$$o+1 )) | gzip -c > $$M; \
	   fi )
