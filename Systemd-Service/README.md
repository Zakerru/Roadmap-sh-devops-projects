---
layout: default
title: Server Performance Stats
---

# SYSTEMD SERVICE

Для выполнения данного проекта я решил организовать работу предыдущего проекта (simple monitoring) при помощи сервиса systemd

### Шаг 1: Настройка оркестратора (`workflow.sh`)

Для того что бы данный скрипт смог стать полноценным демоном системы его потребовалось доработать. 
Главный скрипт читает JSON, передает параметры в `alerting.sh`, а затем записывает новые состояния обратно.
В скрипт встроена **регулярная проверка (Regex)** для защиты парсера `jq` от непредвиденных ошибок:

```bash
# Защита от непредвиденного вывода скрипта проверки
if [[ ! "$STATES" =~ ^[0-1]\ [0-1]\ [0-1]$ ]]; then
    echo "ERROR - Unexpected output from alerting.sh: $STATES"
    continue # Безопасный пропуск итерации без повреждения JSON
fi

```
Так же, для того что бы при запуске скрипта через сервис systemd логи не были пустыми, в нескольких местах добавлена команда `echo`, вывод которой и будет в последующем попадать в логи systemd.

### Шаг 2: Регистрация systemd-службы

Создан файл службы в директории systemd - `systemd_monitoring.service` содержащий:

```ini
[Unit]
Description=Simple Monitoring Orchestrator
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/bin/bash /путь/workflow.sh
Restart=always
RestartSec=10
User=seriojka

[Install]
WantedBy=multi-user.target

```
Данная конфигурация запускает скрипт только после запуска сетевых служб и требует их работы, а так же перезапускает скрипт если он перестает работать по каким-то причинам.
---

## Команды управления

После создания юнит-файла необходимо перезагрузить конфигурацию systemd и запустить сервис:

* **Перечитать конфиги systemd:**
`sudo systemctl daemon-reload`
* **Добавить службу в автозагрузку:**
`sudo systemctl enable simple-monitoring.service`
* **Запустить службу:**
`sudo systemctl start simple-monitoring.service`
* **Проверить статус:**
`sudo systemctl status simple-monitoring.service`

**Просмотр логов:**
Система автоматически собирает логи всех `echo` из bash-скриптов. Посмотреть их в реальном времени можно через journalctl:

```bash
# Просмотр логов сервиса в реальном времени (режим слежения)
journalctl -u simple-monitoring.service -f

```

---

# SYSTEMD SERVICE

To implement this project, I decided to manage the operation of the previous project (simple monitoring) using a systemd service.

### Step 1: Configuring the Orchestrator (`workflow.sh`)

To enable this script to function as a fully-fledged system daemon, it required some modifications.
The main script reads a JSON file, passes parameters to `alerting.sh`, and then writes the new states back to the file.
A **regular expression check (Regex)** has been built into the script to protect the `jq` parser from unexpected errors:

```bash
# Protection against unexpected output from the check script
if [[ ! "$STATES" =~ ^[0-1]\ [0-1]\ [0-1]$ ]]; then
echo "ERROR - Unexpected output from alerting.sh: $STATES"
continue # Safely skip the iteration without corrupting the JSON data
fi

```
Additionally, to ensure that the logs are not empty when the script is launched via the systemd service, `echo` commands were added at several points; the output of these commands will subsequently be captured in the systemd logs.

### Step 2: Registering the systemd Service

A service file named `systemd_monitoring.service` was created within the systemd directory, containing the following configuration:

```ini
[Unit]
Description=Simple Monitoring Orchestrator
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/bin/bash /path/to/workflow.sh
Restart=always
RestartSec=10
User=seriojka

[Install]
WantedBy=multi-user.target

```
This configuration ensures that the script launches only after the network services have started and requires them to be operational; it also automatically restarts the script should it stop running for any reason. ---

## Management Commands

After creating the unit file, you must reload the systemd configuration and start the service:

* **Reload systemd configuration:**
`sudo systemctl daemon-reload`
* **Enable the service to start automatically:**
`sudo systemctl enable simple-monitoring.service`
* **Start the service:**
`sudo systemctl start simple-monitoring.service`
* **Check status:**
`sudo systemctl status simple-monitoring.service`

**Viewing Logs:**
The system automatically collects logs for all `echo` commands within the Bash scripts. You can view them in real-time using `journalctl`:

```bash
# View service logs in real-time (follow mode)
journalctl -u simple-monitoring.service -f

```

---
### Project files:
- [systemd_monitoring.service](https://github.com/Zakerru/Roadmap-sh-devops-projects/blob/main/Systemd-Service/systemd_monitoring.service)
