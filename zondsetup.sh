#!/bin/bash

# Fix color output for both bash and zsh
if [[ "$SHELL" == *"zsh"* ]]; then
    GREEN=$'\e[32m'
    RESET=$'\e[0m'
else
    GREEN="\e[32m"
    RESET="\e[0m"
fi

green_echo() {
    echo -e "${GREEN}$1${RESET}"
}

green_echo "[+] Welcome to the Zond Setup Script an effort by @DigitalGuards"
green_echo "[+] This script will install the Zond Execution Engine and Qrysm Consensus Engine"
green_echo "[+] This currently assumes Go is already installed on the system"

# --- New code: Mode Selection ---
echo ""
echo "Select mode:"
echo "1) Full setup - Install dependencies, build binaries and launch nodes"
echo "2) Restart nodes - Launch only the node processes (skip dependency checks and builds)"
read -p "Enter your choice (1 or 2): " RUN_MODE

if [ "$RUN_MODE" == "2" ]; then
    RESTART_MODE=1
else
    RESTART_MODE=0
fi

if [ "$RESTART_MODE" -eq 1 ]; then
    # In restart mode, verify that required binaries exist
    if [ ! -f "$PWD/go-zond/build/bin/gzond" ]; then
        green_echo "[!] Error: gzond binary not found. Please run full setup first."
        exit 1
    fi
    if [ ! -f "$PWD/beacon-chain" ]; then
        green_echo "[!] Error: beacon-chain binary not found. Please run full setup first."
        exit 1
    fi
    GZOND_PATH="$PWD/go-zond/build/bin/gzond"
    BEACON_PATH="$PWD/beacon-chain"
    green_echo "[+] Restart mode selected. Skipping full setup and building binaries."
fi

if [ "$RESTART_MODE" -eq 0 ]; then
    # --- Full setup: dependency installation, cloning, and building binaries ---
    
    # Detect OS
    OS="$(uname)"

    # Install required packages based on OS
    if [ "$OS" = "Darwin" ]; then
        if ! command -v brew &>/dev/null; then
            green_echo "[+] Installing Homebrew..."
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        fi
        green_echo "[+] Installing required packages with Homebrew..."
        brew install screen tmux curl wget git
    else
        green_echo "[+] Installing required packages with apt-get..."
        sudo apt-get update
        sudo apt-get upgrade -y
        sudo apt-get install -y build-essential screen tmux curl wget git
    fi
    green_echo "[+] Installed build essentials and required tools"

    # Check for gobrew installation and install if needed
    if ! command -v gobrew &>/dev/null; then
        green_echo "[+] gobrew not found, installing..."
        wget -O - https://git.io/gobrew | sh
        green_echo "[+] gobrew installed successfully"
    else
        green_echo "[+] gobrew is already installed"
    fi

    if [ -d "$HOME/.gobrew" ]; then
        export PATH="$HOME/.gobrew/bin:$PATH"
        export PATH="$HOME/.gobrew/current/go/bin:$PATH"
    fi

    gobrew install 1.21.5
    gobrew install 1.20.12
    green_echo "[+] Finished installing gobrew"

    git clone https://github.com/theQRL/go-zond.git
    git clone https://github.com/theQRL/qrysm.git
    green_echo "[+] Cloned latest version of zond"

    # Build zond and qrysm first
    gobrew use 1.21.5
    cd go-zond/

    green_echo "[+] Building gzond..."
    if [ "$OS" = "Darwin" ]; then
        mkdir -p build/bin
        GOARCH=arm64 CGO_ENABLED=1 go build \
            -o build/bin/gzond \
            -ldflags "-s -w -X github.com/theQRL/go-zond/internal/version.gitCommit=$(git rev-parse HEAD) -X github.com/theQRL/go-zond/internal/version.gitDate=$(date +%Y%m%d)" \
            -tags "urfave_cli_no_docs,ckzg" \
            -gcflags=all="-B" \
            ./cmd/gzond || {
                green_echo "[!] Error: Failed to build gzond"
                green_echo "[!] Build output:"
                GOARCH=arm64 CGO_ENABLED=1 go build -v ./cmd/gzond
                exit 1
            }
    else
        go build -o build/bin/gzond \
            -ldflags "-X github.com/theQRL/go-zond/internal/version.gitCommit=$(git rev-parse HEAD) -X github.com/theQRL/go-zond/internal/version.gitDate=$(date +%Y%m%d)" \
            -tags "urfave_cli_no_docs,ckzg" \
            -trimpath \
            ./cmd/gzond
    fi

    if [ ! -f "build/bin/gzond" ]; then
        green_echo "[!] Error: gzond binary was not created"
        exit 1
    fi
    GZOND_PATH="$PWD/build/bin/gzond"
    cd ..
    green_echo "[+] Finished building the go-zond Execution Engine"

    cd qrysm/
    gobrew use 1.20.12

    green_echo "[+] Building qrysm binaries..."
    go build -o=../qrysmctl ./cmd/qrysmctl || { green_echo "[!] Error building qrysmctl"; exit 1; }
    BEACON_PATH="$PWD/../beacon-chain"
    go build -o="$BEACON_PATH" ./cmd/beacon-chain || { green_echo "[!] Error building beacon-chain"; exit 1; }
    go build -o=../validator ./cmd/validator || { green_echo "[!] Error building validator"; exit 1; }
    cd ..
    green_echo "[+] Finished building the Qrysm Consensus Engine"

    green_echo "[+] Pulling zond Config Files"
    wget https://github.com/theQRL/go-zond-metadata/raw/main/testnet/betanet/config.yml
    wget https://github.com/theQRL/go-zond-metadata/raw/main/testnet/betanet/genesis.ssz

    green_echo "[+] All dependencies and builds completed successfully"
