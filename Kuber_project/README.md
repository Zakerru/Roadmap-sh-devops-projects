---
title: "Kubernetes Project"
description: "Project to set up a cluster and CI/CD using Kubernetes"
---


# Kubernetes Cluster & GitOps CI/CD Project

В данном проекте была спроектирована и развернута микросервисная архитектура на базе **Kubernetes**, выступающего в роли оркестратора контейнеров. За основу взята логика предыдущего проекта (Docker), которая была масштабирована для работы в отказоустойчивом кластере, а не на единичном хосте.

**Архитектура проекта:**
Кластер состоит из 1 Master-ноды и 2 Worker-нод. Развернуты 4 независимых веб-сайта. Каждый сайт функционирует внутри собственного пода (Pod). Применен паттерн **Sidecar**: в каждом поде работают два контейнера:

1. `nginx` — отдает статические HTML-файлы и генерирует логи доступа (access.log).
2. `parser` — bash-скрипт, который анализирует логи Nginx и отправляет сводную статистику по REST API на внешний сервер.
Связь между контейнерами внутри пода осуществляется через общее хранилище `shared volume` (тип `emptyDir`).

---

## Шаги, предпринятые для реализации:

### 1. Подготовка системы (Linux KVM/Bare Metal)

Стандартный образ Ubuntu-Server требует предварительной настройки перед развертыванием Kubernetes. Были выполнены следующие критические шаги:

* **а) Отключение Swap-файла:**
Kubernetes жестко управляет ресурсами (CPU/RAM). Если системе не хватает оперативной памяти и она начинает использовать swap (файл подкачки на жестком диске), производительность контейнеров непредсказуемо падает, а механизмы изоляции ресурсов (cgroups) работают некорректно. Swap был отключен командой `swapoff -a` и закомментирован в `/etc/fstab`.
* **б) Включение маршрутизации трафика (IP Forwarding):**
По умолчанию Linux не перенаправляет сетевые пакеты между интерфейсами. Для того чтобы поды могли общаться друг с другом поверх физической сети нод, необходимо включить форвардинг. В файл `/etc/sysctl.conf` были добавлены параметры `net.ipv4.ip_forward = 1` и загружены модули ядра `br_netfilter` и `overlay`.

### 2. Установка и настройка Kubernetes

Kubernetes — это не монолитная программа, а экосистема компонентов, взаимодействующих друг с другом. Были установлены:

* **Kubelet:** Агент, работающий на каждой ноде и управляющий жизненным циклом подов.
* **Kubeadm:** Утилита для бутстраппинга (инициализации) кластера.
* **Kubectl:** CLI-инструмент для управления кластером.
* **Containerd:** Среда выполнения контейнеров (CRI).

Кластер был инициализирован командой `kubeadm init`, после чего Worker-ноды были присоединены к Master-ноде.
В качестве сетевого плагина (CNI) был установлен **Flannel**, который создал оверлейную сеть для обеспечения связности между подами на разных физических машинах.

### 3. Подготовка материалов

* **а) Файловая структура:** На Master-ноде были созданы директории `site1`, `site2`, `site3`, `site4`. Dockerfile для Nginx унифицирован:

```dockerfile
FROM nginx:alpine
RUN rm /etc/nginx/conf.d/default.conf
COPY ./site.conf /etc/nginx/conf.d/
COPY ./static/ /usr/share/nginx/html/
EXPOSE 80

```


* **б) Реестр образов:** Создан аккаунт DockerHub. Образ `parser` загружен туда централизованно, так как он абсолютно идентичен для всех подов. *Важное дополнение: в логику парсера была внедрена пауза `sleep 15` при старте контейнера, чтобы исключить состояние гонки (Race Condition) при инициализации сетевого интерфейса пода.*
* **в) Адаптация:** Конфигурационные файлы Nginx адаптированы под Kubernetes (перенаправление логов в `/var/log/nginx` вместо stdout).

### 4. Создание генератора манифестов (Первая итерация)

