#!/bin/bash
model=NousResearch/Hermes-2-Pro-Mistral-7B  # ${MODEL}
num_shard=1			# ${NUM_SHARD}
volume="${HOME}/${HOSTNAME}-AI/text-generation" # share a volume
#service_version=latest 	# ${SERVICE_VERSION}
service_version=latest-rocm 	# ${SERVICE_VERSION}
service_image="ghcr.io/huggingface/text-generation-inference"
service_port=8081		# ${SERVICE_PORT}
max_input_length=8192		# ${MAX_INPUT_LENGTH}
max_total_tokens=16384		# ${MAX_TOTAL_TOKENS}
max_batch_prefill_tokens=16384
gpus=all			# ${GPUS}

docker run \
  --device=/dev/kfd --device=/dev/dri --security-opt seccomp=unconfined --group-add video \
  --shm-size 1g -p $service_port:80 \
  -v $volume:/data $service_image:$service_version \
  --model-id $model --num-shard $num_shard \
  --max-concurrent-requests 128 \
  --max-best-of 2 \
  --max-stop-sequences 4 \
  --max-input-length $max_input_length \
  --max-total-tokens $max_total_tokens \
  --max-batch-prefill-tokens $max_batch_prefill_tokens