fi

# --- Common: choose process manager and restart nodes ---
green_echo "[+] Now we need to choose how to run the nodes"

choose_process_manager() {
    echo ""
    echo "The Zond and Crysm nodes need to run as background processes."
    echo "Please choose which process manager you want to use:"
    echo ""
    echo "1) screen - Simple terminal multiplexer (default)"
    echo "2) tmux   - Terminal multiplexer with more features"
    echo "3) pm2    - Process manager with monitoring"
    echo ""
    
    local choice
    read -p "Enter your choice (1-3): " choice
    
    case $choice in
        2) PROCESS_MANAGER="tmux";;
        3) PROCESS_MANAGER="pm2";;
        *) PROCESS_MANAGER="screen";;
    esac
}

PROCESS_MANAGER=""
choose_process_manager
green_echo "[+] Using $PROCESS_MANAGER to manage the node processes"

green_echo "[+] Cleaning up any existing node processes..."
case $PROCESS_MANAGER in
    "screen")
        screen -X -S crysm quit 2>/dev/null || true
        screen -X -S zond quit 2>/dev/null || true
        ;;
    "tmux")
        tmux kill-session -t crysm 2>/dev/null || true
        tmux kill-session -t zond 2>/dev/null || true
        ;;
    "pm2")
        pm2 delete crysm 2>/dev/null || true
        pm2 delete zond 2>/dev/null || true
        ;;
esac

green_echo "[+] Starting Zond node in $PROCESS_MANAGER session..."
case $PROCESS_MANAGER in
    "screen")
        screen -dmS zond "$GZOND_PATH" \
            --log.file gozond.log \
            --nat=extip:0.0.0.0 \
            --betanet \
            --http \
            --http.api "web3,net,personal,zond,engine" \
            --datadir=gzonddata \
            --syncmode=full \
            --snapshot=false
        ;;
    "tmux")
        tmux new-session -d -s zond "$GZOND_PATH \
            --log.file gozond.log \
            --nat=extip:0.0.0.0 \
            --betanet \
            --http \
            --http.api 'web3,net,personal,zond,engine' \
            --datadir=gzonddata \
            --syncmode=full \
            --snapshot=false"
        ;;
    "pm2")
        pm2 start "$GZOND_PATH" --name zond -- \
            --log.file gozond.log \
            --nat=extip:0.0.0.0 \
            --betanet \
            --http \
            --http.api "web3,net,personal,zond,engine" \
            --datadir=gzonddata \
            --syncmode=full \
            --snapshot=false
        ;;
esac
green_echo "[+] Zond started"

green_echo "[+] Sleep for 10 seconds and launch ze crysm"
for i in {1000..1}; do
    printf "\r%.2f" $(bc <<< "scale=2; $i/100")
    sleep 0.01
done
green_echo "[+] Crysm consensus engine now starting"

