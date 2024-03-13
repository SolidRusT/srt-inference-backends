# tabbyAPI

API servcie to run exl2 models.

## Run with pyenv

```bash
git clone https://github.com/theroyallab/tabbyAPI

pyenv local 3.11
python -m venv ~/venv-tabbyAPI
source ~/venv-tabbyAPI/bin/activate

cd tabbyAPI
pip install -U -r requirements.txt

cp config_sample.yml config.yml

python main.py
```

## Run with Docker

```bash
git clone https://github.com/theroyallab/tabbyAPI
docker build -t solidrust/tabby-api .
```

```bash
volume="/srv/home/shaun/repos/text-generation-webui/models"

docker run --gpus all --shm-size 1g -p 8091:8091 \
  -v $volume:/data \
  solidrust/tabby-api
```