Для автоматизации развертывания переменного числа сайтов был написан bash-скрипт `deploy-sites.sh`. Он итерировался по папкам, собирал образы локально, пушил их в DockerHub и применял (apply) шаблонный манифест.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: deploy-${SITE_NAME}
  labels:
    app: nginx-${SITE_NAME}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx-${SITE_NAME}
  template:
    metadata:
      labels:
        app: nginx-${SITE_NAME}
    spec:
      volumes:
      - name: shared-logs
        emptyDir:
          sizeLimit: 50Mi
      containers:
      - name: nginx
        image: ${DOCKER_USER}/nginx-${SITE_NAME}:latest
        imagePullPolicy: Always
        resources:
          requests:
            memory: "500Mi"
        ports:
        - containerPort: 80
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 15
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 2
          periodSeconds: 10
        volumeMounts:
        - name: shared-logs
          mountPath: /var/log/nginx
      - name: parser
        image: ${DOCKER_USER}/parser:latest
        imagePullPolicy: Always
        resources:
          requests:
            memory: "1000Mi"
        env:
        - name: SITE_NAME
          value: "${SITE_NAME}"
        volumeMounts:
        - name: shared-logs
          mountPath: /var/log/nginx
---
apiVersion: v1
kind: Service
metadata:
  name: service-${SITE_NAME}
spec:
  type: NodePort
  selector:
    app: nginx-${SITE_NAME}
  ports:
    - port: 80
      targetPort: 80
      nodePort: ${CURRENT_PORT}

```

**Как работал манифест:**

* В секции `volumes` создавался общий диск `shared-logs`, который монтировался в оба контейнера в директорию `/var/log/nginx`. Это позволило парсеру читать логи, сгенерированные Nginx.
* Настроены проверки жизнеспособности (Liveness/Readiness probes) для автохилинга.
* `Service` типа `NodePort` открывал статический порт на каждой ноде кластера, чтобы сайт был доступен извне.

**Осознание проблемы:** Архитектура "push-from-master" с локальными скриптами не отвечает принципам DevOps. Хранение исходников на Master-ноде, сборка образов прямо в кластере и императивное управление через скрипт — это плохие практики. Было принято решение мигрировать на **GitOps** архитектуру с использованием Helm и ArgoCD.

### 5. Построение CI-пайплайна (GitHub Actions)

Для сборки образов внедрен CI-пайплайн. Написан workflow `docker_commit.yml`. Триггером является пуш изменений в директории исходников `Kuber_project/sites/`.

**Ключевые улучшения:**

* **Отказ от тега `latest`:** Для обеспечения идемпотентности и защиты от кэширования Kubernetes, в качестве тега образа теперь используется короткий хэш Git-коммита:

```yaml
- name: Get Short Commit SHA
  id: vars
  run: |
    echo "SHORT_SHA=$(echo ${GITHUB_SHA::7})" >> $GITHUB_ENV

```


* **Умная сборка:** Единый `Dockerfile` переиспользуется для всех сайтов с подменой контекста при билде:

```bash
docker build -f Kuber_project/sites/Dockerfile -t ${DOC_USR}/nginx-${SITE_NAME}:${SHORT_SHA} ${folder}

```



### 6. Переход на Helm (Шаблонизация)

**Helm** — это пакетный менеджер для Kubernetes, который позволяет управлять сложными манифестами с помощью переменных (шаблонов Go). Это избавило проект от дублирования YAML-кода.

Структура Helm-чарта:

* **`values.yaml`:** Главный конфигурационный файл. Содержит переменные: `enabled` (вкл/выкл сайт), `imageTag` (хэш коммита от GitHub Actions) и `replicas`.
* **`Chart.yaml`:** Метаданные пакета.
* **`deployment.yaml`:** Шаблон подов. *Важно: для адаптации под ограниченные ресурсы Worker-нод (4 пода на 2 ноды), в стратегию деплоя был добавлен параметр `maxSurge: 0, maxUnavailable: 1`. Это предотвратило deadlock кластера при Rolling Update.*
* **`service.yaml`:** Абстракция сети (теперь типа `ClusterIP`).
* **`ingress.yaml`:** Правила маршрутизации внешнего трафика.

### 7. Настройка Ingress-контроллера

Открытие портов через `NodePort` для каждого сайта не масштабируется. Был развернут **NGINX Ingress Controller** (Bare-metal версия).

* Для привязки контроллера к конкретному IP-адресу (Master-ноде) и порту 80 был применен patch:

```bash
kubectl patch svc ingress-nginx-controller -n ingress-nginx -p '{"spec": {"externalIPs":["192.168.1.229"]}}'

