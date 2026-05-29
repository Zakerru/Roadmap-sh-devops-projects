---

title: "DNS Setup"
description: "A project on configuring a castom domain name"
---

# Basic DNS Setup

В данном проекте была произведена покупка и настройка доменного имени `zakerru.site`, а так же опробован различный функционал платформы Cloudflare.

## Базовая инфраструктура: Домен, Cloudflare DNS и Почтовый роутинг

Данный раздел описывает первичную настройку инфраструктуры для хостинга статического сайта (`Roadmap-sh-devops-projects`) на базе GitHub Pages с использованием собственного доменного имени. 

Главные архитектурные цели этого этапа:
* **Анонимность:** Регистрация домена без привязки к паспортным данным в открытых базах WHOIS.
* **Безопасность и CDN:** Проксирование всего трафика через Cloudflare для скрытия реальных IP-адресов GitHub, ускорения доставки контента и защиты от DDoS.
* **Фильтрация трафика:** Базовая настройка WAF для отсеивания ботов с помощью капчи.
* **Профессиональная почта:** Настройка Email Routing для получения писем на корпоративный адрес без необходимости поднимать и администрировать собственный почтовый сервер.

---

## Пошаговая реализация

### Шаг 1. Покупка домена и обеспечение приватности (Timeweb)
Доменное имя `zakerru.site` было приобретено у регистратора **Timeweb**.
* **Выбор зоны:** Регистрация в национальной зоне `.ru` требует обязательного предоставления паспортных данных, которые могут быть деанонимизированы. Выбор международной зоны `.site` позволил легально обойти это требование и сохранить полную приватность владельца.

### Шаг 2. Делегирование управления зоной (NS) в Cloudflare
Для получения доступа к WAF, бесплатному SSL и продвинутому управлению DNS, зона была передана под контроль Cloudflare. 
В панели управления Timeweb стандартные NS-серверы регистратора были удалены и заменены на серверы Cloudflare:
* `lennon.ns.cloudflare.com`
* `sierra.ns.cloudflare.com`

