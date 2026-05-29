---
title: "Workflow mini projects"
description: "Reprort on completing some practical tasks"
---

После выполнения проекта GitHub Pages я не очень хорошо разобрался в структуре и сути работы yml-файлов и интерфейсе самого GitHub, так что решил выполнить 3 придуманные задачи для закрепления этой информации.

1. **Автоматический синтаксический тест (ShellCheck)**
   Создал воркфлоу для автоматической проверки Bash-скриптов. Реализовал логику получения списка измененных файлов и их поочередную проверку через ShellCheck. Главной сложностью было настроить скрипт так, чтобы он не завершался на первой ошибке, а собирал отчет по всем файлам и только потом выдавал финальный статус.

2. **Сбор статистики и автоматический коммит (Bot-activity)**
   Реализовал воркфлоу `autostats` с ручным запуском (`workflow_dispatch`). Этот процесс автоматически собирает данные о системе (нагрузка CPU, RAM, диск), записывает их в лог и сам делает коммит в репозиторий от имени GitHub Bot. Использовал проверку `git diff-index`, чтобы избежать пустых коммитов, если данные не изменились.

3. **Защита веток и Branch Protection**
   Настроил правила защиты для ветки `main`. Теперь слияние веток через Pull Request заблокировано, пока автоматический тест из первой задачи не пройдет успешно. Также изучил работу триггера `schedule` для запуска проверок по расписанию и отладил процесс взаимодействия между локальными и удаленными ветками.

Благодаря этим задачам мое понимание работы виртуальных машин GitHub Actions и взаимодействия Git-команд внутри автоматизаций значительно улучшилось.

---

After completing a GitHub Pages project, I felt I hadn't fully grasped the structure and underlying mechanics of YAML files, nor the GitHub interface itself. Consequently, I decided to undertake three self-devised tasks to solidify my understanding of this material.

1. **Automated Syntax Testing (ShellCheck)**
I created a workflow designed to automatically validate Bash scripts. I implemented the logic to retrieve a list of modified files and sequentially check each one using ShellCheck. The primary challenge lay in configuring the script so that it wouldn't terminate upon encountering the first error; instead, it was designed to compile a comprehensive report covering all files before finally issuing a definitive status.

2. **Statistics Collection and Automated Commits (Bot-activity)**
I implemented an `autostats` workflow configured for manual triggering (`workflow_dispatch`). This process automatically collects system metrics (CPU load, RAM usage, disk space), logs this data, and then automatically commits the changes to the repository under the identity of a "GitHub Bot." I utilized the `git diff-index` check to prevent the creation of empty commits in instances where the system data had not changed.

3. **Branch Protection Rules**
I configured branch protection rules specifically for the `main` branch. Consequently, merging branches via Pull Requests is now blocked until the automated syntax test—developed in the first task—successfully passes. Additionally, I explored the functionality of the `schedule` trigger to automate checks on a recurring timetable, and I debugged the interaction process between local and remote branches.

Thanks to these tasks, my understanding of how GitHub Actions virtual machines operate—as well as how Git commands interact within automated workflows—has significantly improved.

---
### Project files:
- [shelltesting.yml](https://github.com/Zakerru/Roadmap-sh-devops-projects/blob/main/.github/workflows/shelltesting.yml)
- [autoran_stats.yml](https://github.com/Zakerru/Roadmap-sh-devops-projects/blob/main/.github/workflows/autoran_stats.yml)
- [mistake.sh](https://github.com/Zakerru/Roadmap-sh-devops-projects/blob/main/workflow-miniprojects/mistake.sh)
- [stats.log](https://github.com/Zakerru/Roadmap-sh-devops-projects/blob/main/workflow-miniprojects/stats.log)