```


* Так как проект локальный (без реального DNS-провайдера), доменные имена были прописаны в локальном `/etc/hosts`:
`192.168.1.229   site1.loc site2.loc site3.loc site4.loc argocd.loc`
Теперь Ingress-контроллер принимает весь трафик на порт 80 и динамически маршрутизирует его по подам в зависимости от запрошенного домена (`Host` header).

### 8. Внедрение ArgoCD (GitOps)

Для замыкания цикла CI/CD был развернут **ArgoCD**.
ArgoCD непрерывно мониторит репозиторий GitHub. Установлен режим автоматической синхронизации (Auto-Sync).

**Итоговый рабочий процесс пайплайна:**

1. Разработчик вносит изменения в исходники сайта или конфигурацию и делает `git push`.
2. **GitHub Actions** собирает новый образ, присваивает ему уникальный тег (Git SHA) и отправляет в **DockerHub**.
3. Пайплайн автоматически обновляет `imageTag` в файле `values.yaml` в репозитории.
4. **ArgoCD** замечает изменения в `values.yaml`, генерирует новые манифесты через Helm и применяет изменения в кластере.
5. Kubernetes выполняет плавное обновление (Rolling Update) с учетом ограничений по ресурсам.

Проект полностью автоматизирован, соответствует современным стандартам DevOps-инженерии (IaC, GitOps, CI/CD) и легко масштабируется на любое количество узлов.


---

# Kubernetes Cluster & GitOps CI/CD Project

This project involved designing and deploying a microservices architecture based on **Kubernetes**, acting as the container orchestrator. It builds upon the logic of a previous project (Docker) but scales it to run within a fault-tolerant cluster rather than on a single host.

**Project Architecture:**
The cluster consists of one master node and two worker nodes. Four independent websites have been deployed, with each site running inside its own Pod. The **Sidecar** pattern is implemented, with two containers running in each Pod:

1. `nginx` — serves static HTML files and generates access logs (`access.log`).
2. `parser` — a Bash script that analyzes Nginx logs and sends summary statistics to an external server via a REST API.
Communication between containers within the Pod takes place via a shared volume (`emptyDir` type). Communication between containers within a pod takes place via a shared volume (of the `emptyDir` type).

---

## Implementation Steps:

### 1. System Preparation (Linux KVM/Bare Metal)

A standard Ubuntu Server image requires preliminary configuration before Kubernetes deployment. The following critical steps were performed:

* **a) Disabling Swap:**
Kubernetes strictly manages resources (CPU/RAM). If the system runs low on RAM and begins using swap (disk-based virtual memory), container performance drops unpredictably, and resource isolation mechanisms (cgroups) fail to function correctly. Swap was disabled using the `swapoff -a` command and commented out in `/etc/fstab`.
* **b) Enabling Traffic Routing (IP Forwarding):**
By default, Linux does not forward network packets between interfaces. To allow pods to communicate with each other across the physical node network, IP forwarding must be enabled. The parameter `net.ipv4.ip_forward = 1` was added to `/etc/sysctl.conf`, and the `br_netfilter` and `overlay` kernel modules were loaded.

### 2. Kubernetes Installation and Configuration

Kubernetes is not a monolithic program but an ecosystem of interacting components. The following were installed:

* **Kubelet:** An agent running on each node that manages the pod lifecycle.
* **Kubeadm:** A utility for bootstrapping (initializing) the cluster.
* **Kubectl:** A CLI tool for cluster management.
* **Containerd:** A container runtime (CRI).

The cluster was initialized using the `kubeadm init` command, after which worker nodes were joined to the master node. **Flannel** was installed as the CNI (Container Network Interface) plugin, creating an overlay network to ensure connectivity between pods running on different physical machines.

### 3. Preparation of Materials

* **a) File Structure:** Directories named `site1`, `site2`, `site3`, and `site4` were created on the master node. A unified Dockerfile for Nginx was used:

```dockerfile
FROM nginx:alpine
RUN rm /etc/nginx/conf.d/default.conf
COPY ./site.conf /etc/nginx/conf.d/
COPY ./static/ /usr/share/nginx/html/
EXPOSE 80

