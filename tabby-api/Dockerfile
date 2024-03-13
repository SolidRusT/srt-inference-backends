# Use an official Python runtime as a parent image
#FROM python:3.11.8-bookworm
FROM nvidia/cuda:12.3.1-runtime-ubuntu22.04

# Set non-interactive installation mode for apt-get
ENV DEBIAN_FRONTEND=noninteractive

RUN apt update && apt install -y \
  python3.11 python3-pip \
  python-is-python3 cuda \
  && rm -rf /var/lib/apt/lists/*

# Set the working directory in the container
WORKDIR /app

# Copy the current directory contents into the container at /app
COPY tabbyAPI /app

# Copy service configuration
COPY *.yml    /app

# Install torch with CUDA support and exllamav2
RUN pip install torch --extra-index-url https://download.pytorch.org/whl/cu121
RUN pip install exllamav2

# Install any needed packages specified in requirements.txt
RUN pip install --no-cache-dir -U -r /app/requirements.txt

# Make port 80 available to the world outside this container
EXPOSE 8091

# Run main.py when the container launches
CMD ["python", "main.py"]
