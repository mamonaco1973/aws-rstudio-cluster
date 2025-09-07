#!/bin/bash

# ---------------------------------------------------------------------------------
# Ensure AWS SSM Agent is Installed and Running
# ---------------------------------------------------------------------------------
# The Amazon SSM Agent allows remote management, patching, and automation.
# Installing via snap ensures the latest version is available.

snap install amazon-ssm-agent --classic
systemctl enable snap.amazon-ssm-agent.amazon-ssm-agent.service
systemctl start snap.amazon-ssm-agent.amazon-ssm-agent.service