```


* **b) Image Registry:** A DockerHub account was created. The `parser` image was uploaded to the registry centrally, as it is identical for all pods. *Important note: a `sleep 15` pause was added to the parser's startup logic to prevent a race condition during the initialization of the pod's network interface.*
* **c) Adaptation:** Nginx configuration files were adapted for Kubernetes (redirecting logs to `/var/log/nginx` instead of stdout).

### 4. Creating the Manifest Generator (First Iteration)

To automate the deployment of a variable number of sites, a bash script named `deploy-sites.sh` was written. It iterated through the directories, built images locally, pushed them to DockerHub, and applied a template manifest. 

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: deploy-${SITE_NAME}
  labels:
    app: nginx-${SITE_NAME}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx-${SITE_NAME}
  template:
    metadata:
      labels:
        app: nginx-${SITE_NAME}
    spec:
      volumes:
      - name: shared-logs
        emptyDir:
          sizeLimit: 50Mi
      containers:
      - name: nginx
        image: ${DOCKER_USER}/nginx-${SITE_NAME}:latest
        imagePullPolicy: Always
        resources:
          requests:
            memory: "500Mi"
        ports:
        - containerPort: 80
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 15
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 2
          periodSeconds: 10
        volumeMounts:
        - name: shared-logs
          mountPath: /var/log/nginx
      - name: parser
        image: ${DOCKER_USER}/parser:latest
        imagePullPolicy: Always
        resources:
          requests:
            memory: "1000Mi"
        env:
        - name: SITE_NAME
          value: "${SITE_NAME}"
        volumeMounts:
        - name: shared-logs
          mountPath: /var/log/nginx
---
apiVersion: v1
kind: Service
metadata:
  name: service-${SITE_NAME}
spec:
  type: NodePort
  selector:
    app: nginx-${SITE_NAME}
  ports:
    - port: 80
      targetPort: 80
      nodePort: ${CURRENT_PORT}

```

**How ​​the manifest worked:**

* The `volumes` section created a shared volume named `shared-logs`, which was mounted into both containers at the `/var/log/nginx` directory. This allowed the parser to read logs generated by Nginx.
* Liveness and readiness probes were configured to enable self-healing.
* A `NodePort` service exposed a static port on every cluster node, making the site accessible from outside the cluster.

**Recognizing the problem:** The "push-from-master" architecture relying on local scripts violated DevOps principles. Storing source code on the master node, building images directly within the cluster, and using imperative management via scripts were considered bad practices. A decision was made to migrate to a **GitOps** architecture using Helm and ArgoCD. ### 5. CI Pipeline Construction (GitHub Actions)

A CI pipeline has been implemented to build images. A `docker_commit.yml` workflow was created. The pipeline is triggered by pushing changes to the `Kuber_project/sites/` source directory.

**Key Improvements:**

* **Eliminating the `latest` tag:** To ensure idempotency and avoid Kubernetes caching issues, the short Git commit hash is now used as the image tag:

```yaml
- name: Get Short Commit SHA
  id: vars
  run: | 
echo "SHORT_SHA=$(echo ${GITHUB_SHA::7})" >> $GITHUB_ENV

```


* **Smart build:** A single `Dockerfile` is reused for all sites by swapping the build context:

```bash
docker build -f Kuber_project/sites/Dockerfile -t ${DOC_USR}/nginx-${SITE_NAME}:${SHORT_SHA} ${folder}

```



### 6. Transition to Helm (Templating)

**Helm** is a package manager for Kubernetes that allows for the management of complex manifests using variables (Go templates). This eliminated YAML code duplication across the project.

Helm chart structure:

