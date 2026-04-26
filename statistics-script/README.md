---
layout: default
title: Server Performance Stats
---

# Server Performance Stats script

`RUSSIAN:`

Скрипт просмотра статистики сервера. Создан по идеи из https://roadmap.sh/projects/server-stats
Как указано в задании, скрипт спроектирован максимально портативным для различных linux серверов. Портативность проверялась на домашнем пк и роутере с OpenWrt.

Выводит в терминал следующую информацию:
* Список и информация о дисках
* Общая нагрузка на ЦП
* Информация об оперативной памяти: свободно, задействовано, общий процент занятости
* Топ 5 процессов по нагрузке на ЦП
* Топ 5 процессов по нагрузке на память
* Версия ОС и ядра
* Время старта системы и uptime

## Для запуска:
1. Клонировать репозиторий
2. Сделайте скрипт исполняемым:
   ```bash
   chmod +x server-stats.sh
   ```
3. Запустить: 
   ```bash 
   bash server-stats.sh
   ```
`ENGLISH:`
Server statistics viewing script. Based on the idea from https://roadmap.sh/projects/server-stats
As stated in the task, the script is designed to be as portable as possible for various Linux servers. Portability was tested on a home PC and an OpenWrt router.

Outputs the following information to the terminal:
* Disk list and information
* Total CPU load
* RAM information: free, used, total occupied percentage
* Top 5 processes by CPU load
* Top 5 processes by memory load
* OS and kernel version
* System startup time and uptime

## To run:
1. Clone the repository
2. Make the script executable:
```bash
chmod +x server-stats.sh
```
3. Run:
```bash
bash server-stats.sh
```
### Project files:
- [server-stats.sh](https://github.com/Zakerru/Roadmap-sh-devops-projects/blob/main/statistics-script/server-stats.sh)
