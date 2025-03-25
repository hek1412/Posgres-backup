#!/bin/bash

# Путь к postgresql.conf
POSTGRESQL_CONF="/var/lib/postgresql/data/postgresql.conf"

# Добавляем параметры в конец файла postgresql.conf
cat <<EOL >> "$POSTGRESQL_CONF"
wal_level = replica
archive_mode = on
archive_command = 'wal-g wal-push %p'
restore_command = 'wal-g wal-fetch %f %p'
archive_timeout = 28800 
EOL

# Перезапускаем PostgreSQL для применения изменений
pg_ctl restart -D /var/lib/postgresql/data

# #!/bin/bash
# set -e

# # Проверяем, существует ли база данных, и если нет, восстанавливаем её из бэкапа
# if [ -z "$(ls -A /var/lib/postgresql/data)" ]; then
#     echo "Initializing database from backup..."
#     wal-g backup-fetch /var/lib/postgresql/data LATEST
# fi

# # Настраиваем архивирование WAL-G
# echo "wal_level = replica" >> /var/lib/postgresql/data/postgresql.conf
# echo "archive_mode = on" >> /var/lib/postgresql/data/postgresql.conf
# echo "archive_command = 'wal-g wal-push %p'" >> /var/lib/postgresql/data/postgresql.conf
# echo "restore_command = 'wal-g wal-fetch %f %p'" >> /var/lib/postgresql/data/postgresql.conf