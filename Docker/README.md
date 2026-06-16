---
title: "Docker Project"
description: "A project to set up a multi-container architecture in Docker"
---
# Basic Docker Project (Multi-Container Infrastructure)

## Описание проекта
В рамках данного проекта была спроектирована и развернута переносимая инфраструктура для веб-сервиса. Были проработаны механизмы кастомной сборки образов через `Dockerfile`, организация изолированных сетей `Docker Network`, менеджмент постоянных данных через `Volumes`, а также оркестрация и автоматизация через `Docker Compose`.

Проект структурно разделен на 3 связанных контейнера:
1. **Nginx Web Server** — кастомный контейнер веб-сервера, отдающий статический контент и транслирующий метрики производительности.
2. **Log Parser** — легковесный утилитарный контейнер, запускающийся по расписанию (`cron`) для анализа логов веб-сервера и отправки отчетов на удаленный сервер.
3. **Netdata Monitoring** — контейнер комплексного мониторинга, отслеживающий как состояние хост-системы, так и внутренние метрики Nginx в реальном времени.

---

## Архитектура сети проекта
Для обеспечения сетевой связности и изоляции контейнеров используется кастомный сетевой драйвер. Использование внутренней сети позволяет контейнерам обращаться друг к другу по их системным именам (контейнерным хостам) благодаря встроенному в Docker DNS-серверу.

Создание сети вручную для `docker run`:
```bash
docker network create my_monitoring_net

```

---

## Детальное описание компонентов

### 1. Веб-сервер Nginx

В качестве основы был взят проект статического сайта. Конфигурация Nginx (`site1.conf`) была модернизирована под стандарты контейнеризации:

* Порт изменен на внутренний `80` (вместо хостового `8081`), так как изоляция портов теперь управляется на уровне Docker.
* Изменен путь логирования: `access_log /mylogs/nginx-access.log;` для последующего маппинга на постоянный том.
* Добавлен эндпоинт метрик для мониторинга:

```nginx

location /stub_status {
    stub_status;
    allow all; # Разрешено, так как доступ ограничен изолированной сетью Docker
}

```



#### Dockerfile для Nginx:

```dockerfile
FROM nginx:alpine # Использование кастомного легковесного дистрибутива Alpine Linux
RUN rm /etc/nginx/conf.d/default.conf # Удаление дефолтной конфигурации приветственной страницы
COPY ./site1.conf /etc/nginx/conf.d/ # Внедрение оптимизированного конфига
COPY ./site1/ /usr/share/nginx/html/ # Копирование статических файлов сайта
EXPOSE 80

```

#### Запуск в ручном режиме:

```bash
docker run -d --name my-running-site1 \
  --network my_monitoring_net \
  -p 8081:80 \
  -v /home/zakerru/containering/pod1/logs:/mylogs \
  site1-image

```

### 2. Log Parser (Сайдкар-скрипт)

Контейнер предназначен для автоматической обработки логов доступа Nginx. В конец bash-скрипта парсинга добавлена интеграция с внешним API для отправки сформированных отчетов:

```bash
curl -F "file=@$REPORT_FILE" http://192.168.1.180:5000/upload

```

#### Запуск в ручном режиме:

Контейнер работает в эфемерном режиме (флаг `--rm` автоматически уничтожает контейнер после выполнения скрипта, не забивая диск устройства):

```bash
docker run --rm -v ~/containering/pod1/logs:/logs my-parser

```

Данная команда интегрируется в системный `cron` хост-машины для ежедневного выполнения.

### 3. Мониторинг Netdata

Для данного компонента **Dockerfile отсутствует**. Мониторинг разворачивается напрямую из официального готового образа `netdata/netdata`. Это обусловлено тем, что инструмент предоставляет избыточную конфигурацию «из коробки», а его кастомизация (подключение к Nginx) реализуется не сборкой нового слоя, а динамическим пробросом файлов конфигурации через тома (`Volumes`), что соответствует концепции разделения логики приложения и его настроек.

