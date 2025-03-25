#!/bin/bash
set -e

export PGHOST=localhost
export PGUSER=postgres
export PGPASSWORD=$POSTGRES_PASSWORD

# Проверка наличия S3-конфигурации
if [ -z "$WALG_S3_PREFIX" ]; then
    echo "WAL-G: S3 configuration missing"
    exit 1
fi

# Форсированная очистка данных
echo "WAL-G: Performing clean restore..."
rm -rf "$PGDATA"/* 2>/dev/null || true

# Получение последнего бэкапа
LATEST_BACKUP=$(wal-g backup-list | awk 'NR==2 {print $1}')
if [ -z "$LATEST_BACKUP" ]; then
    echo "WAL-G: No backups found"
    exit 1
fi

# Восстановление с игнорированием идентификатора
wal-g backup-fetch "$PGDATA" "$LATEST_BACKUP" --restore-only --ignore-system-identifier

# Костыль для PostgreSQL 17
rm -f "$PGDATA"/postmaster.pid 2>/dev/null || true
rm -f "$PGDATA"/standby.signal 2>/dev/null || true

# Настройка восстановления
cat > "$PGDATA/postgresql.conf" <<EOF
wal_level = replica
archive_mode = on
archive_command = 'wal-g wal-push %p'
restore_command = 'wal-g wal-fetch %f %p'
recovery_target_timeline = 'latest'
recovery_end_command = 'rm -f /tmp/recovery_completed'
EOF

# Явное задание recovery target
touch "$PGDATA/recovery.signal"
echo "restore_command = 'wal-g wal-fetch %f %p'" > "$PGDATA/recovery.conf"

# Фикс прав
chown -R postgres:postgres "$PGDATA"
chmod 700 "$PGDATA"

echo "WAL-G: Recovery setup complete"
# #!/bin/bash
# set -e

# # Восстановление данных
# wal-g backup-fetch /var/lib/postgresql/data LATEST
# echo "restore_command = 'wal-g wal-fetch %f %p'" >> /var/lib/postgresql/data/postgresql.conf
# touch /var/lib/postgresql/data/recovery.signal

# # Запуск PostgreSQL
# exec postgres