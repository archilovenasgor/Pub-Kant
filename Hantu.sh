
# ==========================================
# INSTALL DOCKER ENGINE + COMPOSE
# ==========================================

echo ""
echo "[INFO] Installing Docker Engine and Compose Plugin..."

. /etc/os-release
OS_ID="${ID}"
DOCKER_REPO=""

if command -v apt-get >/dev/null 2>&1; then

    case "$OS_ID" in
        ubuntu|debian)
            if [[ "$OS_ID" == "ubuntu" ]]; then
                DOCKER_REPO="ubuntu"
                DOCKER_CODENAME="${UBUNTU_CODENAME:-$VERSION_CODENAME}"
            else
                DOCKER_REPO="debian"
                DOCKER_CODENAME="$VERSION_CODENAME"
            fi

            install -m 0755 -d /etc/apt/keyrings

            curl -fsSL \
                "https://download.docker.com/linux/${DOCKER_REPO}/gpg" \
                -o /etc/apt/keyrings/docker.asc

            chmod a+r /etc/apt/keyrings/docker.asc

            echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/${DOCKER_REPO} ${DOCKER_CODENAME} stable" \
                > /etc/apt/sources.list.d/docker.list

            apt-get update -o DPkg::Lock::Timeout=300

            apt-get install -y -o DPkg::Lock::Timeout=300 \
                docker-ce \
                docker-ce-cli \
                containerd.io \
                docker-buildx-plugin \
                docker-compose-plugin
            ;;
        *)
            echo "[WARNING] APT distribution not officially configured for Docker."
            ;;
    esac

elif command -v dnf >/dev/null 2>&1 || command -v yum >/dev/null 2>&1; then

    case "$OS_ID" in
        fedora)
            DOCKER_REPO="fedora"
            ;;
        almalinux|rocky|centos|rhel)
            DOCKER_REPO="rhel"
            ;;
        *)
            echo "[WARNING] RPM distribution not officially configured for Docker."
            ;;
    esac

    if [[ -n "$DOCKER_REPO" ]]; then
        mkdir -p /etc/yum.repos.d

        curl -fsSL \
            "https://download.docker.com/linux/${DOCKER_REPO}/docker-ce.repo" \
            -o /etc/yum.repos.d/docker-ce.repo

        if command -v dnf >/dev/null 2>&1; then
            dnf install -y \
                docker-ce \
                docker-ce-cli \
                containerd.io \
                docker-buildx-plugin \
                docker-compose-plugin
        else
            yum install -y \
                docker-ce \
                docker-ce-cli \
                containerd.io \
                docker-buildx-plugin \
                docker-compose-plugin
        fi
    fi

else
    echo "[WARNING] Docker installation skipped: unsupported package manager."
fi

# Enable Docker service when systemd is available
if command -v systemctl >/dev/null 2>&1 &&
   [[ "$(ps -p 1 -o comm= | tr -d ' ')" == "systemd" ]] &&
   command -v docker >/dev/null 2>&1; then

    systemctl enable --now docker
    echo "[SUCCESS] Docker service enabled."
fi

# Verify installation
if command -v docker >/dev/null 2>&1; then
    echo "[SUCCESS] Docker installed:"
    docker --version

    if docker compose version; then
        echo "[SUCCESS] Docker Compose Plugin installed."
    else
        echo "[ERROR] Docker Compose Plugin verification failed."
        exit 1
    fi
else
    echo "[WARNING] Docker is not installed."
fi
