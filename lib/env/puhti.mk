# -*-makefile-*-
#
# environment on puhti@CSC
#


DATA_PREPARE_HPCPARAMS = CPUJOB_HPC_CORES=2 CPUJOB_HPC_MEM=16g CPUJOB_HPC_DISK=3000
DATA_ALIGN_HPCPARAMS = CPUJOB_HPC_CORES=4 CPUJOB_HPC_JOBS=2 CPUJOB_HPC_MEM=64g CPUJOB_HPC_DISK=3000

TRANSLATE_JOB_OPTIONS := GPUJOB_HPC_MEM=64g \
			GPUJOB_HPC_CORES=8 \
			NR_GPUS=4 \
			MARIAN_GPUS='0 1 2 3' \
			MARIAN_DECODER_WORKSPACE=20000 \
			HPC_TIME=72:00

TRANSLATE_JOB_OPTIONS := GPUJOB_HPC_MEM=64g \
			GPUJOB_HPC_CORES=8 \
			NR_GPUS=1 \
			MARIAN_GPUS='0' \
			MARIAN_DECODER_WORKSPACE=20000 \
			HPC_TIME=72:00

TRANSLATE_JOB_TYPE := submit


TRANSLATE_CPUJOB_OPTIONS := HPC_MEM=128g \
			MARIAN_MINI_BATCH=40 \
			MARIAN_MAXI_BATCH=1 \
			HPC_CORES=40 \
			MARIAN_CPU_DECODER_WORKSPACE=512 \
			HPC_TIME=72:00




## job parameters for translating with ctranslate2

CT2_JOB_OPTIONS := GPUJOB_HPC_MEM=32g \
			LOAD_CT2_ENV='module load gcc/13.2.0 cuda/12.6.0 &&' \
			GPUJOB_HPC_CORES=4 \
			NR_GPUS=4 \
			CT2_WORKERS=4 \
			CT2_DEVICE=cuda \
			CT2_BEAM_SIZE=4 \
			CT2_BATCH_SIZE=128 \
			HPC_TIME=72:00

CT2_JOB_TYPE := submit

CT2_JOB_OPTIONS := GPUJOB_HPC_MEM=32g \
			LOAD_CT2_ENV='module load gcc/13.2.0 cuda/12.6.0 &&' \
			GPUJOB_HPC_CORES=4 \
			NR_GPUS=1 \
			CT2_WORKERS=1 \
			CT2_DEVICE=cuda \
			CT2_BEAM_SIZE=4 \
			CT2_BATCH_SIZE=128 \
			HPC_TIME=72:00

CT2_JOB_TYPE := submit

CT2_JOB_OPTIONS := HPC_MEM=64g \
			LOAD_CT2_ENV='module load gcc/13.2.0 &&' \
			HPC_CORES=40 \
			CT2_WORKERS=40 \
			CT2_DEVICE=cpu \
			CT2_BEAM_SIZE=4 \
			CT2_BATCH_SIZE=40 \
			HPC_TIME=72:00

CT2_JOB_TYPE := submitcpu




CSCPROJECT   = project_2005815
# CSCPROJECT   = project_2002688
# CSCPROJECT   = project_2002982
# CSCPROJECT    = project_2005625
WORKHOME     = ${shell realpath ${PWD}/work}
GPU          = v100
HPC_QUEUE    = small

SLURM_MAX_NR_JOBS := 200

ifneq (${wildcard /projappl/project_2001194/bin},)
  APPLHOME     = /projappl/project_2001194
  OPUSHOME     = /projappl/nlpl/data/OPUS
  MOSESHOME    = ${APPLHOME}/mosesdecoder
  MOSESSCRIPTS = ${MOSESHOME}/scripts
  EFLOMAL_HOME = ${APPLHOME}/eflomal/
  MARIAN_HOME  = ${APPLHOME}/marian-dev/build/
  MARIAN       = ${APPLHOME}/marian-dev/build
# MARIAN_HOME  = ${APPLHOME}/marian/build/
# MARIAN       = ${APPLHOME}/marian/build
  SPM_HOME     = ${MARIAN_HOME}
  export PATH := ${APPLHOME}/bin:${PATH}
endif

