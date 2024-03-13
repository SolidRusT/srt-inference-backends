# docker run --gpus all nvidia/cuda:12.2.0-base-ubuntu22.04 nvidia-smi
FROM nvidia/cuda:12.3.1-base-ubuntu22.04

#RUN apt-get update && \
#    apt-get install -y python3-pip python3-dev && \
#    rm -rf /var/lib/apt/lists/*
FROM python:3.11
WORKDIR /app
COPY ./requirements.txt /app/requirements.txt
RUN pip install -r requirements.txt
COPY . /app

