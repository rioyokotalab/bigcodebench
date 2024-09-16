#!/bin/bash
#YBATCH -r a6000_1
#SBATCH -N 1
#SBATCH -J bigcodebench
#SBATCH --time=168:00:00
#SBATCH --output outputs/%j.out

export PYTHONPATH=$PYTHONPATH:$(pwd)

. /etc/profile.d/modules.sh
module load singularity
source .venv_bigcodebench/bin/activate

MODEL=$1
DO_GENERATION=$2
DO_EVAL=$3
BACKEND=${4:-vllm} # hf,vllm,openai,mistralai,authropic,googleの6つから
NUM_GPU=1
batch_size=256
N_SAMPLES=1
DATASET=bigcodebench
TEMP=0
SPLIT=$5
SUBSET=$6

if [ "$SUBSET" = "full" ]; then
    FILE_HEADER="${DATASET}-${SUBSET}-${SPLIT}--${BACKEND}-${TEMP}-${N_SAMPLES}"
  else
    FILE_HEADER="${DATASET}-${SUBSET}-${SPLIT}--${BACKEND}-${TEMP}-${N_SAMPLES}"
  fi
OUTDIR="results/${MODEL}/bigcode"

mkdir -p $OUTDIR

if [ ${DO_GENERATION} = "true" ]; then
  echo "Generating"
  { time \
  bigcodebench.generate \
    --save_path ${OUTDIR}/${FILE_HEADER}.jsonl \
    --model $MODEL \
    --split $SPLIT \
    --subset $SUBSET \
    --backend $BACKEND \
    --greedy \
    --bs $batch_size \
    --n_samples $N_SAMPLES \
    --tp $NUM_GPU
  } 2>&1 | tee ${OUTDIR}/generation_time.log

  bigcodebench.sanitize --samples ${OUTDIR}/${FILE_HEADER}.jsonl --calibrate
fi

# Check if the ground truth works on your machine
if [ ${DO_EVAL} = "true" ]; then
  echo "Evaluating"
  # # If the execution is slow:
  bigcodebench.evaluate --split $SPLIT --subset $SUBSET --samples $OUTDIR/bigcodebench-${SUBSET}-${SPLIT}--vllm-0-1-sanitized-calibrated.jsonl --parallel 32
fi

echo "Model $MODEL"
echo "Done"