# set LOCAL_SCRATCH to nvme disk if it exists
ifdef SLURM_JOBID
ifneq ($(wildcard /run/nvme/job_${SLURM_JOBID}/tmp),)
  LOCAL_SCRATCH := /run/nvme/job_${SLURM_JOBID}/tmp
endif
endif

# set tmpdir
ifdef LOCAL_SCRATCH
  TMPDIR     := ${LOCAL_SCRATCH}
  TMPWORKDIR := ${LOCAL_SCRATCH}
else
  TMPDIR := /scratch/${CSCPROJECT}
endif


export PATH                := ${HOME}/perl5/bin:${PATH}:${MARIAN_HOME}:${SPM_HOME}:${FASTALIGN_HOME}
export PERL5LIB            := ${HOME}/perl5/lib/perl5:${PERL5LIB}}
export PERL_LOCAL_LIB_ROOT := ${HOME}/perl5:${PERL_LOCAL_LIB_ROOT}}
export PERL_MB_OPT         := --install_base "${HOME}/perl5"
export PERL_MM_OPT         := INSTALL_BASE=${HOME}/perl5


# CPU_MODULES = gcc/8.3.0 cuda/10.1.168 cudnn/7.6.1.34-10.1 intel-mkl/2019.0.4 python-env 
# GPU_MODULES = gcc/8.3.0 cuda/10.1.168 cudnn/7.6.1.34-10.1 intel-mkl/2019.0.4 python-env
CPU_MODULES = perl python-data cuda intel-oneapi-mkl openmpi
GPU_MODULES = perl python-data cuda intel-oneapi-mkl openmpi
LOAD_CPU_ENV = module load ${CPU_MODULES} && module list
LOAD_GPU_ENV = module load ${GPU_MODULES} && module list

ifneq (${HPC_DISK},)
  HPC_GPU_ALLOCATION = --gres=gpu:${GPU}:${NR_GPUS},nvme:${HPC_DISK}
  HPC_CPU_EXTRA1     = \#SBATCH --gres=nvme:${HPC_DISK}
endif

ifneq (${GPUJOB_HPC_DISK},)
  HPC_GPU_ALLOCATION = --gres=gpu:${GPU}:${NR_GPUS},nvme:${GPUJOB_HPC_DISK}
endif

ifneq (${CPUJOB_HPC_DISK},)
  HPC_CPU_EXTRA1  = \#SBATCH --gres=nvme:${CPUJOB_HPC_DISK}
  MAKEARGS       += HPC_DISK=${CPUJOB_HPC_DISK}
endif


## extra SLURM directives (up to 3 numbered variables)
# HPC_EXTRA1 = \#SBATCH --account=${CSCPROJECT}


BUILD_MODULES  = StdEnv perl python-data cuda intel-oneapi-mkl openmpi cmake
LOAD_BUILD_ENV = module load ${BUILD_MODULES} && module list

MARIAN_BUILD_MODULES  = StdEnv perl python-data cuda intel-oneapi-mkl openmpi cmake
LOAD_MARIAN_BUILD_ENV = module load ${MARIAN_BUILD_MODULES} && module list
MARIAN_BUILD_OPTIONS  =	-DCUDNN=ON \
			-DCOMPILE_CPU=ON \
			-DCOMPILE_CUDA=ON \
			-DCOMPILE_CUDA_SM35=OFF \
			-DCOMPILE_CUDA_SM50=OFF \
			-DCOMPILE_CUDA_SM60=OFF \
			-DCOMPILE_CUDA_SM70=ON \
			-DCOMPILE_CUDA_SM75=OFF \
			-DUSE_DOXYGEN=OFF
#			-DUSE_FBGEMM=1 \
#			-DFBGEMM_STATIC=1

#			-DTcmalloc_INCLUDE_DIR=/appl/spack/install-tree/gcc-8.3.0/gperftools-2.7-5w7w2c/include \
#			-DTcmalloc_LIBRARY=/appl/spack/install-tree/gcc-8.3.0/gperftools-2.7-5w7w2c/lib/libtcmalloc.so \
#			-DTCMALLOC_LIB=/appl/spack/install-tree/gcc-8.3.0/gperftools-2.7-5w7w2c/lib/libtcmalloc.so

LOAD_COMET_ENV = module load pytorch &&
