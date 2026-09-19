#!/bin/bash
set -euo pipefail

# ==========================================================
# CARDANO NODE INSTALLER
# ==========================================================
#
# Run as normal user:
#
#   chmod +x install-cardano-node.sh
#   ./install-cardano-node.sh
#
# DO NOT run with sudo.
# The script uses sudo automatically where required.
#
# Automatically uses:
#
#   Current user
#   $HOME/cardano
#   $HOME/git
#
# ==========================================================


# ==========================================================
# AUTOMATIC USER DETECTION
# ==========================================================

CURRENT_USER="$(id -un)"
CURRENT_GROUP="$(id -gn)"
USER_HOME="${HOME}"

if [[ "${CURRENT_USER}" == "root" ]]; then
    echo "ERROR: Do not run this installer as root."
    echo
    echo "Run:"
    echo "  ./install-cardano-node.sh"
    echo
    exit 1
fi


# ==========================================================
# USER CONFIGURATION
# ==========================================================

NODE_VERSION="11.1.2"
GHC_VERSION="9.6.7"
CABAL_VERSION="3.12.1.0"

BLST_VERSION="v0.3.14"
LIBSODIUM_COMMIT="dbb48cc"

NETWORK="mainnet"

NODE_PORT="3002"
NODE_BIND_ADDRESS="0.0.0.0"

# ----------------------------------------------------------
# Local relay
# ----------------------------------------------------------

LOCAL_RELAY_ADDRESS="192.168.50.7"
LOCAL_RELAY_PORT="3002"
LOCAL_RELAY_NAME="crlnode02"

LOCAL_ROOT_VALENCY="1"
LOCAL_ROOT_ADVERTISE="false"
LOCAL_ROOT_TRUSTABLE="true"

# ----------------------------------------------------------
# Ledger peers
# ----------------------------------------------------------

USE_LEDGER_AFTER_SLOT="185500763"

# ----------------------------------------------------------
# Firewall
# ----------------------------------------------------------

OPEN_NODE_PORT="true"

# ----------------------------------------------------------
# gLiveView
# ----------------------------------------------------------

INSTALL_GLIVEVIEW="true"

# ----------------------------------------------------------
# systemd
# ----------------------------------------------------------

SERVICE_NAME="cardano-node"


# ==========================================================
# AUTOMATIC PATHS
# ==========================================================

NODE_HOME="${USER_HOME}/cardano"
GIT_HOME="${USER_HOME}/git"

NODE_DB="${NODE_HOME}/db"
NODE_CONFIG_DIR="${NODE_HOME}/config"
NODE_KEYS="${NODE_HOME}/keys"
NODE_SCRIPTS="${NODE_HOME}/scripts"
NODE_LOGS="${NODE_HOME}/logs"

NODE_SOCKET="${NODE_DB}/node.socket"

CARDANO_NODE_REPO="${GIT_HOME}/cardano-node"

BLST_DIR="${USER_HOME}/blst"
LIBSODIUM_DIR="${USER_HOME}/libsodium"

LOCAL_BIN="${USER_HOME}/.local/bin"

GHCUP_HOME="${USER_HOME}/.ghcup"
CABAL_HOME="${USER_HOME}/.cabal"

CARDANO_CONFIG_BASE_URL="https://book.world.dev.cardano.org/environments/${NETWORK}"


# ==========================================================
# SHOW CONFIGURATION
# ==========================================================

echo
echo "=========================================================="
echo " CARDANO NODE INSTALLER"
echo "=========================================================="
echo
echo "User:                  ${CURRENT_USER}"
echo "Group:                 ${CURRENT_GROUP}"
echo "Home:                  ${USER_HOME}"
echo
echo "Node version:          ${NODE_VERSION}"
echo "GHC version:           ${GHC_VERSION}"
echo "Cabal version:         ${CABAL_VERSION}"
echo
echo "Network:               ${NETWORK}"
echo "Node port:             ${NODE_PORT}"
echo "Bind address:          ${NODE_BIND_ADDRESS}"
echo
echo "Node home:             ${NODE_HOME}"
echo "Git home:              ${GIT_HOME}"
echo "Database:              ${NODE_DB}"
echo "Config:                ${NODE_CONFIG_DIR}"
echo "Socket:                ${NODE_SOCKET}"
echo
echo "Local relay:           ${LOCAL_RELAY_ADDRESS}:${LOCAL_RELAY_PORT}"
echo "Local relay name:      ${LOCAL_RELAY_NAME}"
echo
echo "=========================================================="
echo


