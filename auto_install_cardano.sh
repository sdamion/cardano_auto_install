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

CARDANO_RELEASE_API_URL="https://api.github.com/repos/IntersectMBO/cardano-node/releases/latest"
CARDANO_RAW_BASE_URL="https://raw.githubusercontent.com/IntersectMBO/cardano-node"
CABAL_RELEASES_API_URL="https://api.github.com/repos/haskell/cabal/releases?per_page=100"

BLST_VERSION="v0.3.14"
LIBSODIUM_COMMIT="dbb48cc"

DEFAULT_NETWORK="mainnet"
DEFAULT_NODE_DB="${USER_HOME}/cardano/db"

NODE_BIND_ADDRESS="0.0.0.0"

# ----------------------------------------------------------
# Topology defaults
# ----------------------------------------------------------

DEFAULT_NODE_ROLE="relay"
DEFAULT_LOCAL_PEER_COUNT="1"

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
# INTERACTIVE TOPOLOGY CONFIGURATION
# ==========================================================

echo
echo "=========================================================="
echo " CARDANO TOPOLOGY CONFIGURATION"
echo "=========================================================="
echo

while true; do
    NETWORK_INPUT=""
    read -r -p "Cardano network: mainnet, preprod, or preview [${DEFAULT_NETWORK}]: " NETWORK_INPUT || true
    NETWORK="${NETWORK_INPUT:-${DEFAULT_NETWORK}}"
    NETWORK="${NETWORK,,}"

    case "${NETWORK}" in
        mainnet|preprod|preview)
            break
            ;;
        *)
            echo "Enter mainnet, preprod, or preview."
            ;;
    esac
done