### Шаг 3. Настройка на стороне GitHub Pages
Чтобы GitHub начал принимать запросы по новому адресу, потребовалась настройка самого репозитория:
1. В настройках репозитория (`Settings` -> `Pages`) в поле **Custom domain** был указан адрес `zakerru.site`.
2. GitHub автоматически создал файл `CNAME` в корне репозитория для фиксации этого имени.
3. Дождавшись проверки DNS со стороны GitHub, была включена опция **Enforce HTTPS**, чтобы сам GitHub также выписал внутренний SSL-сертификат (Let's Encrypt) для корректной работы связки Cloudflare <-> GitHub.

### Шаг 4. Конфигурация DNS-записей в Cloudflare
Для маршрутизации трафика на серверы GitHub были добавлены соответствующие `A` и `CNAME` записи. 
**Критически важно:** для всех веб-записей был включен статус **Proxied**. Это значит, что юзеры подключаются к серверам Cloudflare, а уже Cloudflare идет за контентом на GitHub.

### Шаг 5. Базовая защита (WAF & Captcha)
Для защиты от парсеров и ботнетов, создающих мусорную нагрузку, в разделе **Security -> WAF -> Custom rules** было настроено правило защиты.
* Трафик, попадающий под заданные критерии, обрабатывается действием **Managed Challenge**. 
* Cloudflare автоматически оценивает риск запроса и, при необходимости, показывает посетителю интерактивную капчу или проверяет браузер неинтерактивно через JS-челлендж.

### Шаг 6. Настройка Cloudflare Email Routing (Почта)
Для создания точки связи был настроен адрес `nitpick@zakerru.site`. В разделе **Email Routing** было создано правило переадресации, которое прозрачно пересылает все входящие письма на защищенный личный ящик Gmail.

Чтобы почтовые серверы (включая жесткие фильтры Google) доверяли этой пересылке, Cloudflare автоматически добавил необходимые служебные записи (DNS only):
* **MX-записи:** Три сервера (`route1`, `route2`, `route3.mx.cloudflare.net`) с разными приоритетами (62, 30, 57), которые принимают почту для домена.
* **TXT (SPF):** `v=spf1 include:_spf.mx.cloudflare.net ~all` — разрешает серверам Cloudflare отправлять письма от имени домена `zakerru.site`.
* **TXT (DKIM):** `cf2024-1._domainkey` — содержит публичный криптографический ключ для проверки цифровой подписи писем, гарантируя, что письмо не было изменено в процессе пересылки.

## Secure OpenWrt Access via Cloudflare mTLS & Tunnel 

Данный этап реализует безопасный доступ к веб-интерфейсу (LuCI) домашнего роутера OpenWrt из любой точки мира. 
Вместо классического проброса портов (Port Forwarding), который делает роутер уязвимым для сканеров и ботов, используется концепция **Zero Trust Network Access (ZTNA)**.

**Ключевые особенности архитектуры:**
* **Отсутствие открытых портов:** Трафик идет через зашифрованный Cloudflare Tunnel.
* **Аутентификация mTLS (Mutual TLS):** Доступ к поддомену невозможен без клиентского криптографического сертификата. Нет сертификата — Cloudflare мгновенно сбрасывает соединение (Drop).
* **RAM-оптимизация (Защита Flash-памяти):** Бинарный файл `cloudflared` (весом ~35 МБ) скачивается и исполняется исключительно в оперативной памяти (`/tmp`) при каждой загрузке роутера.
* **Обход ТСПУ:** Туннель принудительно переведен на `HTTP/2` (TCP), чтобы избежать разрывов соединения, характерных для протокола QUIC (UDP) в сетях некоторых провайдеров.
* **Отказоустойчивость:** Настроен системный демон `procd` для автовосстановления туннеля при разрывах связи или отключении электричества.

---

## Пошаговая реализация

### Шаг 1. Подготовка домена и mTLS в Cloudflare
1. Домен (`zakerru.site`) привязан к аккаунту Cloudflare.
2. В разделе **SSL/TLS -> Client Certificates** сгенерирован клиентский сертификат (формат PEM).
3. Исходные ключи (Private Key и Certificate) сохранены локально и конвертированы в формат `PKCS#12 (.p12)` для поддержки браузерами и мобильными ОС:

   ```bash
   openssl pkcs12 -export -out router-client.p12 -inkey cloudflare.key -in cloudflare.crt
   ```

4. На вкладке **Hosts** (в разделе Client Certificates) для поддомена `router.zakerru.site` включено обязательное требование сертификата (**Required**).

### Шаг 2. Настройка Web Application Firewall (WAF)

Для отсечения всех неавторизованных запросов создано правило **Custom WAF Rule**:

* **Имя:** `mTLS Shield`
* **Логика:** `(http.host eq "router.zakerru.site" and not cf.tls_client_auth.cert_verified)`
* **Действие:** `Block`
* **Приоритет:** Правило установлено **первым в списке** (Order: 1), чтобы перекрывать любые правила с действиями Managed Challenge (капча).

### Шаг 3. Первичная настройка Cloudflared на роутере

Так как бинарник не хранится в постоянной памяти, установка выполняется через `/tmp`.

Скачивание клиента для архитектуры ARM64:

```bash
wget -O /tmp/cloudflared [https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64](https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64)
chmod +x /tmp/cloudflared

```

Авторизация и создание туннеля:

```bash
/tmp/cloudflared tunnel login
/tmp/cloudflared tunnel create router
/tmp/cloudflared tunnel route dns router router.zakerru.site

```

*Ключи авторизации (`.json`) и конфиги автоматически сохраняются в постоянную память роутера (`/root/.cloudflared/`).*

### Шаг 4. Конфигурация туннеля

Создан конфигурационный файл `/root/.cloudflared/config.yml` с явным указанием протокола `http2` для стабильной работы:

```yaml
tunnel: <ID>
credentials-file: /root/.cloudflared/<ID>.json
protocol: http2

ingress:
  - hostname: router.zakerru.site
    service: [http://127.0.0.1:80](http://127.0.0.1:80)
  - service: http_status:404

```

### Шаг 5. Автоматизация (procd init-скрипт)

Создан скрипт-демон `/etc/init.d/zzz_cloudflared` (префикс `zzz_` гарантирует запуск последним в очереди).
Скрипт проверяет наличие сети, скачивает актуальный клиент в RAM и поддерживает его работу.

## Использование на клиенте

Для доступа к интерфейсу роутера:

1. Импортировать сгенерированный файл `router-client.p12` в хранилище сертификатов устройства (Настройки Android/iOS или настройки браузера Firefox на ПК).
2. Перейти на `https://router.zakerru.site`.
3. Подтвердить предоставление клиентского сертификата во всплывающем окне браузера.

---

# Basic DNS Setup

In this project, the domain name `zakerru.site` was purchased and configured, and various features of the Cloudflare platform were explored.

## Basic Infrastructure: Domain, Cloudflare DNS, and Email Routing

This section describes the initial infrastructure setup for hosting a static site (`Roadmap-sh-devops-projects`) on GitHub Pages using a custom domain name.

The primary architectural goals for this stage were:
* **Anonymity:** Registering the domain without linking it to personal passport details in public WHOIS databases.
* **Security and CDN:** Proxying all traffic through Cloudflare to mask the actual GitHub IP addresses, accelerate content delivery, and provide protection against DDoS attacks.
* **Traffic Filtering:** Basic WAF configuration to filter out bots using CAPTCHA challenges.
* **Professional Email:** Configuring Email Routing to receive emails at a professional address without the need to set up and administer a dedicated mail server.

---

## Step-by-Step Implementation

### Step 1. Domain Purchase and Privacy Assurance (Timeweb)
The domain name `zakerru.site` was purchased from the registrar **Timeweb**.
* **Zone Selection:** Registration in the national `.ru` zone mandates the submission of passport details, which can potentially lead to de-anonymization. Choosing the international `.site` zone allowed us to legally bypass this requirement and maintain complete owner privacy.

### Step 2. Delegating Zone Management (NS) to Cloudflare
To gain access to the WAF, free SSL certificates, and advanced DNS management features, control of the domain zone was delegated to Cloudflare. In the Timeweb control panel, the registrar's default NS servers were removed and replaced with Cloudflare servers:
* `lennon.ns.cloudflare.com`
* `sierra.ns.cloudflare.com`

### Step 3. Configuration on the GitHub Pages Side
To ensure GitHub began accepting requests at the new address, the repository itself required configuration:
1. In the repository settings (`Settings` -> `Pages`), the address `zakerru.site` was entered into the **Custom domain** field.
2. GitHub automatically created a `CNAME` file in the repository's root directory to register this domain name.
3. After waiting for GitHub to verify the DNS settings, the **Enforce HTTPS** option was enabled; this prompted GitHub to issue an internal SSL certificate (via Let's Encrypt) to ensure the Cloudflare ↔ GitHub connection functioned correctly.

### Step 4. Configuring DNS Records in Cloudflare
To route traffic to the GitHub servers, the corresponding `A` and `CNAME` records were added.
**Critically Important:** The **Proxied** status was enabled for all web-related records. This means that users connect to Cloudflare's servers, and Cloudflare, in turn, fetches the content from GitHub.

### Step 5. Basic Protection (WAF & Captcha)
To protect against scrapers and botnets generating malicious traffic, a security rule was configured within the **Security -> WAF -> Custom rules** section.
* Traffic matching the specified criteria is processed using the **Managed Challenge** action.
* Cloudflare automatically assesses the risk level of the incoming request and, if necessary, presents the visitor with an interactive CAPTCHA or performs a non-interactive browser verification via a JavaScript challenge.

### Step 6. Configuring Cloudflare Email Routing (Email)
To establish a point of contact, the email address `nitpick@zakerru.site` was configured. In the **Email Routing** section, a forwarding rule was created that transparently forwards all incoming emails to a secure personal Gmail inbox.

To ensure that mail servers (including Google's strict filters) trust this forwarding, Cloudflare automatically added the necessary service records (DNS-only):
* **MX Records:** Three servers (`route1`, `route2`, `route3.mx.cloudflare.net`) with varying priorities (62, 30, 57) that accept mail for the domain.
* **TXT (SPF):** `v=spf1 include:_spf.mx.cloudflare.net ~all` — authorizes Cloudflare servers to send emails on behalf of the `zakerru.site` domain.
* **TXT (DKIM):** `cf2024-1._domainkey` — contains the public cryptographic key used to verify email digital signatures, guaranteeing that the email has not been altered during transit.

## Secure OpenWrt Access via Cloudflare mTLS & Tunnel

This stage implements secure access to the web interface (LuCI) of the home OpenWrt router from anywhere in the world.
Instead of traditional Port Forwarding—which leaves the router vulnerable to scanners and bots—the **Zero Trust Network Access (ZTNA)** concept is employed.

**Key Architectural Features:**
* **No Open Ports:** Traffic flows through an encrypted Cloudflare Tunnel.
* **mTLS (Mutual TLS) Authentication:** Access to the subdomain is impossible without a client-side cryptographic certificate. No certificate? Cloudflare instantly drops the connection. * **RAM Optimization (Flash Memory Protection):** The `cloudflared` binary file (approx. 35 MB) is downloaded and executed exclusively in RAM (`/tmp`) upon every router boot.
* **Bypassing TSPU:** The tunnel is forcibly switched to `HTTP/2` (TCP) to prevent connection interruptions—a common issue with the QUIC (UDP) protocol on certain ISPs' networks.

* **Fault Tolerance:** The `procd` system daemon has been configured to automatically restore the tunnel in the event of connection interruptions or power outages.

---

## Step-by-Step Implementation

### Step 1. Domain and mTLS Preparation in Cloudflare
1. The domain (`zakerru.site`) has been linked to a Cloudflare account.
2. A client certificate (in PEM format) has been generated within the **SSL/TLS -> Client Certificates** section.
3. The original keys (Private Key and Certificate) have been saved locally and converted to the `PKCS#12 (.p12)` format to ensure compatibility with web browsers and mobile operating systems:

```bash
openssl pkcs12 -export -out router-client.p12 -inkey cloudflare.key -in cloudflare.crt

```

4. On the **Hosts** tab (within the Client Certificates section), the requirement for a client certificate has been enabled (**Required**) for the `router.zakerru.site` subdomain.

### Step 2. Web Application Firewall (WAF) Configuration

To block all unauthorized requests, a **Custom WAF Rule** has been created:

* **Name:** `mTLS Shield`
* **Logic:** `(http.host eq "router.zakerru.site" and not cf.tls_client_auth.cert_verified)`
* **Action:** `Block`
* **Priority:** The rule is positioned **first in the list** (Order: 1) to override any rules involving "Managed Challenge" actions (CAPTCHA).

### Step 3. Initial Cloudflared Setup on the Router

Since the binary file is not stored in persistent memory, the installation process is performed within the `/tmp` directory. Downloading the client for the ARM64 architecture:

```bash
wget -O /tmp/cloudflared [https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64](https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64)
chmod +x /tmp/cloudflared

```

Authentication and tunnel creation:

```bash
/tmp/cloudflared tunnel login
/tmp/cloudflared tunnel create router
/tmp/cloudflared tunnel route dns router router.zakerru.site

```

*Authentication keys (`.json`) and configuration files are automatically saved to the router's persistent storage (`/root/.cloudflared/`).*

### Step 4. Tunnel Configuration

A configuration file, `/root/.cloudflared/config.yml`, has been created, explicitly specifying the `http2` protocol to ensure stable operation:

```yaml
tunnel: <ID>
credentials-file: /root/.cloudflared/<ID>.json
protocol: http2

ingress:
- hostname: router.zakerru.site
service: [http://127.0.0.1:80](http://127.0.0.1:80)
- service: http_status:404

```

### Step 5. Automation (procd init script)

A daemon script, `/etc/init.d/zzz_cloudflared`, has been created (the `zzz_` prefix ensures it is the last script to run in the queue).
The script checks for network connectivity, downloads the latest client version into RAM, and maintains its operation.

## Client-side Usage

To access the router interface:

1. Import the generated `router-client.p12` file into your device's certificate store (via Android/iOS Settings or Firefox browser settings on a PC). 2. Go to `https://router.zakerru.site`.
3. Confirm the provision of the client certificate in the browser's pop-up window.

---
### Project files:
- [config.yml](https://github.com/Zakerru/Roadmap-sh-devops-projects/blob/main/DNS-setup/config.yml)
- [zzz_cloudflared_ram](https://github.com/Zakerru/Roadmap-sh-devops-projects/blob/main/DNS-setup/zzz_cloudflared_ram)
