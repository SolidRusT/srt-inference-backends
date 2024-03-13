# SolidRust TGI

## Pre-requisites

- [Docker](https://docs.docker.com/get-docker/)
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)

## Build

```bash
TAG="v1.0.0"
aws ecr get-login-password --region us-west-2 | docker login --username AWS --password-stdin 078744956360.dkr.ecr.us-west-2.amazonaws.com

docker pull ghcr.io/huggingface/text-generation-inference:latest
docker build -t solidrust/solidrust-tgi .

docker tag solidrust/solidrust-tgi:latest 078744956360.dkr.ecr.us-west-2.amazonaws.com/solidrust/solidrust-tgi:latest
docker tag solidrust/solidrust-tgi:latest 078744956360.dkr.ecr.us-west-2.amazonaws.com/solidrust/solidrust-tgi:${TAG}

docker push 078744956360.dkr.ecr.us-west-2.amazonaws.com/solidrust/solidrust-tgi:latest
docker push 078744956360.dkr.ecr.us-west-2.amazonaws.com/solidrust/solidrust-tgi:${TAG}
```

Using the image:

```bash
docker pull 078744956360.dkr.ecr.us-west-2.amazonaws.com/solidrust/solidrust-tgi:latest
```
