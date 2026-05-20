---
layout: default
title: Simple monitoring
---

# Simple Monitoring

Данный проект выполнен в рамках практической задачи из [roadmap.sh](https://roadmap.sh/projects/simple-monitoring-dashboard). 
Цель проекта — изучение системы мониторинга **Netdata**, а также освоение DevOps-практик: автоматизации установки, конфигурации, тестирования (нагрузки) и безопасного удаления программного обеспечения в масштабируемых инфраструктурах. 

В качестве основного метода оповещения (алертинга) были выбраны автоматические уведомления через ботов в **Telegram** и **Discord**. Для тестирования этой механики и работы с секретами GitHub Actions проект был разделен на две логические части: мини-проект (внешний мониторинг) и основной проект (внутренний мониторинг инфраструктуры).

---

## Часть 1: Внешний мониторинг (GitHub Pages + Actions)

В качестве первичной цели для тестирования алертинга был выбран статический сайт, развернутый на GitHub Pages. Задача заключалась в настройке автоматического уведомления при недоступности ресурса.

1. **Интеграция с мессенджерами:** Были изучены API и механики работы ботов в Telegram и Discord. Для Telegram был создан бот (получен токен и Chat ID). В случае с Discord было принято решение использовать **Webhooks** для конкретного канала, что оказалось значительно более удобным и быстрым решением, чем создание полноценного бота. Все креды были безопасно скрыты в GitHub Secrets.
2. **Скрипт проверок (`health-check.sh`):**
   Написан Bash-скрипт, выполняющий `curl`-запросы к сайту для получения HTTP-кодов ответа и времени отклика. При обнаружении аномалий (код != 200) скрипт формирует и отправляет POST-запросы к API Telegram/Discord, используя переменные окружения (`${TG_TOKEN}`, `${TG_CODE}`, `${DS_WEBHOOK}`).
3. **Автоматизация CI/CD:**
   Создан workflow `.github/workflows/monitoring.yml`. По расписанию (cron) раз в 30 минут GitHub Actions поднимает runner, подтягивает секреты и запускает скрипт `health-check.sh`.

> **Вывод по 1 этапу:** Использование Discord Webhooks оказалось более элегантным и удобным методом для системных уведомлений по сравнению с классическими Telegram-ботами.

---

## Часть 2: Внутренний мониторинг (Netdata + Nginx)

Основная часть проекта реализовывалась на базе виртуальной машины (VirtualBox) с предварительно настроенным веб-сервером Nginx.

### 2.1. Установка и базовая настройка Netdata
Netdata был установлен через официальный kickstart-скрипт:
```bash
wget -O /tmp/netdata-kickstart.sh [https://get.netdata.cloud/kickstart.sh](https://get.netdata.cloud/kickstart.sh) && sh /tmp/netdata-kickstart.sh

```

Был изучен механизм конфигурации override. Вместо редактирования дефолтных настроек, в пустой файл `/etc/netdata/netdata.conf` были добавлены кастомные параметры обновления метрик и хранения истории:

```ini
[global]
    update every = 3
    history = 7200
[plugin:proc]
    update every = 6

```

### 2.2. Интеграция Nginx в мониторинг

Для сбора статистики веб-сервера был активирован модуль `stub_status` в конфигурации Nginx (`/etc/nginx/sites-available/site1`). Затем для агента Netdata был создан конфигурационный файл `/etc/netdata/go.d/nginx.conf`, указывающий на локальный эндпоинт Nginx. После перезапуска сервисов в дашборде Netdata появился новый чарт с метриками подключений.

---

## Архитектура автоматизации и алертинга

Вместо примитивной настройки алертинга локально на каждом сервере, была спроектирована и реализована централизованная архитектура **Master-Node (Pull-модель)**.

### Преимущества выбранной архитектуры:

* **Единая точка управления:** Конфигурация порогов срабатывания (thresholds), логика алертинга и списки целевых серверов хранятся только на Master-сервере. Не нужно подключаться по SSH к десяткам машин для изменения одного параметра.
* **Снижение нагрузки на узлы:** Целевые сервера (Nodes) занимаются исключительно сбором метрик. Вычисления, парсинг JSON и отправка вебхуков происходят на Master-сервере.
* **Предотвращение спама (State Management):** Архитектура позволяет хранить состояние каждой метрики каждого сервера (Активен/Упал). Если значение метрики аномальное, алерт отправляется один раз, а не каждую секунду. При восстановлении показателей отправляется сообщение "Recovery".
* **Масштабируемость:** Добавление нового сервера в мониторинг сводится к добавлению одного блока в конфигурационный JSON-файл на Master-сервере.

### Компоненты системы (Скрипты)

1. **`installer.sh` (Узел)**
Скрипт для целевых серверов. Автоматически устанавливает Netdata, редактирует конфиги Nginx (через `sed`), настраивает плагины и перезапускает службы.
2. **`servers.json` (База данных Master-сервера)**
Конфигурационный файл, хранящий IP-адреса узлов, индивидуальные URL вебхуков и текущие "стейты" (состояния) алертов для предотвращения спама. Легко расширяется для любых новых метрик.
3. **`alerting.sh` (Обработчик)**
Скрипт получает данные из `servers.json`, делает API-запрос к нужному серверу:
`curl -s "http://${TARGET_IP}:19999/api/v1/data?chart=${chart}&after=-${seconds}&points=1&group=average&format=json"`
Скрипт парсит ответ, сравнивает с заданными порогами (RAM, CPU, Nginx Connections) и, учитывая текущий стейт, принимает решение об отправке вебхука.
4. **`workflow.sh` (Оркестратор)**
Демон, работающий в бесконечном цикле (каждые 10 секунд). Проходится по всем IP из `servers.json`, запускает `alerting.sh` и перезаписывает обновленные стейты обратно в JSON.
5. **`stresstest.sh` (Тестирование)**
Скрипт для симуляции боевой нагрузки на узлы. Устанавливает `stress` и `apache2-utils`. Поддерживает выборочный запуск через флаги (`-cpu`, `-ram`, `-nginx`).
6. **`uninst.sh` (Очистка)**
Скрипт-деинсталлятор. Корректно удаляет агента Netdata, очищает остаточные файлы, вырезает блок мониторинга из конфигурации Nginx (возвращая её в первозданный вид) и удаляет утилиты стресс-тестирования.

---

## Результаты и освоенные навыки

В процессе работы над данным проектом я значительно улучшил свои навыки в системном администрировании и автоматизации, в частности:

* **API и Observability:** Изучил принципы работы REST API (на примере Netdata API) для извлечения сырых телеметрических данных и вычисления средних значений (Average) за промежутки времени.
* **Архитектурное мышление:** Понял разницу между Push и Pull моделями мониторинга, научился проектировать Master-Node системы и работать с концепцией сохранения состояний (State management) для идемпотентности процессов.
* **DevOps Best Practices:** Усвоил принцип "инфраструктура как код" (IaC) на уровне Bash — скрипты сами устанавливают зависимости, настраивают систему, проводят проверки (`nginx -t`) и бесследно убирают за собой мусор (`autoremove`, `purge`).
* **Интеграции и CI/CD:** Научился работать с GitHub Actions, безопасно управлять секретами и настраивать интеграции систем оповещения через Webhooks.

---

# Simple Monitoring

This project was undertaken as a practical exercise based on a task from [roadmap.sh](https://roadmap.sh/projects/simple-monitoring-dashboard).
The project's goal is to explore the **Netdata** monitoring system, as well as to master DevOps practices: specifically, the automation of software installation, configuration, testing (including load testing), and secure removal within scalable infrastructure environments.

For the primary alerting method, automated notifications via **Telegram** and **Discord** bots were selected. To test this mechanism—and to practice handling secrets within GitHub Actions—the project was divided into two logical parts: a mini-project (external monitoring) and the main project (internal infrastructure monitoring).

---

## Part 1: External Monitoring (GitHub Pages + Actions)

A static website deployed on GitHub Pages was chosen as the initial target for testing the alerting system. The objective was to configure automated notifications in the event that the resource became unavailable.

1. **Messenger Integration:** The APIs and operational mechanics of bots for Telegram and Discord were studied. For Telegram, a dedicated bot was created (yielding a token and Chat ID). For Discord, the decision was made to utilize **Webhooks** targeting a specific channel; this proved to be a significantly more convenient and faster solution than creating a full-fledged bot. All credentials were securely stored within GitHub Secrets.
2. **Health Check Script (`health-check.sh`):**
A Bash script was written to execute `curl` requests against the website, retrieving HTTP response codes and response times. Upon detecting any anomalies (specifically, a response code other than 200), the script constructs and sends POST requests to the Telegram/Discord APIs, utilizing environment variables (`${TG_TOKEN}`, `${TG_CODE}`, `${DS_WEBHOOK}`).
3. **CI/CD Automation:**
A workflow file—`.github/workflows/monitoring.yml`—was created. On a schedule (via cron), every 30 minutes, GitHub Actions spins up a runner, fetches the necessary secrets, and executes the `health-check.sh` script.

> **Conclusion for Phase 1:** Using Discord Webhooks proved to be a more elegant and convenient method for system notifications compared to traditional Telegram bots.

---

## Part 2: Internal Monitoring (Netdata + Nginx)

The core of the project was implemented on a virtual machine (VirtualBox) featuring a pre-configured Nginx web server.

### 2.1. Netdata Installation and Basic Configuration
Netdata was installed using the official kickstart script:
```bash
wget -O /tmp/netdata-kickstart.sh [https://get.netdata.cloud/kickstart.sh](https://get.netdata.cloud/kickstart.sh) && sh /tmp/netdata-kickstart.sh

```

The configuration override mechanism was explored. Instead of editing the default settings, custom parameters for metric update intervals and history retention were added to an empty `/etc/netdata/netdata.conf` file:

```ini
[global]
update every = 3
history = 7200
[plugin:proc]
update every = 6

```

### 2.2. Integrating Nginx into Monitoring

To collect web server statistics, the `stub_status` module was enabled within the Nginx configuration (`/etc/nginx/sites-available/site1`). Subsequently, a configuration file—`/etc/netdata/go.d/nginx.conf`—was created for the Netdata agent, pointing to the local Nginx endpoint. After restarting the services, a new chart displaying connection metrics appeared on the Netdata dashboard. 

---

## Automation and Alerting Architecture

Instead of relying on primitive, localized alerting configurations on each individual server, a centralized **Master-Node (Pull Model)** architecture was designed and implemented.

### Advantages of the Chosen Architecture:

* **Single Point of Control:** Configuration of alert thresholds, alerting logic, and lists of target servers are stored exclusively on the Master server. There is no need to SSH into dozens of machines just to modify a single parameter.
* **Reduced Node Load:** Target servers (Nodes) focus solely on metric collection. All computations, JSON parsing, and webhook dispatching take place on the Master server.
* **Spam Prevention (State Management):** The architecture allows for tracking the state of every metric for every server (Active/Down). If a metric value becomes anomalous, an alert is sent only once—rather than every second. A "Recovery" message is sent once the metric values ​​return to normal.
* **Scalability:** Adding a new server to the monitoring system simply requires adding a single block to the configuration JSON file on the Master server.

### System Components (Scripts)

1. **`installer.sh` (Node)**
A script designed for target servers. It automatically installs Netdata, modifies Nginx configuration files (using `sed`), configures plugins, and restarts relevant services.
2. **`servers.json` (Master Server Database)**
A configuration file that stores Node IP addresses, unique webhook URLs, and the current "states" of alerts to prevent spamming. It is easily extensible to accommodate any new metrics. 
3. **`alerting.sh` (Handler)**
The script retrieves data from `servers.json` and makes an API request to the target server:
`curl -s "http://${TARGET_IP}:19999/api/v1/data?chart=${chart}&after=-${seconds}&points=1&group=average&format=json"`

The script parses the response, compares it against predefined thresholds (RAM, CPU, Nginx Connections), and—taking the current state into account—decides whether to trigger a webhook notification.
4. **`workflow.sh` (Orchestrator)**
A daemon running in an infinite loop (executing every 10 seconds). It iterates through all IP addresses listed in `servers.json`, launches `alerting.sh`, and writes the updated states back to the JSON file.
5. **`stresstest.sh` (Testing)**
A script designed to simulate production-level workloads on the nodes. It installs the `stress` and `apache2-utils` packages. It supports selective execution via command-line flags (`-cpu`, `-ram`, `-nginx`).
6. **`uninst.sh` (Cleanup)**
An uninstallation script. It cleanly removes the Netdata agent, purges residual files, removes the monitoring block from the Nginx configuration (restoring it to its original state), and uninstalls the stress-testing utilities.

---

## Results and Acquired Skills

While working on this project, I significantly enhanced my skills in system administration and automation, specifically in the following areas:

* **API and Observability:** I gained an understanding of REST API principles (specifically using the Netdata API) for extracting raw telemetry data and calculating time-averaged metrics.
* **Architectural Thinking:** I grasped the distinction between Push and Pull monitoring models, learned how to design Master-Node systems, and mastered the concept of state management to ensure process idempotency.
* **DevOps Best Practices:** I internalized the "Infrastructure as Code" (IaC) principle at the Bash scripting level—the scripts automatically install dependencies, configure the system, perform validation checks (`nginx -t`), and clean up after themselves without leaving any traces (`autoremove`, `purge`). 
* **Integrations and CI/CD:** Learned to work with GitHub Actions, securely manage secrets, and configure alerting system integrations via Webhooks.

---
### Project file list:
- [alerting.sh](https://github.com/Zakerru/Roadmap-sh-devops-projects/blob/main/simple-monitoring/alerting.sh)
- [health-check.sh](https://github.com/Zakerru/Roadmap-sh-devops-projects/blob/main/simple-monitoring/health-check.sh)
- [workflow.sh](https://github.com/Zakerru/Roadmap-sh-devops-projects/blob/main/simple-monitoring/workflow.sh)
- [installer.sh](https://github.com/Zakerru/Roadmap-sh-devops-projects/blob/main/simple-monitoring/installer.sh)
- [stresstest.sh](https://github.com/Zakerru/Roadmap-sh-devops-projects/blob/main/simple-monitoring/stresstest.sh)
- [uninst.sh](https://github.com/Zakerru/Roadmap-sh-devops-projects/blob/main/simple-monitoring/uninst.sh)
- [servers.json](https://github.com/Zakerru/Roadmap-sh-devops-projects/blob/main/simple-monitoring/servers.json)
- [monitoring.yml](https://github.com/Zakerru/Roadmap-sh-devops-projects/tree/main/.github/workflows/monitoring.yml)
