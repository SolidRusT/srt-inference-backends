[Unit]
Description=Inference API Application
After=docker.service
Requires=docker.service

[Service]
TimeoutStartSec=0
Restart=always
ExecStartPre=-/usr/bin/docker stop inference-app
ExecStartPre=-/usr/bin/docker rm inference-app
ExecStartPre=/usr/local/bin/docker-login-ecr.sh
ExecStartPre=/usr/bin/docker pull ${ecr_repository_url}:latest
ExecStart=/usr/bin/docker run --rm --name inference-app -p ${app_port}:${app_port} -e PORT=${app_port} -e AWS_REGION=${aws_region} ${ecr_repository_url}:latest

[Install]
WantedBy=multi-user.target
