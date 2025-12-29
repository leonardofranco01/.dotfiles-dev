#!/usr/bin/env bash

set -euo pipefail

# 1. Atualização inicial e instalação de dependências base
echo -e "[+] Instalando dependências base\n"
sudo pacman -Syu --noconfirm base base-devel git stow

if ! command -v paru &>/dev/null; then
  echo -e "[+] Instalando paru..."
  cd /tmp || exit
  git clone https://aur.archlinux.org/paru.git
  cd paru || exit
  makepkg -si --noconfirm
  cd - || exit
fi

# 3. Instalação de Pacotes
echo -e "[+] Instalando pacotes essenciais...\n"

paru -S --needed --noconfirm bat blueman bluez bluez-utils brightnessctl btop docker docker-compose efibootmgr eza fastfetch fd fish fzf git github-cli gst-plugin-pipewire htop intel-ucode inxi less libpulse linux linux-firmware linux-headers man-db neovim networkmanager npm openssh pipewire pipewire-alsa pipewire-jack pipewire-pulse postgresql power-profiles-daemon ripgrep ripgrep-all speedtest-cli stow tailscale unrar unzip vim wget wireplumber yazi zellij zoxide zram-generator

# Instala os dotfiles
rm -rf ~/.config/.bashrc ~/.config/fish ~/.gitconfig ~/.config/nvim ~/.ssh/config ~/.config/yazi ~/.config/zellij
cd ~/.dotfiles-dev
stow bash fish git nvim ssh yazi zellij

# Variáveis FZF (sintaxe bash)
export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_DEFAULT_OPTS="--preview 'bat --style=numbers --color=always --line-range :500 {}'"

# Ativa os daemons
echo -e "Ativando os Daemons\n"
sudo systemctl unmask firewalld
sudo systemctl enable firewalld
sudo systemctl start firewalld
sudo systemctl enable --now sshd
systemctl enable syncthing@leo.service
sudo loginctl enable-linger leo
systemctl --user enable syncthing.service
systemctl start syncthing@leo.service
sudo systemctl enable --now tailscaled

# Função para criação segura de chaves SSH (apenas se não existirem)
generate_ssh_key() {
  local key_path="$1"
  shift
  local key_type="$1"
  shift
  local key_comment="$1"
  shift
  local key_bits="${1:-}" # opcional (apenas RSA)

  # Verifica existência (privada ou pública)
  if [ -f "$key_path" ] || [ -f "$key_path.pub" ]; then
    echo "[!] Chave já existe, pulando: ${key_path##*/}"
    return 0
  fi

  echo "[+] Gerando chave: ${key_path##*/}"
  if [ "$key_type" = "rsa" ]; then
    ssh-keygen -t rsa -b "${key_bits:-4096}" -C "$key_comment" -f "$key_path" -N ""
  else
    ssh-keygen -t "$key_type" -C "$key_comment" -f "$key_path" -N ""
  fi
}

# Diretório .ssh
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

# Paths das chaves
PERSONAL_KEY="$HOME/.ssh/personal"
CONPEC_KEY="$HOME/.ssh/conpec"
UNICAMP_KEY="$HOME/.ssh/unicamp"

echo -e "[+] Verificando/Gerando chaves SSH (personal, conpec, unicamp)\n"
generate_ssh_key "$PERSONAL_KEY" ed25519 "leonardofrancosilva01@gmail.com"
generate_ssh_key "$CONPEC_KEY" ed25519 "leonardo.franco@conpec.com.br"
generate_ssh_key "$UNICAMP_KEY" rsa "l205007@dac.unicamp.br" 4096

sudo tailscale up
