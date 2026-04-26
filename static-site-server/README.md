---
layout: default
title: Nginx Web Server Setup
---

# Nginx Web Server Setup & Multi-Site Configuration

Этот проект посвящен установке веб-сервера Nginx на Ubuntu Server и настройке хостинга для нескольких сайтов (Virtual Hosts) с использованием современных инструментов синхронизации.

## Пошаговое описание выполненных действий

### 1. Установка Nginx
* Обновлены репозитории: `sudo apt update`.
* Установлен пакет Nginx: `sudo apt install nginx -y`.
* Настроен файрвол UFW для разрешения стандартного HTTP трафика: `sudo ufw allow 'Nginx HTTP'`.

### 2. Подготовка файловой структуры и прав доступа
* Созданы директории для двух разных сайтов:
  `sudo mkdir -p /var/www/site1`
  `sudo mkdir -p /var/www/site2`
* Для возможности загрузки файлов без использования root-прав, изменен владелец папок на текущего пользователя (zakerru):
  `sudo chown -R zakerru:zakerru /var/www/site1`
  `sudo chown -R zakerru:zakerru /var/www/site2`

### 3. Развертывание контента (HTML)
* На локальной машине (Kubuntu) подготовлены файлы `index1.html`, `index2.html` и `page2.html`.
* Выполнена синхронизация файлов с использованием утилиты **rsync** (вместо менее эффективного scp):
  `rsync -avz -e "ssh -p 2222" ./local_folder/ Vzakerru:/var/www/`
  *Опция -a сохраняет права, -z сжимает данные, -e указывает на нестандартный SSH порт.*

### 4. Настройка Server Blocks (Виртуальные хосты)
Для разделения сайтов по портам (8081 и 8082) созданы конфигурационные файлы в `/etc/nginx/sites-available/`:
* Конфиги определяют корень сайта (`root`), индексный файл и порт прослушивания (`listen`).
* Активация сайтов выполнена через создание символических ссылок (симлинков):
  `sudo ln -s /etc/nginx/sites-available/site1 /etc/nginx/sites-enabled/`
* Проверка синтаксиса: `sudo nginx -t`.
* Перезапуск службы: `sudo systemctl restart nginx`.

### 5. Настройка портов
* В файрволе UFW открыты дополнительные порты:
  `sudo ufw allow 8081/tcp`
  `sudo ufw allow 8082/tcp`

### 6. Управление логами
* Изучены основные лог-файлы Nginx в директории `/var/log/nginx/`:
  - `access.log`: запись всех входящих запросов.
  - `error.log`: технические ошибки сервера.
* Для отладки использовалась команда `tail -f /var/log/nginx/access.log` для наблюдения за трафиком в реальном времени.

---

# Nginx Web Server Setup & Multi-Site Configuration (English Version)

This project focuses on installing Nginx on an Ubuntu Server and configuring multiple virtual hosts to serve different websites using modern synchronization tools.

## Implementation Steps

### 1. Nginx Installation
* Updated package lists: `sudo apt update`.
* Installed Nginx: `sudo apt install nginx -y`.
* Allowed initial HTTP traffic in UFW: `sudo ufw allow 'Nginx HTTP'`.

### 2. Directory Structure & Permissions
* Created web root directories for two sites:
  `sudo mkdir -p /var/www/site1`
  `sudo mkdir -p /var/www/site2`
* Changed ownership to the local user (zakerru) to allow seamless file uploads:
  `sudo chown -R zakerru:zakerru /var/www/site1`
  `sudo chown -R zakerru:zakerru /var/www/site2`

### 3. Content Deployment via RSYNC
* Prepared `index.html` and `page2.html` on the Kubuntu host.
* Synchronized files using **rsync** for efficient incremental updates:
  `rsync -avz -e "ssh -p 2222" ./local_folder/ vm-sergej:/var/www/site1/`
  *Flags: -a (archive mode), -z (compression), -e (specifies custom SSH port).*

### 4. Configuring Server Blocks (Virtual Hosts)
* Created configuration files in `/etc/nginx/sites-available/` to host sites on ports 8081 and 8082.
* Enabled the sites by creating symbolic links in `/etc/nginx/sites-enabled/`.
* Verified the configuration with `sudo nginx -t` and restarted the service.

### 5. Log Monitoring
* Explored Nginx logs located in `/var/log/nginx/`:
  - `access.log`: Logs all incoming client requests.
  - `error.log`: Logs server-side errors.
* Used `tail -f` to monitor real-time traffic and debug HTTP status codes.

### 6. Firewall Configuration
* Opened custom ports for web access:
  `sudo ufw allow 8081/tcp`
  `sudo ufw allow 8082/tcp`
