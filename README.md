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
- **Two operation modes:**
  - **Full setup:** Installs dependencies, clones repositories, builds binaries, and launches nodes.
  - **Restart nodes:** Skips dependency checks and rebuilds; only restarts the node processes (useful after a reboot).

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

When you run the script, you will be prompted to choose a mode:

- **Full setup:** Performs dependency installation, cloning, and building of binaries before launching the nodes.
- **Restart nodes:** Skips the full setup steps and only launches the node processes (ideal when the nodes have stopped, e.g., after a reboot).

Happy node running!