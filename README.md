# Cardano Install

This repository contains `auto_install_cardano.sh`, an Ubuntu installer for a Cardano node.

## Validation

The complete supplied script has been assembled and passes `bash -n` syntax validation.

During installation, the script prompts for the Cardano network (`mainnet`,
`preprod`, or `preview`), the node role (`relay` or `block-producer`), whether
to configure one or two local peers, and each peer's address, port, and name.
Peer IPv4 addresses, ports, and names have no defaults and are required.
Addresses must contain four octets in the 0–255 range, and ports must be in
the 1–65535 range. Relay nodes retain public bootstrap peers; block producers
connect only to the configured relay peers.

## Safety

Review the configuration at the top of the script before use. The installer upgrades system packages, builds and installs libraries, configures systemd and UFW, and must be run as a normal user with sudo access.