* **`values.yaml`:** The main configuration file. It contains variables such as `enabled` (site on/off), `imageTag` (commit hash from GitHub Actions), and `replicas`.
* **`Chart.yaml`:** Package metadata.
* **`deployment.yaml`:** Pod template. *Note: To accommodate the limited resources of the worker nodes (4 pods across 2 nodes), the `maxSurge: 0, maxUnavailable: 1` parameter was added to the deployment strategy. This prevented cluster deadlock during Rolling Updates.*
* **`service.yaml`:** Network abstraction (now set to `ClusterIP` type). * **`ingress.yaml`:** External traffic routing rules.

### 7. Configuring the Ingress Controller

Opening ports via `NodePort` for each site does not scale well. An **NGINX Ingress Controller** (bare-metal version) was deployed.

* A patch was applied to bind the controller to a specific IP address (the master node) and port 80:

```bash
kubectl patch svc ingress-nginx-controller -n ingress-nginx -p '{"spec": {"externalIPs":["192.168.1.229"]}}'

```

* Since this is a local project (without a real DNS provider), domain names were added to the local `/etc/hosts` file:

`192.168.1.229   site1.loc site2.loc site3.loc site4.loc argocd.loc`

The Ingress controller now accepts all traffic on port 80 and dynamically routes it to the appropriate pods based on the requested domain (`Host` header).

### 8. Implementing ArgoCD (GitOps)

**ArgoCD** was deployed to close the CI/CD loop.
ArgoCD continuously monitors the GitHub repository. Auto-sync mode is enabled.

**Final pipeline workflow:**

1. A developer makes changes to the site source code or configuration and performs a `git push`.
2. **GitHub Actions** builds a new image, assigns it a unique tag (Git SHA), and pushes it to **DockerHub**.
3. The pipeline automatically updates the `imageTag` in the `values.yaml` file within the repository.
4. **ArgoCD** detects the changes in `values.yaml`, generates new manifests using Helm, and applies the changes to the cluster.
5. Kubernetes performs a rolling update while respecting resource constraints. The project is fully automated, complies with modern DevOps engineering standards (IaC, GitOps, CI/CD), and easily scales to any number of nodes.

---

### Project file list:
- [deploy_sites.sh](https://github.com/Zakerru/Roadmap-sh-devops-projects/blob/main/Kuber_project/deploy_sites.sh)
- [parcerdoc/Dockerfile](https://github.com/Zakerru/Roadmap-sh-devops-projects/blob/main/Kuber_project/parcerdoc/Dockerfile)
- [parser.sh](https://github.com/Zakerru/Roadmap-sh-devops-projects/blob/main/Kuber_project/parcerdoc/parser.sh)
- [receiever.py](https://github.com/Zakerru/Roadmap-sh-devops-projects/blob/main/Kuber_project/receiever/receiever.py)
- [sites/Dockerfile](https://github.com/Zakerru/Roadmap-sh-devops-projects/blob/main/Kuber_project/sites/Dockerfile)
- [values.yaml](https://github.com/Zakerru/Roadmap-sh-devops-projects/blob/main/Kuber_project/web-app-chart/values.yaml)
- [Chart.yaml](https://github.com/Zakerru/Roadmap-sh-devops-projects/blob/main/Kuber_project/web-app-chart/Chart.yaml)
- [deployment.yaml](https://github.com/Zakerru/Roadmap-sh-devops-projects/blob/main/Kuber_project/web-app-chart/templates/deployment.yaml)
- [ingress.yaml](https://github.com/Zakerru/Roadmap-sh-devops-projects/blob/main/Kuber_project/web-app-chart/templates/ingress.yaml)
- [service.yaml](https://github.com/Zakerru/Roadmap-sh-devops-projects/blob/main/Kuber_project/web-app-chart/templates/service.yaml)
- [argocd-ingress.yaml](https://github.com/Zakerru/Roadmap-sh-devops-projects/blob/main/Kuber_project/argocd-ingress.yaml)
- [docker_commit.yml](https://github.com/Zakerru/Roadmap-sh-devops-projects/blob/main/.github/workflows/docker_commit.yml)