case $PROCESS_MANAGER in
    "screen")
        screen -dmS crysm "$BEACON_PATH" \
            --log-file crysm.log --log-format text \
            --datadir=beacondata \
            --min-sync-peers=1 \
            --genesis-state="$PWD/genesis.ssz" \
            --chain-config-file="$PWD/config.yml" \
            --config-file="$PWD/config.yml" \
            --chain-id=32382 \
            --execution-endpoint=http://localhost:8551 \
            --accept-terms-of-use \
            --jwt-secret=gzonddata/gzond/jwtsecret \
            --contract-deployment-block=0 \
            --minimum-peers-per-subnet=0 \
            --p2p-static-id \
            --bootstrap-node "enr:-MK4QB1-CQAEPXFwD0D_tS08YXWPsKuaWdCzentML2JhAJnvXUR4lSPHCRXHCjudviKciwBmbPirHjyL_kmI0T1ti6qGAY0sF6hgh2F0dG5ldHOIAAAAAAAAAACEZXRoMpDeYa1-IAAAk___________gmlkgnY0gmlwhC1MJ0KJc2VjcDI1NmsxoQN_5eo8D8pFGWUX1SMAT7kMbY2a9Ryb6Bu2oAW8s28kyYhzeW5jbmV0cwCDdGNwgjLIg3VkcIIu4A" \
            --bootstrap-node "enr:-MK4QOiaZeOWRnUyxfJv0lTbvjh-Re4zfDBW7vNWl9wIW7n8OWzMmxhy8IVHgRF7QZrkm7OGShDogEYUtdg8Bt1nIqaGAY0sFwP7h2F0dG5ldHOIAAAAAAAAAACEZXRoMpDeYa1-IAAAk___________gmlkgnY0gmlwhC0g6p2Jc2VjcDI1NmsxoQK6I2IsSSRwnOtpsnzhgACTRfYZqUQ1aTsw-K4qMR_2BohzeW5jbmV0cwCDdGNwgjLIg3VkcIIu4A"
        ;;
    "tmux")
        tmux new-session -d -s crysm "$BEACON_PATH \
            --log-file crysm.log --log-format text \
            --datadir=beacondata \
            --min-sync-peers=1 \
            --genesis-state="$PWD/genesis.ssz" \
            --chain-config-file="$PWD/config.yml" \
            --config-file="$PWD/config.yml" \
            --chain-id=32382 \
            --execution-endpoint=http://localhost:8551 \
            --accept-terms-of-use \
            --jwt-secret=gzonddata/gzond/jwtsecret \
            --contract-deployment-block=0 \
            --minimum-peers-per-subnet=0 \
            --p2p-static-id \
            --bootstrap-node 'enr:-MK4QB1-CQAEPXFwD0D_tS08YXWPsKuaWdCzentML2JhAJnvXUR4lSPHCRXHCjudviKciwBmbPirHjyL_kmI0T1ti6qGAY0sF6hgh2F0dG5ldHOIAAAAAAAAAACEZXRoMpDeYa1-IAAAk___________gmlkgnY0gmlwhC1MJ0KJc2VjcDI1NmsxoQN_5eo8D8pFGWUX1SMAT7kMbY2a9Ryb6Bu2oAW8s28kyYhzeW5jbmV0cwCDdGNwgjLIg3VkcIIu4A' \
            --bootstrap-node 'enr:-MK4QOiaZeOWRnUyxfJv0lTbvjh-Re4zfDBW7vNWl9wIW7n8OWzMmxhy8IVHgRF7QZrkm7OGShDogEYUtdg8Bt1nIqaGAY0sFwP7h2F0dG5ldHOIAAAAAAAAAACEZXRoMpDeYa1-IAAAk___________gmlkgnY0gmlwhC0g6p2Jc2VjcDI1NmsxoQK6I2IsSSRwnOtpsnzhgACTRfYZqUQ1aTsw-K4qMR_2BohzeW5jbmV0cwCDdGNwgjLIg3VkcIIu4A'"
        ;;
    "pm2")
        pm2 start "$BEACON_PATH" --name crysm -- \
            --log-file crysm.log --log-format text \
            --datadir=beacondata \
            --min-sync-peers=1 \
            --genesis-state="$PWD/genesis.ssz" \
            --chain-config-file="$PWD/config.yml" \
            --config-file="$PWD/config.yml" \
            --chain-id=32382 \
            --execution-endpoint=http://localhost:8551 \
            --accept-terms-of-use \
            --jwt-secret=gzonddata/gzond/jwtsecret \
            --contract-deployment-block=0 \
            --minimum-peers-per-subnet=0 \
            --p2p-static-id \
            --bootstrap-node "enr:-MK4QB1-CQAEPXFwD0D_tS08YXWPsKuaWdCzentML2JhAJnvXUR4lSPHCRXHCjudviKciwBmbPirHjyL_kmI0T1ti6qGAY0sF6hgh2F0dG5ldHOIAAAAAAAAAACEZXRoMpDeYa1-IAAAk___________gmlkgnY0gmlwhC1MJ0KJc2VjcDI1NmsxoQN_5eo8D8pFGWUX1SMAT7kMbY2a9Ryb6Bu2oAW8s28kyYhzeW5jbmV0cwCDdGNwgjLIg3VkcIIu4A" \
            --bootstrap-node "enr:-MK4QOiaZeOWRnUyxfJv0lTbvjh-Re4zfDBW7vNWl9wIW7n8OWzMmxhy8IVHgRF7QZrkm7OGShDogEYUtdg8Bt1nIqaGAY0sFwP7h2F0dG5ldHOIAAAAAAAAAACEZXRoMpDeYa1-IAAAk___________gmlkgnY0gmlwhC0g6p2Jc2VjcDI1NmsxoQK6I2IsSSRwnOtpsnzhgACTRfYZqUQ1aTsw-K4qMR_2BohzeW5jbmV0cwCDdGNwgjLIg3VkcIIu4A"
        ;;
esac

green_echo "[+] Setup complete with $PROCESS_MANAGER running, exiting script."