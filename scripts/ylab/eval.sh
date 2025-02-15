#!/bin/bash
#YBATCH -r a100_1
#SBATCH -J bigcodebench
#SBATCH --time=168:00:00
#SBATCH --output outputs/%j.out

source venv/bin/activate

MODEL=$1

# 1. Complete + Full
echo "Running evaluation: Complete + Full"
bigcodebench.evaluate \
  --model $MODEL \
  --execution gradio \
  --split complete \
  --subset full \
  --backend vllm

# 2. Complete + Hard
echo "Running evaluation: Complete + Hard"
bigcodebench.evaluate \
  --model $MODEL \
  --execution gradio \
  --split complete \
  --subset hard \
  --backend vllm

# 3. Instruct + Full
echo "Running evaluation: Instruct + Full"
bigcodebench.evaluate \
  --model $MODEL \
  --execution gradio \
  --split instruct \
  --subset full \
  --backend vllm

# 4. Instruct + Hard
echo "Running evaluation: Instruct + Hard"
bigcodebench.evaluate \
  --model $MODEL \
  --execution gradio \
  --split instruct \
  --subset hard \
  --backend vllm

echo "All evaluations completed!"