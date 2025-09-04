#!/bin/bash
#PBS -q rt_HG
#PBS -N bigcodebench
#PBS -l select=1
#PBS -l walltime=1:00:00
#PBS -j oe
#PBS -m n
#PBS -koed
#PBS -V
#PBS -o outputs/

set -e
cd "$PBS_O_WORKDIR/bigcodebench"
source .venv/bin/activate

echo "Nodes allocated to this job:"
cat $PBS_NODEFILE

# environment variables
export TMP="/groups/gag51395/fujii/tmp"
export TMP_DIR="/groups/gag51395/fujii/tmp"
export HF_HOME="/groups/gag51395/fujii/hf_cache"

source .venv/bin/activate

export CUDA_VISIBLE_DEVICES=0
export TOKENIZERS_PARALLELISM=false
python -m bigcodebench.evaluate \
  --model $MODEL \
  --execution local \
  --split complete \
  --subset full \
  --backend vllm \
  --all_result_csv "../${RESULT_CSV}"
