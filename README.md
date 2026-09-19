# Cardano Install

This repository contains `auto_install_cardano.sh`, an Ubuntu installer for a Cardano node.

## Validation

The complete supplied script has been assembled and passes `bash -n` syntax validation.

During installation, the script prompts for the node role (`relay` or
`block-producer`), whether to configure one or two local peers, and each
peer's address, port, and name. Relay nodes retain public bootstrap peers;
block producers connect only to the configured relay peers.

## Safety

Review the configuration at the top of the script before use. The installer upgrades system packages, builds and installs libraries, configures systemd and UFW, and must be run as a normal user with sudo access.
