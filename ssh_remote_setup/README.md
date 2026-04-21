# SSH Security & Configuration Lab

Этот проект посвящен настройке безопасного удаленного доступа к **Ubuntu Server**, запущенному на виртуальной машине, с основной рабочей станции на **Kubuntu**. В ходе работы был реализован переход от стандартной парольной аутентификации к защищенному доступу по SSH-ключам.
* **Сделано по задаче из:** [SSH Remote Server Setup](https://roadmap.sh/projects/ssh-remote-server-setup)

## Пошаговое описание выполненных действий

### 1. Подготовка среды в VirtualBox
* Развернута виртуальная машина с ОС **Ubuntu Server**.
* Настроен сетевой адаптер в режиме **«Сетевой мост»** (Bridged Adapter) для получения IP из локальной сети.
* Выполнен первый вход по стандартному порту (22) для базовой настройки системы.

### 2. Управление пользователями
Для практики управления доступом использовались два пользователя:
* **zakerru** — первый основной пользователь.
* **sergej** — второй пользователь с правами администратора.
* Добавление пользователя в группу sudo: `sudo usermod -aG sudo sergej`.

### 3. Генерация и настройка SSH-ключей (на Kubuntu)
Вместо паролей настроена аутентификация по ключам **ED25519**:
* На основной системе (Kubuntu) сгенерированы пары ключей:
  ssh-keygen -t ed25519 -f ~/.ssh/id_zakerru
  ssh-keygen -t ed25519 -f ~/.ssh/id_sergej
* Публичные ключи переданы на сервер:
  ssh-copy-id -i ~/.ssh/id_zakerru.pub zakerru@192.168.1.XXX
  ssh-copy-id -i ~/.ssh/id_sergej.pub sergej@192.168.1.XXX

### 4. Настройка файла ~/.ssh/config
Для автоматизации подключений в Kubuntu настроен конфиг-файл:

Host vm-zakerru
    HostName 192.168.1.XXX
    User zakerru
    Port 2222
    IdentityFile ~/.ssh/id_zakerru

Host vm-sergej
    HostName 192.168.1.XXX
    User sergej
    Port 2222
    IdentityFile ~/.ssh/id_sergej

### 5. Настройка безопасности сервера (Hardening)
Внесены изменения в /etc/ssh/sshd_config на стороне Ubuntu Server:
* **Порт:** Стандартный порт 22 изменен на **2222**.
* **Аутентификация:** Установлено `PasswordAuthentication no` (вход по паролю запрещен).
* **Firewall:** Разрешен новый порт в UFW: `sudo ufw allow 2222/tcp`.
* **Перезапуск:** `sudo systemctl restart ssh`.

### 6. Резервное копирование
Создан **Snapshot** в VirtualBox после успешной проверки всех доступов.

---

# SSH Security & Configuration Lab (English Version)

This project covers the configuration of secure remote access to an **Ubuntu Server** (running on a VM) from a **Kubuntu** host machine. 

## Step-by-Step Implementation

### 1. Environment Setup (VirtualBox)
* Deployed **Ubuntu Server** as a virtual machine.
* Configured **Bridged Adapter** for local network access.

### 2. User Management
* **zakerru** — primary user.
* **sergej** — secondary user with administrative privileges.
* Granted sudo access: `sudo usermod -aG sudo sergej`.

### 3. SSH Key Generation & Deployment (on Kubuntu)
* Generated ED25519 key pairs on the Kubuntu host:
  ssh-keygen -t ed25519 -f ~/.ssh/id_zakerru
  ssh-keygen -t ed25519 -f ~/.ssh/id_sergej
* Deployed public keys to the server:
  ssh-copy-id -i ~/.ssh/id_zakerru.pub zakerru@192.168.1.XXX
  ssh-copy-id -i ~/.ssh/id_sergej.pub sergej@192.168.1.XXX

### 4. SSH Client Configuration (~/.ssh/config)
Updated the local SSH config file on Kubuntu:

Host vm-zaker
    HostName 192.168.1.XXX
    User zakerru
    Port 2222
    IdentityFile ~/.ssh/id_zakerru

Host vm-sergej
    HostName 192.168.1.XXX
    User sergej
    Port 2222
    IdentityFile ~/.ssh/id_sergej

### 5. Server Hardening (sshd_config)
* **Port:** Changed from 22 to **2222**.
* **Authentication:** Disabled passwords (`PasswordAuthentication no`).
* **Firewall:** `sudo ufw allow 2222/tcp`.
* **Service Restart:** `sudo systemctl restart ssh`.

### 6. Disaster Recovery
Created a **VirtualBox Snapshot** to capture the secure state of the VM.