while true; do
    NODE_PORT_INPUT=""
    read -r -p "Cardano node listening port (required): " NODE_PORT_INPUT || true

    if [[ "${NODE_PORT_INPUT}" =~ ^[0-9]+$ ]] \
        && ((${#NODE_PORT_INPUT} <= 5)) \
        && ((10#${NODE_PORT_INPUT} >= 1 && 10#${NODE_PORT_INPUT} <= 65535)); then
        NODE_PORT="$((10#${NODE_PORT_INPUT}))"
        break
    fi

    echo "Enter a port between 1 and 65535."
done

while true; do
    NODE_DB_INPUT=""
    read -r -p "Cardano database folder [${DEFAULT_NODE_DB}]: " NODE_DB_INPUT || true
    NODE_DB="${NODE_DB_INPUT:-${DEFAULT_NODE_DB}}"

    while [[ "${NODE_DB}" != "/" && "${NODE_DB}" == */ ]]; do
        NODE_DB="${NODE_DB%/}"
    done

    if [[ "${NODE_DB}" == /* && "${NODE_DB}" != "/" ]]; then
        break
    fi

    echo "Enter an absolute folder path other than /."
done

is_valid_ipv4() {
    local ip_address="$1"
    local octet
    local -a octets

    if [[ ! "${ip_address}" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]]; then
        return 1
    fi

    IFS='.' read -r -a octets <<< "${ip_address}"

    for octet in "${octets[@]}"; do
        if ((10#${octet} < 0 || 10#${octet} > 255)); then
            return 1
        fi
    done

    return 0
}

while true; do
    NODE_ROLE_INPUT=""
    read -r -p "Node role: relay or block-producer [${DEFAULT_NODE_ROLE}]: " NODE_ROLE_INPUT || true
    NODE_ROLE="${NODE_ROLE_INPUT:-${DEFAULT_NODE_ROLE}}"
    NODE_ROLE="${NODE_ROLE,,}"

    case "${NODE_ROLE}" in
        relay|block-producer)
            break
            ;;
        blockproducer|bp)
            NODE_ROLE="block-producer"
            break
            ;;
        *)
            echo "Enter relay or block-producer."
            ;;
    esac
done

while true; do
    LOCAL_PEER_COUNT_INPUT=""
    read -r -p "Number of local peers (1 or 2) [${DEFAULT_LOCAL_PEER_COUNT}]: " LOCAL_PEER_COUNT_INPUT || true
    LOCAL_PEER_COUNT="${LOCAL_PEER_COUNT_INPUT:-${DEFAULT_LOCAL_PEER_COUNT}}"

    if [[ "${LOCAL_PEER_COUNT}" == "1" || "${LOCAL_PEER_COUNT}" == "2" ]]; then
        break
    fi

    echo "Enter 1 or 2."
done

declare -a LOCAL_PEER_ADDRESSES=()
declare -a LOCAL_PEER_PORTS=()
declare -a LOCAL_PEER_NAMES=()

for ((PEER_INDEX = 1; PEER_INDEX <= LOCAL_PEER_COUNT; PEER_INDEX++)); do
    echo
    echo "Local peer ${PEER_INDEX}"

    while true; do
        PEER_ADDRESS_INPUT=""
        read -r -p "  IPv4 address (required): " PEER_ADDRESS_INPUT || true

        if is_valid_ipv4 "${PEER_ADDRESS_INPUT}"; then
            LOCAL_PEER_ADDRESSES+=("${PEER_ADDRESS_INPUT}")
            break
        fi

        echo "  Enter a valid IPv4 address with four numbers from 0 to 255."
    done

    while true; do
        PEER_PORT_INPUT=""
        read -r -p "  Port (required): " PEER_PORT_INPUT || true
        PEER_PORT="${PEER_PORT_INPUT}"

        if [[ "${PEER_PORT}" =~ ^[0-9]+$ ]] \
            && ((${#PEER_PORT} <= 5)) \
            && ((10#${PEER_PORT} >= 1 && 10#${PEER_PORT} <= 65535)); then
            LOCAL_PEER_PORTS+=("$((10#${PEER_PORT}))")
            break
        fi

        echo "  Enter a port between 1 and 65535."
    done

    while true; do
        PEER_NAME_INPUT=""
        read -r -p "  Name (required): " PEER_NAME_INPUT || true

        if [[ -n "${PEER_NAME_INPUT}" ]]; then
            LOCAL_PEER_NAMES+=("${PEER_NAME_INPUT}")
            break
        fi

        echo "  Enter a non-empty peer name."
    done
done


# ==========================================================
# AUTOMATIC PATHS
# ==========================================================

NODE_HOME="${USER_HOME}/cardano"
GIT_HOME="${USER_HOME}/git"

NODE_CONFIG_DIR="${NODE_HOME}/config"
NODE_KEYS="${NODE_HOME}/keys"
NODE_SCRIPTS="${NODE_HOME}/scripts"
NODE_LOGS="${NODE_HOME}/logs"

NODE_SOCKET="${NODE_DB}/node.socket"

CARDANO_NODE_REPO="${GIT_HOME}/cardano-node"

BLST_DIR="${USER_HOME}/blst"
LIBSODIUM_DIR="${USER_HOME}/libsodium"

LOCAL_BIN="/usr/local/bin"

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
echo "Software versions:     detected from the latest official Cardano release"
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
echo "Node role:             ${NODE_ROLE}"
echo "Local peer count:      ${LOCAL_PEER_COUNT}"

for ((PEER_INDEX = 0; PEER_INDEX < LOCAL_PEER_COUNT; PEER_INDEX++)); do
    echo "Local peer $((PEER_INDEX + 1)):          ${LOCAL_PEER_NAMES[PEER_INDEX]} (${LOCAL_PEER_ADDRESSES[PEER_INDEX]}:${LOCAL_PEER_PORTS[PEER_INDEX]})"
done
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

RUN_SYSTEM_UPGRADE=""
read -r -p "Run a full system upgrade before installing Cardano? [y/N]: " RUN_SYSTEM_UPGRADE || true

case "${RUN_SYSTEM_UPGRADE}" in
    [yY]|[yY][eE][sS])
        sudo apt upgrade -y

        if [[ -f /var/run/reboot-required ]]; then
            echo
            echo "=========================================================="
            echo " REBOOT REQUIRED"
            echo "=========================================================="
            echo
            echo "The system upgrade requires a reboot."
            echo "Reboot this machine, then rerun this installer:"
            echo
            echo "  sudo reboot"
            echo "  ./auto_install_cardano.sh"
            echo
            exit 0
        fi
        ;;
    *)
        echo "Skipping full system upgrade."
        ;;
esac


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
# DETECT OFFICIAL CARDANO TOOLCHAIN VERSIONS
# ==========================================================

echo
echo "=== Check latest official Cardano toolchain versions ==="

if ! CARDANO_RELEASE_JSON="$(curl -fsSL "${CARDANO_RELEASE_API_URL}")"; then
    echo "ERROR: Could not check the latest Cardano Node release."
    echo "Source: ${CARDANO_RELEASE_API_URL}"
    exit 1
fi

NODE_VERSION="$(jq -r '.tag_name // empty' <<< "${CARDANO_RELEASE_JSON}")"
NODE_RELEASE_URL="$(jq -r '.html_url // empty' <<< "${CARDANO_RELEASE_JSON}")"

if [[ -z "${NODE_VERSION}" || -z "${NODE_RELEASE_URL}" ]]; then
    echo "ERROR: The latest Cardano Node release response has no version or release URL."
    echo "Source: ${CARDANO_RELEASE_API_URL}"
    exit 1
fi

CARDANO_GHC_CONFIG_URL="${CARDANO_RAW_BASE_URL}/${NODE_VERSION}/nix/haskell.nix"
CARDANO_CI_CONFIG_URL="${CARDANO_RAW_BASE_URL}/${NODE_VERSION}/.github/workflows/haskell.yml"

if ! CARDANO_GHC_CONFIG="$(curl -fsSL "${CARDANO_GHC_CONFIG_URL}")"; then
    echo "ERROR: Could not read the GHC configuration for Cardano Node ${NODE_VERSION}."
    echo "Source: ${CARDANO_GHC_CONFIG_URL}"
    exit 1
fi

GHC_VERSION="$(
    sed -n \
        's/.*else "ghc\([0-9]\)\([0-9][0-9]*\)\([0-9]\)".*/\1.\2.\3/p' \
        <<< "${CARDANO_GHC_CONFIG}" \
        | head -n 1
)"

if [[ ! "${GHC_VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "ERROR: Could not determine the supported GHC version."
    echo "Source: ${CARDANO_GHC_CONFIG_URL}"
    exit 1
fi

if ! CARDANO_CI_CONFIG="$(curl -fsSL "${CARDANO_CI_CONFIG_URL}")"; then
    echo "ERROR: Could not read the Cabal configuration for Cardano Node ${NODE_VERSION}."
    echo "Source: ${CARDANO_CI_CONFIG_URL}"
    exit 1
fi

CABAL_VERSION_SERIES="$(
    sed -n \
        's/.*cabal-version[^\"]*"\([0-9][0-9.]*\)".*/\1/p' \
        <<< "${CARDANO_CI_CONFIG}" \
        | head -n 1
)"

if [[ ! "${CABAL_VERSION_SERIES}" =~ ^[0-9]+\.[0-9]+$ ]]; then
    echo "ERROR: Could not determine the supported Cabal release line."
    echo "Source: ${CARDANO_CI_CONFIG_URL}"
    exit 1
fi

if ! CABAL_RELEASES_JSON="$(curl -fsSL "${CABAL_RELEASES_API_URL}")"; then
    echo "ERROR: Could not check official Cabal releases."
    echo "Source: ${CABAL_RELEASES_API_URL}"
    exit 1
fi

CABAL_RELEASE="$(
    jq -c \
        --arg prefix "cabal-install-v${CABAL_VERSION_SERIES}." \
        '[.[] | select(.draft == false and .prerelease == false and (.tag_name | startswith($prefix)))] | first // empty' \
        <<< "${CABAL_RELEASES_JSON}"
)"

CABAL_VERSION="$(jq -r '.tag_name // empty' <<< "${CABAL_RELEASE}")"
CABAL_VERSION="${CABAL_VERSION#cabal-install-v}"
CABAL_RELEASE_URL="$(jq -r '.html_url // empty' <<< "${CABAL_RELEASE}")"

if [[ ! "${CABAL_VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ || -z "${CABAL_RELEASE_URL}" ]]; then
    echo "ERROR: Could not determine the latest stable Cabal ${CABAL_VERSION_SERIES}.x release."
    echo "Source: ${CABAL_RELEASES_API_URL}"
    exit 1
fi

echo
echo "=========================================================="
echo " OFFICIAL VERSIONS DETECTED"
echo "=========================================================="
echo
echo "Cardano Node: ${NODE_VERSION}"
echo "Release:      ${NODE_RELEASE_URL}"
echo
echo "GHC:          ${GHC_VERSION}"
echo "Checked at:   ${CARDANO_GHC_CONFIG_URL}"
echo
echo "Cabal:        ${CABAL_VERSION}"
echo "Cardano CI:   ${CARDANO_CI_CONFIG_URL}"
echo "Release:      ${CABAL_RELEASE_URL}"
echo

INSTALL_DETECTED_VERSIONS=""
read -r -p "Install these detected versions? [Y/n]: " INSTALL_DETECTED_VERSIONS || true

case "${INSTALL_DETECTED_VERSIONS}" in
    [nN]|[nN][oO])
        echo "Installation cancelled."
        exit 0
        ;;
esac


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
    "${NODE_LOGS}"


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

CABAL_VERSION="$(cabal --numeric-version)"

echo "Installed Cabal version: ${CABAL_VERSION}"


# ==========================================================
# CURRENT ENVIRONMENT
# ==========================================================

export PATH="${LOCAL_BIN}:${CABAL_HOME}/bin:${GHCUP_HOME}/bin:/usr/bin:/bin:${PATH}"

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
export PATH="${LOCAL_BIN}:${CABAL_HOME}/bin:${GHCUP_HOME}/bin:/usr/bin:/bin:\$PATH"
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

sudo mkdir -p "${LOCAL_BIN}"

sudo cp -p \
    "$(./scripts/bin-path.sh cardano-node)" \
    /usr/local/bin/cardano-node

sudo cp -p \
    "$(./scripts/bin-path.sh cardano-cli)" \
    /usr/local/bin/cardano-cli

sudo chmod +x \
    /usr/local/bin/cardano-node \
    /usr/local/bin/cardano-cli


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

LOCAL_ACCESS_POINTS='[]'

for ((PEER_INDEX = 0; PEER_INDEX < LOCAL_PEER_COUNT; PEER_INDEX++)); do
    LOCAL_ACCESS_POINTS="$(
        jq -n -c \
            --argjson accessPoints "${LOCAL_ACCESS_POINTS}" \
            --arg address "${LOCAL_PEER_ADDRESSES[PEER_INDEX]}" \
            --argjson port "${LOCAL_PEER_PORTS[PEER_INDEX]}" \
            --arg name "${LOCAL_PEER_NAMES[PEER_INDEX]}" \
            '$accessPoints + [{address: $address, port: $port, name: $name}]'
    )"
done

if [[ "${NODE_ROLE}" == "block-producer" ]]; then
    jq -n \
        --argjson accessPoints "${LOCAL_ACCESS_POINTS}" \
        --argjson advertise "${LOCAL_ROOT_ADVERTISE}" \
        --argjson trustable "${LOCAL_ROOT_TRUSTABLE}" \
        --argjson valency "${LOCAL_PEER_COUNT}" \
        '{
            bootstrapPeers: null,
            localRoots: [{
                accessPoints: $accessPoints,
                advertise: $advertise,
                trustable: $trustable,
                valency: $valency
            }],
            publicRoots: [],
            useLedgerAfterSlot: -1
        }' > "${NODE_CONFIG_DIR}/topology.json"
else
    jq -n \
        --argjson accessPoints "${LOCAL_ACCESS_POINTS}" \
        --argjson advertise "${LOCAL_ROOT_ADVERTISE}" \
        --argjson trustable "${LOCAL_ROOT_TRUSTABLE}" \
        --argjson valency "${LOCAL_PEER_COUNT}" \
        --argjson useLedgerAfterSlot "${USE_LEDGER_AFTER_SLOT}" \
        '{
            bootstrapPeers: [
                {address: "backbone.cardano.iog.io", port: 3001},
                {address: "backbone.mainnet.cardanofoundation.org", port: 3001}
            ],
            localRoots: [{
                accessPoints: $accessPoints,
                advertise: $advertise,
                trustable: $trustable,
                valency: $valency
            }],
            peerSnapshotFile: "peer-snapshot.json",
            publicRoots: [{accessPoints: [], advertise: false}],
            useLedgerAfterSlot: $useLedgerAfterSlot
        }' > "${NODE_CONFIG_DIR}/topology.json"
fi


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

export PATH="${LOCAL_BIN}:${CABAL_HOME}/bin:${GHCUP_HOME}/bin:/usr/bin:/bin:\$PATH"

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
Environment="PATH=${LOCAL_BIN}:${CABAL_HOME}/bin:${GHCUP_HOME}/bin:/usr/bin:/bin"
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
    "${NODE_DB}" \
    "${GIT_HOME}" \
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
echo "Node role:"
echo "  ${NODE_ROLE}"
echo
echo "Local peers:"

for ((PEER_INDEX = 0; PEER_INDEX < LOCAL_PEER_COUNT; PEER_INDEX++)); do
    echo "  ${LOCAL_PEER_NAMES[PEER_INDEX]}: ${LOCAL_PEER_ADDRESSES[PEER_INDEX]}:${LOCAL_PEER_PORTS[PEER_INDEX]}"
done

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
