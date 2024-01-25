#!/bin/bash
GREEN="\e[32m"
RESET="\e[0m"
green_echo() {
  echo -e "${GREEN}$1${RESET}"
}

green_echo "[+] Currently not zsh compatible run as bash zond-setup.sh"
green_echo "[+] This currently assumes Go is not already installed on the system"

# Check if ~/theQRL directory exists
if [ -d "$HOME/theQRL" ]; then
    echo "Directory ~/theQRL already exists. Removing it to start fresh."
    rm -rf "$HOME/theQRL"
    screen -X -S crysm quit
    screen -X -S zond quit
fi

mkdir -p ~/theQRL
cd ~/theQRL

sudo apt-get update
sudo apt-get upgrade -y
sudo apt-get install -y build-essential screen
green_echo "[+]  Installed build essentials and screen"

command -v wget &>/dev/null && echo "wget is already installed, continuing..." || { echo "wget not found, installing..."; sudo apt-get install -y wget; }
command -v gobrew &>/dev/null && echo "gobrew is already installed." || { echo "gobrew is not installed. Installing now."; wget -O - https://git.io/gobrew | sh; }
echo 'export PATH="$HOME/.gobrew/bin:$PATH"' >> ~/.bashrc
echo 'export PATH="$HOME/.gobrew/current/go/bin:$PATH' >> ~/.bashrc
export PATH="$HOME/.gobrew/bin:$PATH"
export PATH="$HOME/.gobrew/current/go/bin:$PATH"

gobrew install 1.21.5
gobrew install 1.20.12
green_echo "[+] Finished installing gobrew"

command -v git &>/dev/null && echo "git is already installed, continuing..." || { echo "git not found, installing..."; sudo apt-get install -y git; }
git clone https://github.com/theQRL/go-zond.git
git clone https://github.com/theQRL/qrysm.git
green_echo "[+] Cloned latest version of zond"

gobrew use 1.21.5
cd go-zond/
make gzond
cp build/bin/gzond ../
cd ..
green_echo "[+] Finished building the go-zond Execution Engine"

cd qrysm/
gobrew use 1.20.12
go build -o=../qrysmctl ./cmd/qrysmctl
go build -o=../beacon-chain ./cmd/beacon-chain
go build -o=../validator ./cmd/validator
cd ..
green_echo "[+] Finished building the Qrysm Consensus Engine"

green_echo "[+] Pulling zond Config Files"
wget https://github.com/theQRL/go-zond-metadata/raw/main/testnet/betanet/config.yml -P ~/theQRL
wget https://github.com/theQRL/go-zond-metadata/raw/main/testnet/betanet/genesis.ssz -P ~/theQRL

green_echo "[+] Zond node starting in screen session."
screen -dmS zond ./gzond \
  --log.file gozond.log \
  --nat=extip:0.0.0.0 \
  --betanet \
  --http \
  --http.api "web3,net,personal,zond,engine" \
  --datadir=gzonddata \
  --syncmode=full \
  --snapshot=false
green_echo "[+] Zond started"

green_echo "[+] Sleep for 10 seconds and launch ze crysm"
for i in {1000..1}; do
    printf "\r%.2f" $(bc <<< "scale=2; $i/100")
    sleep 0.01
done
green_echo "[+] Crysm consensus engine now starting"

screen -dmS crysm ./beacon-chain \
  --log-file crysm.log --log-format text \
  --datadir=beacondata \
  --min-sync-peers=1 \
  --genesis-state=genesis.ssz \
  --chain-config-file=config.yml \
  --config-file=config.yml \
  --chain-id=32382 \
  --execution-endpoint=http://localhost:8551 \
  --accept-terms-of-use \
  --jwt-secret=gzonddata/gzond/jwtsecret \
  --contract-deployment-block=0 \
  --minimum-peers-per-subnet=0 \
  --p2p-static-id \
  --bootstrap-node "enr:-MK4QB1-CQAEPXFwD0D_tS08YXWPsKuaWdCzentML2JhAJnvXUR4lSPHCRXHCjudviKciwBmbPirHjyL_kmI0T1ti6qGAY0sF6hgh2F0dG5ldHOIAAAAAAAAAACEZXRoMpDeYa1-IAAAk___________gmlkgnY0gmlwhC1MJ0KJc2VjcDI1NmsxoQN_5eo8D8pFGWUX1SMAT7kMbY2a9Ryb6Bu2oAW8s28kyYhzeW5jbmV0cwCDdGNwgjLIg3VkcIIu4A" \
  --bootstrap-node "enr:-MK4QOiaZeOWRnUyxfJv0lTbvjh-Re4zfDBW7vNWl9wIW7n8OWzMmxhy8IVHgRF7QZrkm7OGShDogEYUtdg8Bt1nIqaGAY0sFwP7h2F0dG5ldHOIAAAAAAAAAACEZXRoMpDeYa1-IAAAk___________gmlkgnY0gmlwhC0g6p2Jc2VjcDI1NmsxoQK6I2IsSSRwnOtpsnzhgACTRfYZqUQ1aTsw-K4qMR_2BohzeW5jbmV0cwCDdGNwgjLIg3VkcIIu4A"

green_echo "[+] Setup complete screens running, exiting script."