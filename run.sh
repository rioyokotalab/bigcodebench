#!/bin/bash
#YBATCH -r a100_1
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
if [[ $MODEL == *"/"* ]]; then
  ORG=$(echo $MODEL | cut -d'/' -f1)--
  BASE_MODEL=$(echo $MODEL | cut -d'/' -f2)
else
  ORG=""
  BASE_MODEL=$MODEL
fi

if [ "$SUBSET" = "full" ]; then
    FILE_HEADER="${DATASET}-${SPLIT}--${BACKEND}-${TEMP}-${N_SAMPLES}"
  else
    FILE_HEADER="${DATASET}-${SUBSET}-${SPLIT}--${BACKEND}-${TEMP}-${N_SAMPLES}"
  fi
OUTDIR="results/${BASE_MODEL}/bigcode"

mkdir -p $OUTDIR

if [ ${DO_GENERATION} = "true" ]; then
  echo "Generating"
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

  bigcodebench.sanitize --samples ${OUTDIR}/${FILE_HEADER}.jsonl --calibrate
fi

# Check if the ground truth works on your machine
if [ ${DO_EVAL} = "true" ]; then
  echo "Evaluating"
  touch $(pwd)/${OUTDIR}/metrics.json
  singularity exec \
    --bind $(pwd)/${OUTDIR}/${FILE_HEADER}-sanitized-calibrated.jsonl:/app/generation.jsonl \
    --bind $(pwd)/${OUTDIR}/metrics.json:/app/metrics.json \
    /home/masaki/bigcodebench/evaluation-harness_latest.sif \
    python3 bigcodebench/evaluate.py --split $SPLIT --subset $SUBSET --samples /app/generation.jsonl --save_path metrics.json

  # # If the execution is slow:
  # bigcodebench.evaluate --split $SPLIT --subset $SUBSET --samples $FILE_HEADER-sanitized-calibrated.jsonl --parallel 32
fi

echo "Done"