---
layout: default
title: Folder cleaner & archiver
---

# Folder cleaner & archiver

* Russian:

Мой первый Bash-скрипт. Создан для автоматической очистки папки загрузок. 
Скрипт перемещает файлы старше N дней в архив, удаляет архивы старше Z дней, проверяет свободное место на диске и ведет логи.

* Пути к директориям очистки и хранения архивов, а так же старость файлов и архивов указываются в файле `config.conf`.
* Скрипт проверяет, примонтирован ли диск перед началом работы.
* Итоги работы записываются в лог с указанием времени (логи находятся там же, где и созданные архивы).
* Скрипт проверяет, хватит ли места для создания архива (с запасом x2).

Скрипт предполагается использовать либо при запуске, либо при выходе из системы, либо через cron
## Для запуска:
1. Клонировать репозиторий
2. Укажите свои пути и сроки хранения в `config.conf`
3. Сделайте скрипт исполняемым:
   ```bash
   chmod +x download-cleaner.sh
   ```
После этого можно запустить в ручную.
* Для автоматического запуска при выходе из системы добавьте путь к скрипту в ваш `~/.bash_logout`
* Для автоматического запуска при входе в систему добавьте путь к скрипту в ваш `/etc/rc.local`

Либо используйте графический интерфейс

Идея для написания скрипта взята с https://roadmap.sh/projects/log-archive-tool , была изменена под мои личные потребности

* English:

  My first Bash script. Designed to automatically clean out the downloads folder.
The script moves files older than N days to an archive, deletes archives older than Z days, checks free disk space, and maintains logs.

* The paths to the archive cleanup and storage directories, as well as the age of files and archives, are specified in the `config.conf` file.
* The script checks whether the drive is mounted before starting.
* The results of the work are written to the log with time stamps (the logs are located in the same location as the created archives).
* The script checks whether there is enough space to create the archive (with a 2x safety margin).

The script is intended to be used either at startup, at logout, or via cron.
## To run:
1. Clone the repository
2. Specify your paths and expiration times in `config.conf`
3. Make the script executable:
```bash
chmod +x download-cleaner.sh
```
After this, you can run it manually.
* To automatically run it at logout, add the path to the script to your `~/.bash_logout`
* To automatically run it at login, add the path to the script to your `/etc/rc.local`

Alternatively, use the graphical interface

The idea for writing the script was taken from https://roadmap.sh/projects/log-archive-tool , modified to suit my personal needs

### Project file list:
- [download-cleaner.sh](https://github.com/Zakerru/Roadmap-sh-devops-projects/blob/main/folder_cleaner/download-cleaner.sh)
- [config.conf](https://github.com/Zakerru/Roadmap-sh-devops-projects/blob/main/folder_cleaner/config.conf)