# ==========================================================
# SUDO CHECK
# ==========================================================

echo "=== Check sudo access ==="

sudo -v


# ==========================================================
# UPDATE SYSTEM
# ==========================================================

echo
echo "=== Update Ubuntu ==="

sudo apt update
sudo apt upgrade -y


# ==========================================================
# INSTALL DEPENDENCIES
# ==========================================================

echo
echo "=== Install dependencies ==="

sudo apt install -y \
    autoconf \
    automake \
    autotools-dev \
    bc \
    build-essential \
    chrony \
    curl \
    git \
    g++ \
    htop \
    jq \
    libffi-dev \
    libgmp-dev \
    libssl-dev \
    libsystemd-dev \
    libtinfo-dev \
    libtool \
    liblmdb-dev \
    liburing-dev \
    libsecp256k1-dev \
    libsnappy-dev \
    libsqlite3-dev \
    m4 \
    make \
    pkg-config \
    protobuf-compiler \
    tmux \
    wget \
    zlib1g-dev \
    tcptraceroute


# ==========================================================
# CHRONY
# ==========================================================

echo
echo "=== Enable chrony ==="

sudo systemctl enable --now chrony


# ==========================================================
# CREATE DIRECTORIES
# ==========================================================

echo
echo "=== Create directories ==="

mkdir -p \
    "${GIT_HOME}" \
    "${NODE_DB}" \
    "${NODE_CONFIG_DIR}" \
    "${NODE_KEYS}" \
    "${NODE_SCRIPTS}" \
    "${NODE_LOGS}" \
    "${LOCAL_BIN}"


# ==========================================================
# INSTALL GHCUP
# ==========================================================

echo
echo "=== Install GHCup ==="

if [[ ! -d "${GHCUP_HOME}" ]]; then

    curl \
        --proto '=https' \
        --tlsv1.2 \
        -sSf \
        https://get-ghcup.haskell.org \
        | BOOTSTRAP_HASKELL_NONINTERACTIVE=1 sh

else

    echo "GHCup already installed."

fi

source "${GHCUP_HOME}/env"


# ==========================================================
# INSTALL GHC
# ==========================================================

echo
echo "=== Install GHC ${GHC_VERSION} ==="

ghcup install ghc "${GHC_VERSION}" || true
ghcup set ghc "${GHC_VERSION}"


# ==========================================================
# INSTALL CABAL
# ==========================================================

echo
echo "=== Install Cabal ${CABAL_VERSION} ==="

ghcup install cabal "${CABAL_VERSION}" || true
ghcup set cabal "${CABAL_VERSION}"

cabal update


# ==========================================================
# CURRENT ENVIRONMENT
# ==========================================================

export PATH="${LOCAL_BIN}:${CABAL_HOME}/bin:${GHCUP_HOME}/bin:/usr/local/bin:/usr/bin:/bin:${PATH}"

export LIBRARY_PATH="/usr/local/lib:${LIBRARY_PATH:-}"

export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:/usr/lib/x86_64-linux-gnu/pkgconfig:/usr/lib/pkgconfig:${PKG_CONFIG_PATH:-}"

export C_INCLUDE_PATH="/usr/local/include/blst:${C_INCLUDE_PATH:-}"

export NODE_HOME="${NODE_HOME}"

export NODE_CONFIG="${NETWORK}"

export CARDANO_NODE_SOCKET_PATH="${NODE_SOCKET}"


# ==========================================================
# CONFIGURE .BASHRC
# ==========================================================

echo
echo "=== Configure .bashrc ==="

BASHRC_START="# >>> Cardano node environment >>>"
BASHRC_END="# <<< Cardano node environment <<<"