Для мониторинга Nginx внутри изолированной сети в файл `nginx.conf` для Netdata добавлен джоб, использующий имя контейнера как DNS-хост:

```yaml
jobs:
  - name: site1_stats
    url: http://my-running-site1/stub_status

```

#### Запуск в ручном режиме:

```bash
docker run -d --name netdata \
  --network my_monitoring_net \
  -p 19999:19999 \
  # Проброс системных директорий хоста в режиме Read-Only (ro) для сбора метрик «железа», а не самого контейнера Netdata:
  -v /proc:/host/proc:ro \
  -v /sys:/host/sys:ro \
  -v /etc/os-release:/host/etc/os-release:ro \
  # Доступ к сокету Докера для мониторинга статуса соседних контейнеров:
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  # Внедрение пользовательских конфигураций:
  -v /home/zakerru/containering/netdatadoc/nginx.conf:/etc/netdata/go.d/nginx.conf \
  -v /home/zakerru/containering/netdatadoc/netdata.conf:/etc/netdata/netdata.conf \
  netdata/netdata

```

---

## Автоматизация декларативного развертывания (Docker Compose)

Для объединения всех компонентов в единый стек, управления зависимостями и автоматизации развертывания был разработан манифест `docker-compose.yml`.

### Преимущества перехода на Docker Compose относительно ручного запуска:

1. **Автоматическое создание сети:** Больше не требуется предварительно создавать сеть руками через CLI, Compose поднимает изолированную сеть для проекта по умолчанию.
2. **Именованные тома (Named Volumes):** Вместо жестко прописанных путей хоста (Bind Mounts) логи вынесены в абстракцию Докера, что делает проект **100% переносимым** на любую другую машину.
3. **Отказоустойчивость:** Добавлены политики перезапуска при падениях.
4. **Защита хоста от переполнения:** Настроены жесткие лимиты на логирование.
5. **Контроль доступности (Healthchecks):** Инфраструктура теперь следит не просто за активностью процесса, а за реальным ответом веб-сервера.

```yaml
services:
  nginx:
    build: ./pod1/site1doc            # Автоматический билд образа при запуске стека
    container_name: my-running-site1
    ports:
      - "8081:80"
    volumes:
      - nginx_logs:/mylogs            # Использование переносимого именованного тома вместо жесткого пути
    restart: unless-stopped           # Автоматический перезапуск контейнера, если он упал с ошибкой
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost"] # Проверка реальной работоспособности сайта изнутри
      interval: 30s                                   # Интервал проверки
      timeout: 10s                                    # Время ожидания ответа
      retries: 3                                      # Количество попыток перед присвоением статуса Unhealthy
    logging:                          # Ограничение размера логов докера (защита диска от переполнения)
      driver: "json-file"
      options:
        max-size: "10m"               # Максимальный размер одного файла лога
        max-file: "3"                 # Максимальное количество ротируемых файлов

  netdata:
    image: netdata/netdata
    container_name: netdata
    ports:
      - "19999:19999"
    volumes:
      # Проброс системных метрик Linux-хоста
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /etc/os-release:/host/etc/os-release:ro
      - /var/run/docker.sock:/var/run/docker.sock:ro
      # Относительные пути (Relative Paths) для конфигов мониторинга — проект готов к переносу в любую директорию
      - ./netdatadoc/nginx.conf:/etc/netdata/go.d/nginx.conf
      - ./netdatadoc/netdata.conf:/etc/netdata/netdata.conf
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
    restart: unless-stopped
    depends_on:
      - nginx                         # Netdata начнет запуск только после того, как поднимется контейнер Nginx

volumes:
  nginx_logs:                         # Декларация общего именованного тома для логов

```

## Итоги проекта и вектор развития

Разработанная архитектура (комбинация основного веб-сервера и парсера логов через общее хранилище данных) является классическим паттерном проектирования высоконагруженных систем — **Sidecar pattern**. Полученные навыки управления контейнеризацией, конфигурации сетевых эндпоинтов и разделения данных ложатся в основу следующего этапа обучения — проектирования и развертывания production-ready кластера в оркестраторе **Kubernetes (K8s)**.

