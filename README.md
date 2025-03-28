# PostgreSQL с WAL-G для бэкапов в S3 яндекса

Одно из решений бэкапа PostgreSQL с использованием WAL-G для резервного копирования БД в S3 яндекса.
Wal-g можно использовать в качестве инструмента для создания зашифрованных, сжатых резервных копий PostgreSQL (полных и инкрементных) и отправки/извлечения их в/из удаленных хранилищ без сохранения их в вашей файловой системе.
В данном примере показан темстовый процесс с минимальным набором параметров.

## Основные особенности
- Образ PostgreSQL 13 (и более) с предустановленным WAL-G 
- Настроенный S3 хранилище для бэкапов
- Автоматическая настройка WAL archiving в конфигурации postgres
- Готовые скрипты для инициализации и бэкапов (позже будет отдельный образ для разворачивания с бэкапом)

## Обязательные шаги перед использованием

1) Создать все переменные, как в образце .env
2) Создать бакет в S3 yandex cloud (или любом другом, можно Minio на другом сервере) и создать сервисный аккаунт с ролью storage.editor
3) Создать статический ключ для этого аккаунта, сохранить id и secret.

![image](https://github.com/user-attachments/assets/033e07a8-0ce3-4e50-94d2-f0e095a4cd7a)

## Порядок разворачивания

Для инициализации БД создаем проект в директории
```
postgres/
├── docker-compose.yaml 
├── .env
├── dockerfile 
├── init-wal-g.sh  
└── backup.sh
```

**Особенности Dockerfile**:
  - Официальный образ PostgreSQL 13
  - Устанавливает Go и WAL-G и его зависимости.
  - Копирует скрипты инициализации `init-wal-g.sh` (автоматическое выполнение при запуске и изменение `postgresql.conf` для бэкапа) и резервного копирования `backup.sh` (скрипт бэкапа для крона).

**Необходимые параметры `postgresql.conf`**
```
wal_level = replica
archive_mode = on
archive_command = 'wal-g wal-push %p'
restore_command = 'wal-g wal-fetch %f %p'
archive_timeout = 28800 #(на время тестов поставил больший интервал, для экономии места)
```
Далее выполняем команды и убеждаемся, что контейнер с БД запустился, при проблемах смотрим логи
```
docker compose build
docker compose up -d 
```
Проверяем конфиг и что скрипт инициализации отработал
```
docker compose exec -it postgres psql -U postgres -d postgres_db -c "SHOW archive_mode;"
```
![image](https://github.com/user-attachments/assets/b9569131-6869-4b8e-8832-190ef7c43b23)
Заходим в контейнер
```
docker compose exec -it postgres psql -U postgres -d postgres_db
```
Создаем тестовые данные
```
CREATE TABLE test (id SERIAL PRIMARY KEY, data TEXT);
INSERT INTO test (data) VALUES ('Тестируем бэкап');
SELECT * FROM test;
```
Выходим из контейнера и создаем бэкап в S3 командой
```
docker compose exec -it -u postgres postgres wal-g backup-push /var/lib/postgresql/data
```
![image](https://github.com/user-attachments/assets/7ff2f769-1fde-40cf-93de-7d0ccea4c322)

Убедимся, что в хранилище данные заружены (name base_000000010000000000000025):
![image](https://github.com/user-attachments/assets/a317ceda-90c1-4fdc-97b4-22d51f342085)

Так же можно посмотреть список версий в терминале
```
docker compose exec -it postgres wal-g backup-list
```
**Настройка cron**

Добавляем в крон строку (скрипт будет выполняться раз в сутки в 03.00)
```
0 3 * * * docker exec postgrestest /usr/local/bin/backup.sh >> /home/vitaliyaleks/cron.log 2>&1
```
После 03.00 можем теперь посмотреть логи в cron.log
![image](https://github.com/user-attachments/assets/fd8b404c-84fa-41ce-94cb-1ae2e1b2cd7f)


## Порядок восстановления

На текщий момент будет описана последовательность действий для восстановления, но в планах сделать готовый образ с автоматическим скриптом разворачивания.
Основной особенностью, стоить отметить, необходимость остановки posgres и очистку директории (если тесты в пределах одного сервера, лучше удалить то и контейнер с которого делали бэкап).
Можем взять тот же образ (предварительно закоментировав там используемые в первой части скрипты), повторяем все шаги.
```
postgresbackup/
├── docker-compose.yaml 
├── .env
└── dockerfile
```
Изначально разворачиваем БД (например с именем postgresbackup) с пустым томом, зайдем внутрь, остановим postgres и после останавливаем контейнер!!!
```
docker compose exec -u postgres postgresbackup bash
pg_ctl stop
docker compose stop postgresbackup
```
Теперь нам необходимо запустить контейнер под пользователем postgres с оболочкой bash (можем дополнительно убедиться что процесов postgres нет `ps aux | grep postgres`).  
```
docker compose run --rm -it -u postgres postgresbackup bash
```
Внутри контейнера чистим директорию, проверяем, что все удалилось, загружаем последнюю версию бэкапа, создаем recovery.signal для инициализации процесса восстановления, выходим и делаем рестарт контейнеру, что бы была произведена инициализация бэкапа.
```
rm -rf /var/lib/postgresql/data/*
ls -la /var/lib/postgresql/data
wal-g backup-fetch /var/lib/postgresql/data LATEST
touch /var/lib/postgresql/data/recovery.signal
exit
```
```
docker compose start postgresbackup
```
После старта, заходим в этот контейнер и проверяем наши данные)
```
docker compose exec -it postgresbackup psql -U postgres -d postgres_db
postgres_db=# SELECT * FROM test;
```
![image](https://github.com/user-attachments/assets/03aea22a-7fd2-4a05-b1fe-1dad92e3eb58)