touch "${USER_HOME}/.bashrc"

if grep -qF "${BASHRC_START}" "${USER_HOME}/.bashrc"; then

    sed -i \
        "\|${BASHRC_START}|,\|${BASHRC_END}|d" \
        "${USER_HOME}/.bashrc"

fi

cat >> "${USER_HOME}/.bashrc" <<BASHRC

${BASHRC_START}
export PATH="${LOCAL_BIN}:${CABAL_HOME}/bin:${GHCUP_HOME}/bin:/usr/local/bin:/usr/bin:/bin:\$PATH"
export LIBRARY_PATH="/usr/local/lib:\${LIBRARY_PATH:-}"
export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:/usr/lib/x86_64-linux-gnu/pkgconfig:/usr/lib/pkgconfig:\${PKG_CONFIG_PATH:-}"
export C_INCLUDE_PATH="/usr/local/include/blst:\${C_INCLUDE_PATH:-}"
export NODE_HOME="${NODE_HOME}"
export NODE_CONFIG="${NETWORK}"
export CARDANO_NODE_SOCKET_PATH="${NODE_SOCKET}"
${BASHRC_END}
BASHRC


# ==========================================================
# BUILD BLST
# ==========================================================

echo
echo "=== Build BLST ${BLST_VERSION} ==="

if [[ ! -d "${BLST_DIR}/.git" ]]; then

    git clone \
        https://github.com/supranational/blst.git \
        "${BLST_DIR}"

fi

cd "${BLST_DIR}"

git fetch --tags

git checkout "${BLST_VERSION}"

./build.sh


# ==========================================================
# INSTALL BLST
# ==========================================================

echo
echo "=== Install BLST ==="

sudo mkdir -p \
    /usr/local/include/blst \
    /usr/local/lib/pkgconfig

sudo cp \
    bindings/blst.h \
    /usr/local/include/blst/

sudo cp \
    bindings/blst_aux.h \
    /usr/local/include/blst/

sudo cp \
    libblst.a \
    /usr/local/lib/

sudo tee /usr/local/lib/pkgconfig/libblst.pc >/dev/null <<PC
prefix=/usr/local
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include/blst

