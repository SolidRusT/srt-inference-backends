[Unit]
Description=Inference Services Watchdog
After=network.target docker.service multi-user.target
Wants=docker.service

[Service]
Type=simple
ExecStart=/usr/local/bin/inference-watchdog.sh
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target