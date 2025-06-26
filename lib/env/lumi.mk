# -*-makefile-*-
#
# environment on mahti@CSC
#
# https://docs.lumi-supercomputer.eu/runjobs/scheduled-jobs/batch-job/
# https://docs.lumi-supercomputer.eu/runjobs/scheduled-jobs/partitions/


DATA_PREPARE_HPCPARAMS = CPUJOB_HPC_CORES=2 CPUJOB_HPC_MEM=16g
DATA_ALIGN_HPCPARAMS   = CPUJOB_HPC_CORES=8 CPUJOB_HPC_JOBS=8 CPUJOB_HPC_MEM=64g
# DATA_ALIGN_HPCPARAMS = CPUJOB_HPC_CORES=128 CPUJOB_HPC_JOBS=20 CPUJOB_HPC_MEM=128g
GPUJOB_HPC_CORES = 56
GPUJOB_HPC_MEM   = 32g


# TRANSLATE_JOB_OPTIONS := GPUJOB_HPC_MEM=64g GPUJOB_HPC_CORES=8 NR_GPUS=4 MARIAN_GPUS='0 1 2 3' HPC_TIME=30 HPC_GPUQUEUE=dev-g
TRANSLATE_JOB_OPTIONS := GPUJOB_HPC_MEM=64g GPUJOB_HPC_CORES=8 NR_GPUS=4 MARIAN_GPUS='0 1 2 3' HPC_TIME=72:00 HPC_GPUQUEUE=small-g
# TRANSLATE_JOB_OPTIONS := GPUJOB_HPC_MEM=64g \
# 			GPUJOB_HPC_CORES=8 \
# 			NR_GPUS=8 \
# 			MARIAN_GPUS='0 1 2 3 4 5 6 7' \
# 			HPC_TIME=24:00


TRANSLATE_JOB_TYPE := submit




## HPLT-bitexting
# CSCPROJECT    = project_462000688
# GPU_PROJECT   = project_462000688
# CPU_PROJECT   = project_462000688

## HPLT-bitexting-2
CSCPROJECT    = project_462000764
GPU_PROJECT   = project_462000764
CPU_PROJECT   = project_462000764

## MaMuLaM
# CSCROJECT     = project_462000964
# GPU_PROJECT   = project_462000964
# CPU_PROJECT   = project_462000964


HPC_QUEUE     = small
GPU           = a100
WALLTIME      = 72

SLURM_MAX_NR_JOBS := 200

SUBMIT_PREFIX = submitcpu

WORKHOME      = ${shell realpath ${PWD}/work}
OPUSHOME      = /scratch/project_462000688/data/OPUS

MONITOR := time


# set tmpdir
ifdef LOCAL_SCRATCH
  TMPDIR      := ${LOCAL_SCRATCH}
  TMPWORKDIR  := ${LOCAL_SCRATCH}
else
  TMPDIR     := /scratch/${CSCPROJECT}/tmp
  TMPWORKDIR := ${TMPDIR}
endif


## select queue depending on the number of GPUs allocated
HPC_GPUQUEUE ?= small-g

# ifeq (${NR_GPUS},1)
#  HPC_GPUQUEUE  = small-g
# else ifeq (${NR_GPUS},2)
#  HPC_GPUQUEUE  = small-g
# else
#  HPC_GPUQUEUE  = standard-g
# endif 



EXTRA_MODULES_DIR = /projappl/project_462000067/public/gnail/software/modules

CPU_MODULES   = cray-python parallel expat Perl wget
GPU_MODULES   = cray-python parallel expat Perl wget
# GPU_MODULES   = PrgEnv-cray/8.3.3 craype-accel-amd-gfx90a cray-python rocm/5.2.3 parallel expat Perl wget

LOAD_CPU_ENV  = module -q load ${CPU_MODULES}
LOAD_GPU_ENV  = module -q load ${GPU_MODULES}
# LOAD_CPU_ENV  = module load LUMI/23.03 && module load ${CPU_MODULES}
# LOAD_GPU_ENV  = module load LUMI/23.03 && module load ${GPU_MODULES}

# GPU_MODULES   = marian/lumi cray-python parallel
# LOAD_GPU_ENV  = module use -a ${EXTRA_MODULES_DIR} && module load ${GPU_MODULES}


# WGET := /appl/lumi/SW/LUMI-23.03/L/EB/wget/1.21.3-cpeCray-23.03/bin/wget -T 1
# MARIAN_HOME := /projappl/project_462000067/public/gnail/software/marian-320dd390/bin/
# MARIAN := ${MARIAN_HOME}marian


# MARIAN_HOME := /appl/local/csc/soft/ai/opt/MarianNMT-2024-09/bin/
# MARIAN      := ${MARIAN_HOME}marian

HPC_GPU_ALLOCATION = --gpus-per-node=${NR_GPUS}
HPC_GPU_EXTRA1 = \#SBATCH --cpus-per-task 56

# --gpus 	Set the total number of GPUs to be allocated for the job
# --gpus-per-node 	Set the number of GPUs per node
# --gpus-per-task 	Set the number of GPUs per task

# --mem 	Set the memory per node
# --mem-per-cpu 	Set the memory per allocated CPU cores
# --mem-per-gpu 	Set the memory per allocated GPU


## extra SLURM directives (up to 5 variables)
HPC_EXTRA1 = \#SBATCH --account=${CSCPROJECT}


## setup for compiling marian-nmt

# MARIAN_BUILD_MODULES  = gcc cuda cudnn openblas openmpi cmake
# LOAD_MARIAN_BUILD_ENV = module load ${MARIAN_BUILD_MODULES}

# /appl/spack/v017/install-tree/gcc-11.2.0/gperf-3.1-cxa2un

# MARIAN_BUILD_OPTIONS  = 

## setup for compiling extract-lex from marian-nmt

# LOAD_EXTRACTLEX_BUILD_ENV = cmake gcc/9.3.0 boost/1.68.0
# LOAD_EXTRACTLEX_BUILD_ENV = module load cmake boost

# LOAD_COMET_ENV = module load python-data pytorch cuda &&
# LOAD_COMET_ENV = module load pytorch && singularity_wrapper exec
# COMET_SCORE = ${HOME}/.local/bin/comet-score

# LOAD_COMET_ENV = module load pytorch &&
