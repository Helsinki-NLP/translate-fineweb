

SHELL := bash

REPOHOME := ../../../
include ${REPOHOME}lib/env.mk
include ${REPOHOME}lib/slurm.mk


MULTISYNT_PARALLEL := /appl/local/openeurollm/training/catalogue/multisynt-mt/0.1/tower+/parallel


TOWER_MODEL := tower72b
TRGLANG     := swe_Latn
TRG         := $(firstword $(subst _, ,${TRGLANG}))
TRG2        := $(shell iso639 -2 -n ${TRG})


SRCDIR  := ${MULTISYNT_PARALLEL}/eng_Latn
TRGDIR  := ${MULTISYNT_PARALLEL}/${TOWER_MODEL}/${TRGLANG}
JSONL   := $(notdir $(wildcard ${TRGDIR}/*.jsonl.zst))
TRGTXTS := $(patsubst %.jsonl.zst,${TOWER_MODEL}/${TRG}/%.txt.gz,${JSONL})


## extract all bitexts (aligned paragraphs)
## and merge all bitexts together to create the multilingual parallel corpus

.PHONY: bitexts
bitexts: ${TRGTXTS}
	${MAKE} parallel/${TOWER_MODEL}/nemotron-cc.eng.gz \
		parallel/${TOWER_MODEL}/nemotron-cc.${TRG}.gz


## just the merging step without dependencies
## (do we need this?)

.PHONY: merge-bitexts
merge-bitexts:
	${MAKE} parallel/${TOWER_MODEL}/nemotron-cc.eng.gz \
		parallel/${TOWER_MODEL}/nemotron-cc.${TRG}.gz

.PHONY: merge-translations
merge-translations:
	${MAKE} parallel/${TOWER_MODEL}/nemotron-cc.${TRG}.gz

.PHONY: merge-original
merge-original:
	${MAKE} parallel/${TOWER_MODEL}/nemotron-cc.eng2.gz




COUNTS := $(patsubst %.gz,%.counts,${wildcard parallel/${TOWER_MODEL}/*.gz})

.PHONY: counts
counts: ${COUNTS}

${COUNTS}: %.counts: %.gz
	pigz -cd < $< | wc > $@




## extract parallel paragraphs from the translations of one specific shard

${TRGTXTS}: ${TOWER_MODEL}/${TRG}/%.txt.gz: ${TRGDIR}/%.jsonl.zst
	mkdir -p $(dir $@)
	python3 ./multisynt2bitext.py -s ${SRCDIR}/$(notdir $<) -t $< -l ${TRG2} \
	| tee >(cut -f1 | gzip -c > $(@:.txt.gz=.eng.gz)) \
	| cut -f2 | gzip -c > $@




## merge files together (target language trabslations and original English files)
## NOTE: take care of some empty lines that mess up the original bitexts

TARGET_FILES     := $(sort $(wildcard ${TOWER_MODEL}/${TRG}/*.txt.gz))
TARGET_BASENAMES := $(patsubst %.txt.gz,%,${TARGET_FILES})

parallel/${TOWER_MODEL}/nemotron-cc.${TRG}.gz:
	mkdir -p $(dir $@)
	rm -f ${@:.gz=}
	for f in ${TARGET_BASENAMES}; do \
	  echo "add $$f"; \
	  paste <(gzip -cd < $$f.eng.gz | tr "\t" ' ') <(gzip -cd < $$f.txt.gz | tr "\t" ' ') \
	  | grep --text ".	" | cut -f2 | grep --text -v 'END_OF_DOCUMENT' >> ${@:.gz=}; \
	done
	pigz ${@:.gz=}


ENGLISH_FILES := $(sort $(wildcard ${TOWER_MODEL}/${TRG}/*.eng.gz))
parallel/${TOWER_MODEL}/nemotron-cc.eng.gz: ${ENGLISH_FILES}
	mkdir -p $(dir $@)
# 	zcat $^ | grep --text '.' | grep --text -v 'END_OF_DOCUMENT' | gzip -c > $@
	zcat $^ | grep --text '.' | grep --text -v 'END_OF_DOCUMENT' > ${@:.gz=}
	pigz ${@:.gz=}

parallel/${TOWER_MODEL}/nemotron-cc.eng2.gz: ${ENGLISH_FILES}
	mkdir -p $(dir $@)
# 	zcat $^ | grep --text '.' | grep --text -v 'END_OF_DOCUMENT' | gzip -c > $@
	zcat $^ | grep --text '.' | grep --text -v 'END_OF_DOCUMENT' > ${@:.gz=}
	pigz ${@:.gz=}









## jobs for extracting bitexts (one per shard)

TRGTXT_JOBS := $(patsubst %,%.job,${TRGTXTS})
bitext-jobs: ${TRGTXT_JOBS}

${TRGTXT_JOBS}:
	${MAKE} HPC_CORES=2 HPC_MEM=8g HPC_TIME=48:00 $(@:.job=).submitcpu


# submit jobs to extract finnish translations

.PHONY: finnish
finnish:
	${MAKE} TRGLANG=fin_Latn bitext-jobs


# submit jobs to extract swedish translations

.PHONY: swedish
swedish:
	${MAKE} TRGLANG=swe_Latn bitext-jobs