---

# Basic Docker Project (Multi-Container Infrastructure)

## Project Description
This project involved designing and deploying a portable infrastructure for a web service. Mechanisms for custom image assembly via Dockerfile, organization of isolated Docker Networks, persistent data management via Volumes, and orchestration and automation via Docker Compose were developed.

The project is structurally divided into three interconnected containers:
1. Nginx Web Server — a custom web server container that serves static content and broadcasts performance metrics.
2. Log Parser — a lightweight utility container that runs on a schedule (cron) to analyze web server logs and send reports to a remote server.
3. Netdata Monitoring — a comprehensive monitoring container that monitors both the host system status and internal Nginx metrics in real time.

---

## Project Network Architecture
A custom network driver is used to provide network connectivity and container isolation. Using the internal network, containers can access each other by their system names (container hosts) thanks to Docker's built-in DNS server.

Manually create a network for `docker run`:
```bash
docker network create my_monitoring_net

```

---

## Detailed Description of Components

### 1. Nginx Web Server

A static server site project was used as a basis. The Nginx configuration (`site1.conf`) has been modernized to meet containerization standards:

* The port has been changed to internal `80` (instead of the host `8081`), since port isolation is now managed at the Docker level.
* The logging path has been changed: `access_log /mylogs/nginx-access.log;` for subsequent mapping to a persistent volume.
* Added a metrics endpoint for monitoring:

```nginx

location /stub_status {
stub_status;
allow all; # Allowed because access is restricted to an isolated Docker network
}

```

#### Dockerfile for Nginx:

```dockerfile
FROM nginx:alpine # Using a custom lightweight Alpine Linux distribution
RUN rm /etc/nginx/conf.d/default.conf # Removing the default welcome page configuration
COPY ./site1.conf /etc/nginx/conf.d/ # Implementing an optimized configuration
COPY ./site1/ /usr/share/nginx/html/ # Copying static site files
EXPOSE 80

```

#### Running in manual mode:

```bash
docker run -d --name my-running-site1 \
--network my_monitoring_net \
-p 8081:80 \
-v /home/zakerru/containering/pod1/logs:/mylogs \
site1-image

```

### 2. Log Parser (Sidecar script)

This container is designed for automatic processing of Nginx access logs. An external API integration for sending generated reports has been added to the end of the bash parsing script:

```bash
curl -F "file=@$REPORT_FILE" http://192.168.1.180:5000/upload

```

#### Manual launch:

The container runs in ephemeral mode (the `--rm` flag automatically destroys the container after script execution, without consuming disk space):

```bash
docker run --rm -v ~/containering/pod1/logs:/logs my-parser

```

This command is integrated into the host machine's system cron for daily execution.

### 3. Netdata Monitoring

There is no **Dockerfile** for this component. Monitoring is deployed directly from the official pre-built `netdata/netdata` image. This is because the tool provides redundant configuration out of the box, and its customization (connection to Nginx) is implemented not by building a new layer, but by dynamically forwarding configuration files through volumes, which is consistent with the concept of separating application logic from its settings.

To monitor Nginx within an isolated network, a job has been added to the Netdata nginx.conf file that uses the container name as the DNS host:

```yaml
jobs:
- name: site1_stats
url: http://my-running-site1/stub_status

```

#### Starting in manual mode:

```bash
docker run -d --name netdata \
--network my_monitoring_net \
-p 19999:19999 \
# Forwarding host system directories in Read-Only (ro) mode to collect hardware metrics, not the Netdata container itself:
-v /proc:/host/proc:ro \
-v /sys:/host/sys:ro \
-v /etc/os-release:/host/etc/os-release:ro \
# Access to the Docker socket to monitor the status of neighboring servers Containers:
-v /var/run/docker.sock:/var/run/docker.sock:ro \
# Injecting custom configurations:
-v /home/zakerru/containering/netdatadoc/nginx.conf:/etc/netdata/go.d/nginx.conf \
-v /home/zakerru/containering/netdatadoc/netdata.conf:/etc/netdata/netdata.conf \
netdata/netdata

```

