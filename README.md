# Cardano Install

This repository contains `auto_install_cardano.sh`, an Ubuntu installer for a Cardano node.

## Install on Ubuntu

Copy and paste this complete block into a terminal while logged in as the
normal user that will run the Cardano node:

```bash
sudo apt update
sudo apt install -y wget

wget -O auto_install_cardano.sh \
  https://github.com/sdamion/cardano_auto_install/releases/latest/download/auto_install_cardano.sh

chmod +x auto_install_cardano.sh
./auto_install_cardano.sh
```

Do not start the installer with `sudo`. The script requests `sudo` itself only
for operations that need administrative access.

## Validation

The complete supplied script has been assembled and passes `bash -n` syntax validation.

During installation, the script prompts for the Cardano network (`mainnet`,
`preprod`, or `preview`), the required node listening port, the node role
(`relay` or `block-producer`), whether to configure one or two local peers,
and each peer's address, port, and name. Peer IPv4 addresses, ports, and names
have no defaults and are required. Addresses must contain four octets in the
0–255 range, and all ports must be in the 1–65535 range. Relay nodes retain
public bootstrap peers; block producers connect only to the configured relay
peers.

The installer checks the latest non-prerelease Cardano Node version through
the official IntersectMBO GitHub Releases API. It then reads that release
tag's `nix/haskell.nix` and CI workflow to select Cardano's supported GHC
version and Cabal release line. The latest stable patch in that Cabal line is
resolved through the official `haskell/cabal` GitHub Releases API. The exact
detected versions and source URLs are shown for confirmation before the
toolchain is installed.

## Safety

Review the displayed configuration before confirming installation. The
installer can optionally upgrade system packages, builds and installs
libraries, configures systemd, and adds a Cardano port rule to UFW without
enabling the firewall. It must be run as a normal user with sudo access.
The completed `cardano-node` and `cardano-cli` binaries are installed globally
in `/usr/local/bin` using Cardano's `scripts/bin-path.sh` helper.
