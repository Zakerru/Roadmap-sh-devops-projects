---
title: "Prometheus + Grafana project"
description: "Configuring monitoring project"
---

# Kubernetes Cluster Monitoring (Prometheus + Grafana + GitOps)

## Описание проекта

Целью данного проекта является внедрение отказоустойчивой системы мониторинга для Kubernetes-кластера с использованием стека **Prometheus & Grafana**.

Архитектура построена по гибридной модели **«Pull-then-Push»**:
Внутри кластера метрики собираются локальным Prometheus (Pull), после чего агрегированные данные пересылаются во внешнее, стабильное хранилище на базе отдельного сервера (Push). Для визуализации используется Grafana, настроенная на внешнем узле. Сбор прикладных метрик (Nginx) реализован с помощью паттерна `Sidecar`, а развертывание компонентов инфраструктуры управляется через **ArgoCD** (GitOps подход).

---

## Пошаговая реализация

### 1. Установка внешнего хранилища метрик и визуализации (Local Storage)

Внешний сервер (в данной архитектуре — основной ПК) имитирует стабильное оборудование для долговременного хранения TSDB (Time-Series Database) метрик.

Среда развернута с помощью `docker-compose.yml`. В конфигурации Prometheus включен флаг `--web.enable-remote-write-receiver`, позволяющий ему работать в режиме точки приема метрик из удаленного кластера.

**`docker-compose.yml`**:

```yaml
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:latest
    container_name: central_prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/usr/share/prometheus/console_libraries'
      - '--web.console.templates=/usr/share/prometheus/consoles'
      - '--web.enable-remote-write-receiver' # Ключевой флаг для приема данных из k8s
    restart: unless-stopped

  grafana:
    image: grafana/grafana:latest
    container_name: central_grafana
    ports:
      - "3000:3000"
    volumes:
      - grafana_data:/var/lib/grafana
    restart: unless-stopped
    depends_on:
      - central_prometheus

volumes:
  prometheus_data:
  grafana_data:

```

**`prometheus.yml`**:

```yaml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'prometheus-local'
    static_configs:
      - targets: ['localhost:9090']

```

*После запуска контейнеров, по соответствующим портам становятся доступны интерфейсы Grafana (3000) и Prometheus (9090).*

---

### 2. Деплой Prometheus Operator в кластер (ArgoCD)

Для сбора метрик внутри кластера используется Helm-чарт `kube-prometheus-stack`, управление которым передано ArgoCD для соблюдения GitOps-практик.

Был создан манифест Application:
**`prometheus-app.yaml`**:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: prometheus-stack
  namespace: argocd
spec:
  project: default
  source:
    chart: kube-prometheus-stack
    repoURL: https://prometheus-community.github.io/helm-charts
    targetRevision: 61.3.2
    helm:
      values: |
        grafana:
          enabled: false
        prometheus:
          prometheusSpec:
            remoteWrite:
              - url: "http://192.168.1.180:9090/api/v1/write"
            serviceMonitorNamespaceSelector: {}
            serviceMonitorSelectorNilUsesHelmValues: false
  destination:
    server: "https://kubernetes.default.svc"
    namespace: monitoring
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - ServerSideApply=true

