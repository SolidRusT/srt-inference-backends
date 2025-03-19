[Unit]
Description=Ensure Inference Services are Running
After=network.target docker.service
Wants=docker.service

[Service]
Type=oneshot
ExecStart=/var/lib/cloud/scripts/per-boot/ensure-services.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target