Name: libblst
Description: BLST library
Version: ${BLST_VERSION#v}
Libs: -L\${libdir} -lblst
Cflags: -I\${includedir}
PC

sudo ldconfig


# ==========================================================
# BUILD LIBSODIUM
# ==========================================================

echo
echo "=== Build libsodium ${LIBSODIUM_COMMIT} ==="

if [[ ! -d "${LIBSODIUM_DIR}/.git" ]]; then

    git clone \
        https://github.com/IntersectMBO/libsodium.git \
        "${LIBSODIUM_DIR}"

fi

cd "${LIBSODIUM_DIR}"

git fetch

git checkout "${LIBSODIUM_COMMIT}"

./autogen.sh

mkdir -p build-aux

cp \
    /usr/share/misc/config.guess \
    build-aux/config.guess

cp \
    /usr/share/misc/config.sub \
    build-aux/config.sub

chmod +x \
    build-aux/config.guess \
    build-aux/config.sub

CONFIG_SHELL=/bin/bash ./configure

make -j"$(nproc)"

sudo make install

sudo ldconfig


# ==========================================================
# CLONE CARDANO-NODE
# ==========================================================

echo
echo "=== Download cardano-node ==="

mkdir -p "${GIT_HOME}"

cd "${GIT_HOME}"

if [[ ! -d "${CARDANO_NODE_REPO}/.git" ]]; then

    git clone \
        https://github.com/IntersectMBO/cardano-node.git \
        "${CARDANO_NODE_REPO}"

else

    echo "cardano-node repository already exists."

fi


# ==========================================================
# CHECKOUT CARDANO-NODE VERSION
# ==========================================================

cd "${CARDANO_NODE_REPO}"

echo
echo "=== Checkout cardano-node ${NODE_VERSION} ==="

git fetch \
    --all \
    --recurse-submodules \
    --tags

git checkout "${NODE_VERSION}"

git submodule update \
    --init \
    --recursive


# ==========================================================
# BUILD CARDANO-NODE
# ==========================================================

echo
echo "=== Build cardano-node ${NODE_VERSION} ==="

cabal clean
cabal update

cabal build \
    cardano-node \
    cardano-cli


# ==========================================================
# INSTALL BINARIES
# ==========================================================

echo
echo "=== Install Cardano binaries ==="

mkdir -p "${LOCAL_BIN}"

cp -p \
    "$(cabal list-bin cardano-node)" \
    "${LOCAL_BIN}/cardano-node"

cp -p \
    "$(cabal list-bin cardano-cli)" \
    "${LOCAL_BIN}/cardano-cli"

chmod +x \
    "${LOCAL_BIN}/cardano-node" \
    "${LOCAL_BIN}/cardano-cli"


# ==========================================================
# DOWNLOAD CARDANO MAINNET CONFIGURATION
# ==========================================================

echo
echo "=== Download ${NETWORK} configuration ==="

cd "${NODE_CONFIG_DIR}"

wget -N \
    "${CARDANO_CONFIG_BASE_URL}/config.json"

wget -N \
    "${CARDANO_CONFIG_BASE_URL}/topology.json"

wget -N \
    "${CARDANO_CONFIG_BASE_URL}/byron-genesis.json"

wget -N \
    "${CARDANO_CONFIG_BASE_URL}/shelley-genesis.json"

wget -N \
    "${CARDANO_CONFIG_BASE_URL}/alonzo-genesis.json"

wget -N \
    "${CARDANO_CONFIG_BASE_URL}/conway-genesis.json"

wget -N \
    "${CARDANO_CONFIG_BASE_URL}/checkpoints.json"

wget -N \
    "${CARDANO_CONFIG_BASE_URL}/peer-snapshot.json"

wget -N \
    "${CARDANO_CONFIG_BASE_URL}/tracer-config.json"


# ==========================================================
# CREATE CUSTOM TOPOLOGY.JSON
# ==========================================================

echo
echo "=== Create topology.json ==="

cat > "${NODE_CONFIG_DIR}/topology.json" <<TOPOLOGY
{
  "bootstrapPeers": [
    {
      "address": "backbone.cardano.iog.io",
      "port": 3001
    },
    {
      "address": "backbone.mainnet.cardanofoundation.org",
      "port": 3001
    }
  ],
  "localRoots": [
    {
      "accessPoints": [
        {
          "address": "${LOCAL_RELAY_ADDRESS}",
          "port": ${LOCAL_RELAY_PORT},
          "name": "${LOCAL_RELAY_NAME}"
        }
      ],
      "advertise": ${LOCAL_ROOT_ADVERTISE},
      "trustable": ${LOCAL_ROOT_TRUSTABLE},
      "valency": ${LOCAL_ROOT_VALENCY}
    }
  ],
  "peerSnapshotFile": "peer-snapshot.json",
  "publicRoots": [
    {
      "accessPoints": [],
      "advertise": false
    }
  ],
  "useLedgerAfterSlot": ${USE_LEDGER_AFTER_SLOT}
}
TOPOLOGY


# ==========================================================
# VALIDATE JSON
# ==========================================================

echo
echo "=== Validate topology.json ==="

jq empty "${NODE_CONFIG_DIR}/topology.json"

echo "topology.json OK"


echo
echo "=== Validate config.json ==="

jq empty "${NODE_CONFIG_DIR}/config.json"

echo "config.json OK"


echo
echo "=== Validate peer-snapshot.json ==="

jq empty "${NODE_CONFIG_DIR}/peer-snapshot.json"

echo "peer-snapshot.json OK"


echo
echo "=== Validate tracer-config.json ==="

jq empty "${NODE_CONFIG_DIR}/tracer-config.json"

echo "tracer-config.json OK"


# ==========================================================
# CREATE START-NODE.SH
# ==========================================================

echo
echo "=== Create start-node.sh ==="

cat > "${NODE_SCRIPTS}/start-node.sh" <<SCRIPT
#!/bin/bash
set -euo pipefail

export HOME="${USER_HOME}"

export PATH="${LOCAL_BIN}:${CABAL_HOME}/bin:${GHCUP_HOME}/bin:/usr/local/bin:/usr/bin:/bin:\$PATH"

export NODE_HOME="${NODE_HOME}"

export CARDANO_NODE_SOCKET_PATH="${NODE_SOCKET}"

exec cardano-node run \\
  --topology "${NODE_CONFIG_DIR}/topology.json" \\
  --database-path "${NODE_DB}" \\
  --socket-path "${NODE_SOCKET}" \\
  --host-addr "${NODE_BIND_ADDRESS}" \\
  --port "${NODE_PORT}" \\
  --config "${NODE_CONFIG_DIR}/config.json"
SCRIPT

chmod +x "${NODE_SCRIPTS}/start-node.sh"


# ==========================================================
# CREATE SYSTEMD SERVICE
# ==========================================================

echo
echo "=== Create systemd service ==="

sudo tee "/etc/systemd/system/${SERVICE_NAME}.service" >/dev/null <<SERVICE
[Unit]
Description=Cardano Node
After=network-online.target
Wants=network-online.target

[Service]
User=${CURRENT_USER}
Group=${CURRENT_GROUP}
Type=simple

Environment="HOME=${USER_HOME}"
Environment="PATH=${LOCAL_BIN}:${CABAL_HOME}/bin:${GHCUP_HOME}/bin:/usr/local/bin:/usr/bin:/bin"
Environment="CARDANO_NODE_SOCKET_PATH=${NODE_SOCKET}"
Environment="NODE_HOME=${NODE_HOME}"

WorkingDirectory=${NODE_HOME}

ExecStart=${NODE_SCRIPTS}/start-node.sh

Restart=always
RestartSec=10

LimitNOFILE=32768

[Install]
WantedBy=multi-user.target
SERVICE


# ==========================================================
# SYSTEMD RELOAD
# ==========================================================

sudo systemctl daemon-reload


# ==========================================================
# FIREWALL
# ==========================================================

echo
echo "=== Configure UFW firewall ==="

if [[ "${OPEN_NODE_PORT}" == "true" ]]; then

    echo "Opening Cardano node port ${NODE_PORT}/tcp"

    sudo ufw allow "${NODE_PORT}/tcp"

fi


# ==========================================================
# INSTALL GLIVEVIEW
# ==========================================================

if [[ "${INSTALL_GLIVEVIEW}" == "true" ]]; then

    echo
    echo "=== Install gLiveView ==="

    cd "${NODE_HOME}"

    curl -fsSL \
        -o gLiveView.sh \
        https://raw.githubusercontent.com/cardano-community/guild-operators/master/scripts/cnode-helper-scripts/gLiveView.sh

    curl -fsSL \
        -o env \
        https://raw.githubusercontent.com/cardano-community/guild-operators/master/scripts/cnode-helper-scripts/env

    chmod 755 gLiveView.sh

    echo
    echo "=== Configure gLiveView ==="

    sed -i \
        -e "s|^#\?CONFIG=.*|CONFIG=\"${NODE_CONFIG_DIR}/config.json\"|" \
        -e "s|^#\?CNODE_PORT=.*|CNODE_PORT=${NODE_PORT}|" \
        -e "s|^#\?SOCKET=.*|SOCKET=\"${NODE_SOCKET}\"|" \
        -e "s|^#\?TOPOLOGY=.*|TOPOLOGY=\"${NODE_CONFIG_DIR}/topology.json\"|" \
        -e "s|^#\?LOG_DIR=.*|LOG_DIR=\"${NODE_LOGS}\"|" \
        -e "s|^#\?DB_DIR=.*|DB_DIR=\"${NODE_DB}\"|" \
        env

fi


# ==========================================================
# FIX OWNERSHIP
# ==========================================================

echo
echo "=== Set ownership ==="

sudo chown -R \
    "${CURRENT_USER}:${CURRENT_GROUP}" \
    "${NODE_HOME}" \
    "${GIT_HOME}" \
    "${LOCAL_BIN}" \
    "${BLST_DIR}" \
    "${LIBSODIUM_DIR}"


# ==========================================================
# ENABLE SERVICE
# ==========================================================

echo
echo "=== Enable ${SERVICE_NAME} ==="

sudo systemctl enable "${SERVICE_NAME}"


# ==========================================================
# START SERVICE
# ==========================================================

echo
echo "=== Start ${SERVICE_NAME} ==="

sudo systemctl restart "${SERVICE_NAME}"

sleep 5


# ==========================================================
# CHECK INSTALLED VERSIONS
# ==========================================================

echo
echo "=========================================================="
echo " INSTALLED VERSIONS"
echo "=========================================================="
echo

"${LOCAL_BIN}/cardano-node" --version

echo

"${LOCAL_BIN}/cardano-cli" --version


# ==========================================================
# SERVICE STATUS
# ==========================================================

echo
echo "=========================================================="
echo " CARDANO NODE STATUS"
echo "=========================================================="
echo

sudo systemctl \
    --no-pager \
    --full \
    status "${SERVICE_NAME}" || true


# ==========================================================
# INSTALLATION SUMMARY
# ==========================================================

echo
echo "=========================================================="
echo " INSTALLATION COMPLETE"
echo "=========================================================="
echo
echo "User:"
echo "  ${CURRENT_USER}"
echo
echo "Home:"
echo "  ${USER_HOME}"
echo
echo "Cardano Node:"
echo "  ${NODE_VERSION}"
echo
echo "Network:"
echo "  ${NETWORK}"
echo
echo "Node directory:"
echo "  ${NODE_HOME}"
echo
echo "Git directory:"
echo "  ${GIT_HOME}"
echo
echo "Database:"
echo "  ${NODE_DB}"
echo
echo "Configuration:"
echo "  ${NODE_CONFIG_DIR}"
echo
echo "Socket:"
echo "  ${NODE_SOCKET}"
echo
echo "Node port:"
echo "  ${NODE_PORT}"
echo
echo "Local relay:"
echo "  ${LOCAL_RELAY_ADDRESS}:${LOCAL_RELAY_PORT}"
echo
echo "=========================================================="
echo " USEFUL COMMANDS"
echo "=========================================================="
echo
echo "Follow logs:"
echo
echo "  journalctl -u ${SERVICE_NAME} -f"
echo
echo "Service status:"
echo
echo "  systemctl status ${SERVICE_NAME}"
echo
echo "Restart node:"
echo
echo "  sudo systemctl restart ${SERVICE_NAME}"
echo
echo "Stop node:"
echo
echo "  sudo systemctl stop ${SERVICE_NAME}"
echo
echo "Start node:"
echo
echo "  sudo systemctl start ${SERVICE_NAME}"
echo
echo "Check socket:"
echo
echo "  ls -lh ${NODE_SOCKET}"
echo
echo "Query tip:"
echo
echo "  ${LOCAL_BIN}/cardano-cli query tip --mainnet"
echo

if [[ "${INSTALL_GLIVEVIEW}" == "true" ]]; then
    echo "Start gLiveView:"
    echo
    echo "  ${NODE_HOME}/gLiveView.sh"
    echo
fi

echo "=========================================================="
echo " CONFIGURATION FILES"
echo "=========================================================="
echo
echo "  ${NODE_CONFIG_DIR}/config.json"
echo "  ${NODE_CONFIG_DIR}/topology.json"
echo "  ${NODE_CONFIG_DIR}/byron-genesis.json"
echo "  ${NODE_CONFIG_DIR}/shelley-genesis.json"
echo "  ${NODE_CONFIG_DIR}/alonzo-genesis.json"
echo "  ${NODE_CONFIG_DIR}/conway-genesis.json"
echo "  ${NODE_CONFIG_DIR}/checkpoints.json"
echo "  ${NODE_CONFIG_DIR}/peer-snapshot.json"
echo "  ${NODE_CONFIG_DIR}/tracer-config.json"
echo
echo "=========================================================="
echo