```

**Назначение данного манифеста:**

1. **Установка стека:** Автоматически разворачивает кластерный Prometheus, оператор и системные экспортеры (node-exporter, kube-state-metrics).
2. **Отключение локальной Grafana:** Встроенная Grafana отключена (`grafana.enabled: false`), так как визуализация вынесена на внешний сервер.
3. **Настройка Remote Write:** Указывает кластерному Prometheus не хранить данные локально долго, а сразу отправлять (Push) собранные батчи метрик на IP-адрес внешнего хранилища (`[http://192.168.1.180:9090/api/v1/write](http://192.168.1.180:9090/api/v1/write)`).
4. **Service Discovery:** Флаг `serviceMonitorSelectorNilUsesHelmValues: false` заставляет Prometheus Operator глобально отслеживать и автоматически подключать все `ServiceMonitor` в кластере.

---

### 3. Инструментация приложений (Helm Chart Updates)

Для сбора метрик с веб-сайтов, Helm-чарт целевого приложения был модернизирован.

**1. Добавление Sidecar-контейнера (`deployment.yaml`):**
Так как Nginx отдает статистику в текстовом формате (`/stub_status`), в под добавлен sidecar-контейнер `nginx-prometheus-exporter`, который переводит эти данные в формат OpenMetrics на порту `9113`.

```yaml
        - name: nginx-exporter
          image: nginx/nginx-prometheus-exporter:latest
          args:
            - "-nginx.scrape-uri=http://localhost/stub_status"
          ports:
            - containerPort: 9113

```

**2. Обновление сети (`service.yaml`):**
Добавлен лейбл для портов и открыт новый порт `9113` для отдачи метрик.

```yaml
  ports:
    - port: 80
      targetPort: 80
      name: http
    - port: 9113
      targetPort: 9113
      name: metrics

```

**3. Настройка Service Discovery (Создание ServiceMonitor):**
Был написан манифест **`servicemonitor.yaml`**:

```yaml
{{- range $siteName, $siteConfig := .Values.sites }}
{{- if $siteConfig.enabled }}
---
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: monitor-{{ $siteName }}
  labels:
    release: prometheus-stack
spec:
  selector:
    matchLabels:
      app: nginx-{{ $siteName }}
  endpoints:
  - port: metrics
    path: /metrics
    interval: 15s
{{- end }}
{{- end }}

```

**Зачем это нужно:** `ServiceMonitor` — это инструкция (Custom Resource) для Prometheus Operator. Он сообщает оператору: *"Найди все Services с лейблом `app: nginx-...`, подключись к их порту `metrics` и собирай (Scrape) оттуда статистику каждые 15 секунд"*. Это полностью избавляет от необходимости вручную прописывать IP-адреса подов в конфигурации мониторинга.

**4. Альтернативный метод сбора (Ingress Controller):**
Для сбора детализированной статистики по HTTP-трафику (RPS, Latency, коды 2xx/4xx/5xx) был написан манифест `ingress-monitor.yaml`, который собирает данные напрямую с Nginx Ingress Controller:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: {{ .Release.Name }}-ingress-nginx-monitor
  labels:
    release: prometheus-stack
spec:
  selector:
    matchLabels:
      app.kubernetes.io/instance: ingress-nginx
      app.kubernetes.io/name: ingress-nginx
  namespaceSelector:
    matchNames:
      - ingress-nginx
  endpoints:
    - port: metrics
      path: /metrics
      interval: 15s

```

---

### 4. Визуализация в Grafana (Финальный этап)

После выполнения вышеописанных шагов метрики железа, кластера, Ingress-контроллера и Nginx автоматически собираются Prometheus'ом на Master-ноде и проталкиваются (Remote Write) в хранилище на основном ПК.

Для визуализации данных в Grafana были выполнены следующие настройки:

1. **Подключение Data Source:** В Grafana добавлен источник данных Prometheus с URL `http://prometheus:9090` (обращение внутри сети Docker).
2. **Импорт комьюнити-дашбордов:**
* **Node Exporter Full:** Для мониторинга аппаратных ресурсов виртуальных машин кластера (CPU, RAM, Network).
* **NGINX Exporter (ID: 12708):** Для отслеживания активных соединений и общего статуса подов.
* **NGINX Ingress Controller (ID: 9614 / 14314):** Для глубокой аналитики трафика (RPS, процент ошибок, Latency) с возможностью фильтрации по конкретным пространствам имен.


3. **Использование PromQL:** Для получения изолированной статистики (исключающей внутренний шум проверок Kubernetes) применялись кастомные PromQL запросы в режиме Explore. Например, запрос `sum by (host, status) (rate(nginx_ingress_controller_requests[2m]))` позволил получить точную детализацию по HTTP-кодам для каждого отдельного развернутого домена в реальном времени.

---

# Kubernetes Cluster Monitoring (Prometheus + Grafana + GitOps)

## Project Description

The goal of this project is to implement a fault-tolerant monitoring system for a Kubernetes cluster using the **Prometheus & Grafana** stack.

The architecture follows a hybrid **"Pull-then-Push"** model:
Inside the cluster, metrics are collected by a local Prometheus instance (Pull), after which the aggregated data is forwarded to external, stable storage hosted on a separate server (Push). Grafana, configured on the external node, is used for visualization. Application metrics (Nginx) are collected using the `Sidecar` pattern, while infrastructure component deployment is managed via **ArgoCD** (GitOps approach).

---

## Step-by-Step Implementation

### 1. Setting up External Metrics Storage and Visualization (Local Storage)

The external server (in this architecture, the host PC) simulates stable hardware for the long-term storage of TSDB (Time-Series Database) metrics.

The environment is deployed using `docker-compose.yml`. The Prometheus configuration includes the `--web.enable-remote-write-receiver` flag, enabling it to operate as a receiver for metrics sent from the remote cluster. **`docker-compose.yml`**:

```yaml
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:latest
    container_name: central_prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/usr/share/prometheus/console_libraries'
      - '--web.console.templates=/usr/share/prometheus/consoles'
      - '--web.enable-remote-write-receiver' # Ключевой флаг для приема данных из k8s
    restart: unless-stopped

  grafana:
    image: grafana/grafana:latest
    container_name: central_grafana
    ports:
      - "3000:3000"
    volumes:
      - grafana_data:/var/lib/grafana
    restart: unless-stopped
    depends_on:
      - central_prometheus

volumes:
  prometheus_data:
  grafana_data:

```

**`prometheus.yml`**:

```yaml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'prometheus-local'
    static_configs:
      - targets: ['localhost:9090']

```

*Once the containers are started, the Grafana (3000) and Prometheus (9090) interfaces become accessible via their respective ports.*

---

### 2. Deploying Prometheus Operator to the cluster (ArgoCD)

The `kube-prometheus-stack` Helm chart is used to collect metrics within the cluster; its management is handled by ArgoCD to adhere to GitOps practices. The following Application manifest was created:
**`prometheus-app.yaml`**:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: prometheus-stack
  namespace: argocd
spec:
  project: default
  source:
    chart: kube-prometheus-stack
    repoURL: https://prometheus-community.github.io/helm-charts
    targetRevision: 61.3.2
    helm:
      values: |
        grafana:
          enabled: false
        prometheus:
          prometheusSpec:
            remoteWrite:
              - url: "http://192.168.1.180:9090/api/v1/write"
            serviceMonitorNamespaceSelector: {}
            serviceMonitorSelectorNilUsesHelmValues: false
  destination:
    server: "https://kubernetes.default.svc"
    namespace: monitoring
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - ServerSideApply=true

```

**Purpose of this manifest:**

1. **Stack Installation:** Automatically deploys the cluster-level Prometheus, the operator, and system exporters (node-exporter, kube-state-metrics).
2. **Disabling Local Grafana:** The built-in Grafana instance is disabled (`grafana.enabled: false`) because visualization has been offloaded to an external server.
3. **Remote Write Configuration:** Instructs the cluster-level Prometheus not to store data locally for extended periods, but instead to immediately push collected metric batches to the external storage IP address (`[http://192.168.1.180:9090/api/v1/write](http://192.168.1.180:9090/api/v1/write)`). 4. **Service Discovery:** The `serviceMonitorSelectorNilUsesHelmValues: false` flag instructs the Prometheus Operator to globally discover and automatically attach all `ServiceMonitor` resources within the cluster.

---

### 3. Application Instrumentation (Helm Chart Updates)

The target application's Helm chart has been updated to enable metric collection from the websites.

**1. Adding a Sidecar Container (`deployment.yaml`):**
Since Nginx exposes statistics in a plain-text format (`/stub_status`), an `nginx-prometheus-exporter` sidecar container has been added to the pod; this container converts the data into OpenMetrics format and exposes it on port `9113`.

```yaml
        - name: nginx-exporter
          image: nginx/nginx-prometheus-exporter:latest
          args:
            - "-nginx.scrape-uri=http://localhost/stub_status"
          ports:
            - containerPort: 9113

```

**2. Network Update (`service.yaml`):**
A label has been added for the ports, and a new port (`9113`) has been opened for metric exposure.

```yaml
  ports:
    - port: 80
      targetPort: 80
      name: http
    - port: 9113
      targetPort: 9113
      name: metrics

```

**3. Service Discovery Configuration (Creating a ServiceMonitor):**
The **`servicemonitor.yaml`** manifest was created:

```yaml
{{- range $siteName, $siteConfig := .Values.sites }}
{{- if $siteConfig.enabled }}
---
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: monitor-{{ $siteName }}
  labels:
    release: prometheus-stack
spec:
  selector:
    matchLabels:
      app: nginx-{{ $siteName }}
  endpoints:
  - port: metrics
    path: /metrics
    interval: 15s
{{- end }}
{{- end }}

```

**Why this is needed:** A `ServiceMonitor` is an instruction (Custom Resource) for the Prometheus Operator. It tells the operator: *"Find all Services with the label `app: nginx-...`, connect to their `metrics` port, and scrape statistics from there every 15 seconds."* This completely eliminates the need to manually specify pod IP addresses in the monitoring configuration.

**4. Alternative collection method (Ingress Controller):**
To collect detailed HTTP traffic statistics (RPS, Latency, 2xx/4xx/5xx codes), the `ingress-monitor.yaml` manifest was created; it gathers data directly from the Nginx Ingress Controller:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: {{ .Release.Name }}-ingress-nginx-monitor
  labels:
    release: prometheus-stack
spec:
  selector:
    matchLabels:
      app.kubernetes.io/instance: ingress-nginx
      app.kubernetes.io/name: ingress-nginx
  namespaceSelector:
    matchNames:
      - ingress-nginx
  endpoints:
    - port: metrics
      path: /metrics
      interval: 15s

```

---

### 4. Visualization in Grafana (Final Stage)

After completing the steps described above, metrics for hardware, the cluster, the Ingress controller, and Nginx are automatically collected by Prometheus on the master node and pushed (via Remote Write) to the storage on the host machine.

The following configurations were applied to visualize the data in Grafana:

1. **Data Source Connection:** A Prometheus data source was added to Grafana with the URL `http://prometheus:9090` (accessed via the Docker internal network).
2. **Importing Community Dashboards:**
* **Node Exporter Full:** For monitoring the hardware resources of the cluster's virtual machines (CPU, RAM, Network).
* **NGINX Exporter (ID: 12708):** For tracking active connections and the general status of pods.
* **NGINX Ingress Controller (ID: 9614 / 14314):** For in-depth traffic analytics (RPS, error rate, Latency) with the ability to filter by specific namespaces. 3. **Using PromQL:** Custom PromQL queries in Explore mode were used to obtain isolated statistics (excluding internal noise from Kubernetes health checks). For example, the query `sum by (host, status) (rate(nginx_ingress_controller_requests[2m]))` provided a precise breakdown of HTTP status codes for each deployed domain in real time.

---

### Project file list:
- [ingress-monitor.yaml](https://github.com/Zakerru/Roadmap-sh-devops-projects/blob/main/Grafana-Prometeus_project/ingress-monitor.yaml)
- [servicemonitor.yaml](https://github.com/Zakerru/Roadmap-sh-devops-projects/blob/main/Grafana-Prometeus_project/servicemonitor.yaml)
- [docker-compose.yml](https://github.com/Zakerru/Roadmap-sh-devops-projects/blob/main/Grafana-Prometeus_project/local/docker-compose.yml)
- [prometheus.yml](https://github.com/Zakerru/Roadmap-sh-devops-projects/blob/main/Grafana-Prometeus_project/local/prometheus.yml)
- [prometheus-app.yaml](https://github.com/Zakerru/Roadmap-sh-devops-projects/blob/main/Grafana-Prometeus_project/argo/prometheus-app.yaml)