---

## Declarative Deployment Automation (Docker Compose)

To consolidate all components into a single stack, manage dependencies, and automate deployment, the `docker-compose.yml` manifest was developed.

### Benefits of switching to Docker Compose over manual deployment:

1. **Automatic network creation:** You no longer need to manually create a network via the CLI; Compose sets up an isolated network for the project by default.
2. **Named Volumes:** Instead of hard-coded host paths (Bind Mounts), logs are abstracted into a Docker framework, making the project **100% portable** to any other machine.
3. **Fault Tolerance:** Restart policies for crashes have been added.
4. **Host Overflow Protection:** Strict logging limits have been configured.
5. **Health Checks:** The infrastructure now monitors not just process activity, but the actual web server response.

```yaml
services:
nginx:
build: ./pod1/site1doc # Automatically build the image when the stack starts
container_name: my-running-site1
ports:
- "8081:80"
volumes:
- nginx_logs:/mylogs # Use a portable named volume instead of a hardcoded path
restart: unless-stopped # Automatically restart the container if it crashes with an error
healthcheck:
test: ["CMD", "curl", "-f", "http://localhost"] # Check the actual health of the site from the inside
interval: 30s # Check interval
timeout: 10s # Timeout for a response
retries: 3 # Number of retries before assigning the Unhealthy status
logging: # Limit the size of Docker logs (protects against disk overflow)
driver: "json-file"
options:
max-size: "10m" # Maximum size of a single file Log
max-file: "3" # Maximum number of rotated files

netdata:
image: netdata/netdata
container_name: netdata
ports:
- "19999:19999"
volumes:
# Forwarding Linux host system metrics
- /proc:/host/proc:ro
- /sys:/host/sys:ro
- /etc/os-release:/host/etc/os-release:ro
- /var/run/docker.sock:/var/run/docker.sock:ro
# Relative paths for monitoring configurations — the project can be moved to any directory
- ./netdatadoc/nginx.conf:/etc/netdata/go.d/nginx.conf
- ./netdatadoc/netdata.conf:/etc/netdata/netdata.conf
logging:
driver: "json-file"
options:
max-size: "10m"
max-file: "3"
restart: unless-stopped
depends_on:
- nginx # Netdata will only start after the Nginx container is up

volumes:
nginx_logs: # Declaration of a shared named volume for logs

```

## Project Results and Future Directions

The developed architecture (a combination of a main web server and a log parser via a shared data store) is a classic design pattern for high-load systems—the Sidecar pattern. The acquired skills in containerization management, network endpoint configuration, and data separation form the basis for the next stage of training—designing and deploying a production-ready cluster in the Kubernetes (K8s) orchestrator.

---
### Project file list:
- [docker-compose.yml](https://github.com/Zakerru/Roadmap-sh-devops-projects/blob/main/Docker/project-files/docker-compose.yml)
- [netdata.conf](https://github.com/Zakerru/Roadmap-sh-devops-projects/blob/main/Docker/project-files/netdatadoc/netdata.conf)
- [nginx.conf](https://github.com/Zakerru/Roadmap-sh-devops-projects/blob/main/Docker/project-files/netdatadoc/nginx.conf)
- [Nginx Dockerfile](https://github.com/Zakerru/Roadmap-sh-devops-projects/blob/main/Docker/project-files/pod1/site1doc/Dockerfile)
- [site1.conf](https://github.com/Zakerru/Roadmap-sh-devops-projects/blob/main/Docker/project-files/pod1/site1doc/site1.conf)
- [Parcer Dockerfile](https://github.com/Zakerru/Roadmap-sh-devops-projects/blob/main/Docker/project-files/pod1/parcerdoc/Dockerfile)
- [parcer.sh](https://github.com/Zakerru/Roadmap-sh-devops-projects/blob/main/Docker/project-files/pod1/parcerdoc/parcer.sh)

