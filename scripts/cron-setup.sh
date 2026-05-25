#!/usr/bin/env bash
# cron-setup.sh — install or uninstall the hourly auto-theme cron job
# Usage: ./cron-setup.sh install
#        ./cron-setup.sh uninstall

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
AUTO_THEME="$SCRIPT_DIR/auto-theme.sh"
CRON_TAG="ghostty-auto-theme"
CRON_LINE="0 * * * * \"$AUTO_THEME\" # $CRON_TAG"

usage() {
    echo "Usage: $(basename "$0") install|uninstall"
    exit 1
}

install_cron() {
    if [[ ! -x "$AUTO_THEME" ]]; then
        chmod +x "$AUTO_THEME"
    fi
    if crontab -l 2>/dev/null | grep -q "$CRON_TAG"; then
        echo "cron job already installed"
        exit 0
    fi
    (crontab -l 2>/dev/null; echo "$CRON_LINE") | crontab -
    echo "installed: $CRON_LINE"
}

uninstall_cron() {
    if ! crontab -l 2>/dev/null | grep -q "$CRON_TAG"; then
        echo "cron job not found"
        exit 0
    fi
    crontab -l 2>/dev/null | grep -v "$CRON_TAG" | crontab -
    echo "removed cron job"
}

case "${1:-}" in
    install)   install_cron ;;
    uninstall) uninstall_cron ;;
    *)         usage ;;
esac
