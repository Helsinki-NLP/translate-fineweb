
PWD      := ${shell pwd}
REPOHOME := ${PWD}/
TOOLSDIR := ${REPOHOME}tools

include ${REPOHOME}lib/env.mk
include ${REPOHOME}lib/slurm.mk


# /scratch/project_462000963/datasets/HuggingFaceFW/fineweb-edu/350BT/fineweb-edu_350BT_00100.jsonl.gz
# 

SRC ?= eng
TRG ?= deu

LANGPAIR := ${SRC}-${TRG}


## select fineweb shards to be used

FINEWEB_START := 1
FINEWEB_END   := 50

FINEWEB_DIR     := /scratch/project_462000963/datasets/HuggingFaceFW/fineweb-edu/350BT
FINEWEB_JSONL   := $(wordlist ${FINEWEB_START},${FINEWEB_END},$(sort $(notdir $(wildcard ${FINEWEB_DIR}/*.gz))))
FINEWEB_TXT_DIR := fineweb-edu/350BT/${SRC}
FINEWEB_TXT     := $(patsubst %.jsonl.gz,${FINEWEB_TXT_DIR}/%.txt.gz,${FINEWEB_JSONL})





.PHONY: all translate-job translate-jobs
all: translate



.PHONY: prepare-job
prepare-job: prepare-model 
	${MAKE} HPC_MEM=64g HPC_CORES=32 prepare.submitcpu


## maximum input length (number sentence piece segments)

MARIAN_MAX_LENGTH := 512

## translation job options for a single GPU-node

# TRANSLATE_JOB_OPTIONS := GPUJOB_HPC_MEM=64g GPUJOB_HPC_CORES=8 NR_GPUS=8 MARIAN_GPUS='0 1 2 3 4 5 6 7' HPC_TIME=24:00 MARIAN_BEAM_SIZE=6
TRANSLATE_JOB_OPTIONS := GPUJOB_HPC_MEM=128g GPUJOB_HPC_CORES=8 NR_GPUS=8 HPC_TIME=24:00 MARIAN_BEAM_SIZE=6
TRANSLATE_JOB_TYPE    := submit

## translation job options for a CPU job
## NOTE: beam size is reduced to 1
## NOTE: memory will only be sufficient for transformer-base models

# TRANSLATE_JOB_OPTIONS := HPC_CORES=96 HPC_MEM=232g HPC_TIME=24:00 MARIAN_BEAM_SIZE=1 MARIAN_CPU_DECODER_WORKSPACE=1024
# TRANSLATE_JOB_TYPE    := submitcpu

## reduce number of cores to 32 for transformer-big models:
# TRANSLATE_JOB_OPTIONS := HPC_CORES=32 HPC_MEM=224g HPC_TIME=24:00 MARIAN_BEAM_SIZE=1
# TRANSLATE_JOB_TYPE    := submitcpu

.PHONY: translate-job
translate-job: prepare-first
	${MAKE} ${TRANSLATE_JOB_OPTIONS} translate-first.${TRANSLATE_JOB_TYPE}

.PHONY: translate-jobs
translate-jobs: ${FINEWEB_TRANS_JOBS}

.PHONY: ${FINEWEB_TRANS_JOBS}
${FINEWEB_TRANS_JOBS}:
	${MAKE} ${TRANSLATE_JOB_OPTIONS} $(@:-job=).${TRANSLATE_JOB_TYPE}






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


.PHONY: print-modelinfo
print-modelinfo:
	@echo ${MODELTYPE}
	@echo ${MODELNAME}
	@echo ${MODELZIP}
	@echo ${MODELINFO}
	@echo "multi-target model: ${MULTI_TARGET_MODEL}"
	@echo "target language label: ${TARGET_LANG_LABEL}"




FINEWEB_TRANS_DIR  := fineweb-edu/350BT/${LANGPAIR}/${MODELNAME}
FINEWEB_TRANS      := $(patsubst ${FINEWEB_TXT_DIR}/%,${FINEWEB_TRANS_DIR}/%,${FINEWEB_TXT})
FINEWEB_TRANS_JOBS := $(addsuffix -job,${FINEWEB_TRANS})


ifdef LOCAL_SCRATCH
  TMPDIR = ${LOCAL_SCRATCH}
endif




.PHONY: prepare
prepare: prepare-model ${FINEWEB_TXT}

.PHONY: prepare-first
prepare-first: prepare-model $(firstword ${FINEWEB_TXT})

.PHONY: prepare-model
prepare-model: ${LANGPAIR}/${MODELNAME}/decoder.yml



.PHONY: translate
translate: prepare-model ${FINEWEB_TRANS}

.PHONY: translate-first
translate-first: prepare-model $(firstword ${FINEWEB_TRANS})



${FINEWEB_TXT}: ${FINEWEB_TXT_DIR}/%.txt.gz: ${FINEWEB_DIR}/%.jsonl.gz
	mkdir -p $(dir $@)
	python jsonl_to_text.py -i $< -l en | gzip -c > $@




## fetch the selected model

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


## prepare input data for NMT decoder
## (OPUS-MT models require to run a pre-processing script)

ifeq (${MULTI_TARGET_MODEL},1)
  PREPROCESS_ARGS = ${SRC} ${TRG} ${LANGPAIR}/${MODELNAME}/source.spm
else
  PREPROCESS_ARGS = ${SRC} ${LANGPAIR}/${MODELNAME}/source.spm
endif

${FINEWEB_TRANS_DIR}/%.input.gz: ${FINEWEB_TXT_DIR}/%.txt.gz
	mkdir -p ${dir $@}
ifeq (${MODELTYPE},HPLT-MT-models)
	ln -s $< $@
else
	${GZCAT} $< | ${LANGPAIR}/${MODELNAME}/preprocess.sh ${PREPROCESS_ARGS} | gzip -c > $@
endif



## OPUS-MT models require post-processing

ifneq (${MODELTYPE},HPLT-MT-models)
  POST_PROCESS := sed 's/ //g;s/▁/ /g' | sed 's/^ *//;s/ *$$//' |
endif


## translate

${FINEWEB_TRANS}: %.txt.gz: %.input.gz
	${MAKE} prepare-model
	${LOAD_ENV} && cd ${LANGPAIR}/${MODELNAME} && ${MARIAN_DECODER} \
		-i ${PWD}/$< \
		-c decoder.yml \
		--num-devices ${NR_GPUS} \
		${MARIAN_DECODER_FLAGS} |\
	${POST_PROCESS} gzip -c > ${PWD}/$@

#		-d ${MARIAN_GPUS}

