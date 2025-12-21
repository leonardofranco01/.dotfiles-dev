#!/usr/bin/env bash

set -euo pipefail

# Flags / argumentos
ENABLE_BACKUPS=1
SHOW_HELP=0

for arg in "$@"; do
  case "$arg" in
  --no-backup | -N)
    ENABLE_BACKUPS=0
    ;;
  --help | -h)
    SHOW_HELP=1
    ;;
  esac
done

if [ "$SHOW_HELP" -eq 1 ]; then
  cat <<EOF
Uso: ./install.sh [opções]

Opções:
  -N, --no-backup     Desativa criação de backups; arquivos conflitantes são removidos.
  -h, --help          Mostra esta ajuda e sai.

Comportamento padrão: backups ativados em ~/dotfiles_backups/<timestamp>.
EOF
  exit 0
fi

echo "[+] Backups: $([ "$ENABLE_BACKUPS" -eq 1 ] && echo 'ATIVADOS' || echo 'DESATIVADOS')"

# 1. Atualização inicial e instalação de dependências base
echo -e "[+] Instalando dependências base\n"
sudo pacman -Syu --noconfirm base-devel git stow

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

paru -S --needed --noconfirm 7zip accountsservice adobe-source-han-sans-otc-fonts adobe-source-han-serif-otc-fonts adw-gtk-theme-git base base-devel bat bluez bluez-utils brave-bin brightnessctl btrfs-progs cava cliphist dgop direnv dkms dms-shell-bin dsearch-git efibootmgr eza

paru -S --needed --noconfirm fastfetch fd ffmpegthumbnailer file-roller firefox firewalld fish foot fzf git github-cli glycin-gtk4 gnome-keyring greetd-dms-greeter-git grim grimblast-git grub grub-btrfs gst-plugin-pipewire gvfs htop hyprland hyprpicker hyprpolkitagent iwd jq

paru -S --needed --noconfirm less libpulse linux linux-firmware linux-headers man-db mate-polkit matugen mpv neovim net-tools network-manager-applet networkmanager noto-fonts-cjk noto-fonts-emoji npm

paru -S --needed --noconfirm pamixer pavucontrol pipewire pipewire-alsa pipewire-jack pipewire-pulse playerctl pnpm polkit-kde-agent power-profiles-daemon-git qalculate-gtk qt5-wayland qt6-multimedia-ffmpeg qt6-wayland qt6ct-kde quickshell-git ripgrep-all satty slurp smartmontools snap-pac snapper sof-firmware starship stow syncthing tailscale thunar thunar-archive-plugin thunar-shares-plugin thunar-vcs-plugin thunar-volman trash-cli ttf-jetbrains-mono-nerd ttf-ms-fonts ttf-nerd-fonts-symbols-mono tumbler

paru -S --needed --noconfirm unrar unzip uv uwsm valgrind viewnior vim visual-studio-code-bin wf-recorder wget wireless_tools wireplumber wl-clip-persist wl-clipboard xdg-desktop-portal-gtk xdg-desktop-portal-hyprland xdg-utils xorg-server xorg-xinit yazi zellij zoxide zram-generator

# Instala o DankMaterialShell
echo -e "[+] Instalando o DankMaterialShell...\n"
curl -fsSL https://install.danklinux.com | sh

# Diretório dos dotfiles
DOTFILES="$HOME/dotfiles"
cd "$DOTFILES" || exit

# Lista de módulos a instalar
STOW_FOLDERS="bash dgop dms dsearch fish foot git hyprland nvim pavucontrol qalculate ssh starship viewnior yazi zellij"

if [ "$ENABLE_BACKUPS" -eq 1 ]; then
  # Configuração de backup (fora de .config)
  BACKUP_ROOT="$HOME/dotfiles_backups"
  TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
  BACKUP_DIR="$BACKUP_ROOT/$TIMESTAMP"
  mkdir -p "$BACKUP_DIR"
  echo -e "[+] Diretório de backup: $BACKUP_DIR\n"
else
  BACKUP_DIR="" # não usado
fi

echo -e "Criando symlinks para os Dotfiles ($([ "$ENABLE_BACKUPS" -eq 1 ] && echo 'com backups' || echo 'sem backups; conflitos serão removidos'))\n"
for folder in $STOW_FOLDERS; do
  echo -e "[+] Stowing $folder..."
  # Faz backup de arquivos conflitantes não-symlink preservando estrutura
  while IFS= read -r file; do
    target="$HOME/${file#"$folder"/}"
    if [ -f "$target" ] && [ ! -L "$target" ]; then
      if [ "$ENABLE_BACKUPS" -eq 1 ]; then
        relative_path="${target#"$HOME"/}"
        dest="$BACKUP_DIR/$relative_path"
        mkdir -p "$(dirname "$dest")"
        mv "$target" "$dest"
        echo "    [backup] $relative_path -> $dest"
      else
        echo "    [remove] Removendo conflito: ${target#"$HOME"/}"
        rm -f "$target"
      fi
    fi
  done < <(find "$folder" -type f)
  stow -v -t "$HOME" "$folder"
done
if [ "$ENABLE_BACKUPS" -eq 1 ]; then
  echo -e "[+] Backups concluídos. Arquivos movidos para $BACKUP_DIR\n"
else
  echo -e "[+] Conflitos tratados por remoção, nenhum backup criado.\n"
fi

# Variáveis FZF (sintaxe bash)
export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_DEFAULT_OPTS="--preview 'bat --style=numbers --color=always --line-range :500 {}'"

# Ativa os daemons
echo -e "Ativando os Daemons\n"
sudo systemctl disable sddm.service
sudo systemctl enable greetd.service
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

# Indexar arquivos para pesquisa
echo -e "[+] Indexando arquivos no Dsearch\n"
dsearch index generate

# Create symlink for hyprland config
ln -sf ~/dotfiles/hypland/.config/hypr/pc.conf ~/.config/hypr/current.conf

# Enable and sync greetd
dms greeter enable
dms greeter sync

sudo tailscale up
