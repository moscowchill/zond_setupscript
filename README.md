# Zond Node Setup Script

A setup script to run go-zond (execution client) and crysm (consensus client) nodes in background processes.

## Features

- Automatic installation of required dependencies
- Support for multiple process managers:
  - screen (simple terminal multiplexer)
  - tmux (advanced terminal multiplexer)
  - pm2 (process manager with monitoring)
- Cross-platform compatibility:
  - Linux (Debian/Ubuntu)
  - macOS (Intel/ARM)
- Automatic Go version management with gobrew
- Error handling and status updates

## Prerequisites

- Linux (Debian/Ubuntu) or macOS
- bash or zsh shell
- Internet connection
- Basic command line knowledge

## Usage

- Clone the repository
```
git clone https://github.com/theQRL/zond_setupscript.git
cd zond_setupscript
```

- Make the script executable
```
chmod +x zondsetup.sh
```

- Run the script
```
./zondsetup.sh  
```