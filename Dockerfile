# Используем официальный образ PostgreSQL 
FROM postgres:13
# Устанавливаем необходимые зависимости для сборки WAL-G
RUN apt-get update && apt-get install -y \
    libbrotli-dev \
    liblzo2-dev \
    libsodium-dev \
    curl \
    cmake \
    git \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
# Устанавливаем Go вручную (последняя версия)
# RUN apt-get install -y golang
RUN curl -LO https://go.dev/dl/go1.22.4.linux-amd64.tar.gz && \
    tar -C /usr/local -xzf go1.22.4.linux-amd64.tar.gz && \
    rm go1.22.4.linux-amd64.tar.gz
ENV PATH="/usr/local/go/bin:${PATH}"
# Устанавливаем WAL-G
RUN git clone https://github.com/wal-g/wal-g /wal-g && \
    cd /wal-g && \
    make deps pg_build && \
    cp main/pg/wal-g /usr/local/bin/wal-g && \
    rm -rf /wal-g
# Копируем скрипт для инициализации WAL-G и для бэкапа
COPY init-wal-g.sh /docker-entrypoint-initdb.d/ 
COPY backup.sh /usr/local/bin/backup.sh
RUN chmod +x /docker-entrypoint-initdb.d/init-wal-g.sh && \
    chmod +x /usr/local/bin/backup.sh
# Порт PostgreSQL
EXPOSE 5432
# Запуск PostgreSQL
CMD ["postgres"]

