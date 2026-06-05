#!/bin/sh
# backup.sh - Backup and restore Klipper configuration for K2 Plus
SCRIPT_DIR=/mnt/UDISK/helper-script
. "$SCRIPT_DIR/scripts/system.sh"

BACKUP_DIR=/mnt/UDISK/helper-script/backups

backup_config() {
    echo ""
    log_info "Backing up Klipper configuration..."
    mkdir -p "$BACKUP_DIR"

    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    BACKUP_FILE="$BACKUP_DIR/klipper_config_${TIMESTAMP}.tar.gz"

    tar -czf "$BACKUP_FILE" -C /mnt/UDISK/printer_data config/

    if [ $? -eq 0 ]; then
        echo ""
        log_success "Backup saved to: $BACKUP_FILE"
        SIZE=$(du -sh "$BACKUP_FILE" | cut -f1)
        log_info "Backup size: $SIZE"
        echo ""

        # Keep only last 5 backups
        ls -t "$BACKUP_DIR"/*.tar.gz 2>/dev/null | tail -n +6 | xargs rm -f 2>/dev/null
        log_info "Keeping last 5 backups. Older backups removed."
    else
        log_error "Backup failed."
    fi
    echo ""
}

restore_config() {
    echo ""
    log_info "Available backups:"
    echo ""

    if [ ! -d "$BACKUP_DIR" ] || [ -z "$(ls "$BACKUP_DIR"/*.tar.gz 2>/dev/null)" ]; then
        log_warn "No backups found in $BACKUP_DIR"
        return 1
    fi

    i=1
    for f in $(ls -t "$BACKUP_DIR"/*.tar.gz 2>/dev/null); do
        SIZE=$(du -sh "$f" | cut -f1)
        DATE=$(basename "$f" .tar.gz | sed 's/klipper_config_//' | sed 's/_/ /')
        echo "  $i) $DATE  [$SIZE]"
        eval "BACKUP_$i=$f"
        i=$((i+1))
    done

    echo "  0) Cancel"
    echo ""
    printf "  Select backup to restore: "
    read choice

    if [ "$choice" = "0" ] || [ -z "$choice" ]; then
        log_info "Cancelled."
        return 0
    fi

    eval "SELECTED=\$BACKUP_$choice"
    if [ -z "$SELECTED" ]; then
        log_error "Invalid selection."
        return 1
    fi

    echo ""
    echo -e "${YELLOW}WARNING: This will overwrite your current config files.${NC}"
    printf "Are you sure? [y/N]: "
    read confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        log_info "Cancelled."
        return 0
    fi

    log_info "Restoring from: $(basename $SELECTED)..."
    tar -xzf "$SELECTED" -C /mnt/UDISK/printer_data/

    if [ $? -eq 0 ]; then
        log_success "Config restored successfully."
        restart_klipper
    else
        log_error "Restore failed."
    fi
    echo ""
}

case "$1" in
    backup)  backup_config ;;
    restore) restore_config ;;
    *)       echo "Usage: $0 [backup|restore]" ;;
esac
