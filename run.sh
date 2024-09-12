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
batch_size=5
N_SAMPLES=1
DATASET=bigcodebench
TEMP=0
SPLIT=complete
SUBSET=hard

if [ "$SUBSET" = "full" ]; then
    FILE_HEADER="${DATASET}-${SPLIT}--${BACKEND}-${TEMP}-${N_SAMPLES}"
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
  touch $(pwd)/${OUTDIR}/${DATASET}-${SUBSET}-${SPLIT}_metrics.json
  singularity exec \
    --bind $(pwd)/${OUTDIR}/${FILE_HEADER}-sanitized-calibrated.jsonl:/app/generation.jsonl \
    --bind $(pwd)/${OUTDIR}/${DATASET}-${SUBSET}-${SPLIT}_metrics.json:/app/metrics.json \
    /home/masaki/bigcodebench/evaluation-harness_latest.sif \
    python3 bigcodebench/evaluate.py --split $SPLIT --subset $SUBSET --samples /app/generation.jsonl --save_path /app/metrics.json

  # # If the execution is slow:
  # bigcodebench.evaluate --split $SPLIT --subset $SUBSET --samples $FILE_HEADER-sanitized-calibrated.jsonl --parallel 32
fi

echo "Done"