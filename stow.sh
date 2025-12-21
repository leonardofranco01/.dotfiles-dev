#!/usr/bin/env bash

set -euo pipefail

# Flags / argumentos
ENABLE_BACKUPS=1
SHOW_HELP=0

for arg in "$@"; do
    case "$arg" in
        --no-backup|-N)
            ENABLE_BACKUPS=0
            ;;
        --help|-h)
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

echo "[+] Backups: $( [ "$ENABLE_BACKUPS" -eq 1 ] && echo 'ATIVADOS' || echo 'DESATIVADOS' )"

# Diretório dos dotfiles
DOTFILES="$HOME/dotfiles"
cd "$DOTFILES" || exit

# Lista de módulos a instalar
STOW_FOLDERS="bash dgop dms dsearch fish foot git hyprland nvim pavucontrol qalculate ssh starship viewnior zellij"


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


echo -e "Criando symlinks para os Dotfiles ($( [ "$ENABLE_BACKUPS" -eq 1 ] && echo 'com backups' || echo 'sem backups; conflitos serão removidos' ))\n"
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