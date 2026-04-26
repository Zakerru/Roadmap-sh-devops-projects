---
layout: default
title: GitHub Pages Deployment Project
---
# Развертывание статического сайта через GitHub Pages и CI/CD

Проект выполнен по задаче из [GitHub Pages Deployment](https://roadmap.sh/projects/github-actions-deployment-workflow)

В данном проекте был создан сайт через GitHub Pages, добавлены правила его обновления при изменении только определенных файлов, а так же исполькован Jekyll

### 1. Создание index.html
Был создан файл `index.html` который содержит ссылки на страницы других моих проектов.

### 2. Интеграция Jekyll
Чтобы превратить документацию в веб-страницы, был задействован движок Jekyll:
* В корень репозитория добавлен конфигурационный файл `_config.yml` для глобальных настроек сайта (название, описание, выбор встроенной темы `slate`).
* В начало каждого `README.md` файла моих проектов добавлен блок метаданных (Front Matter) `--- layout: default ---`. Это дает Jekyll команду обернуть Markdown-текст в HTML-шаблон при сборке.
* Для кастомизации стилей (создания полноценной темной темы) переопределены CSS-переменные в папке `assets/`.

### 3. Настройка CI/CD (GitHub Actions)
Автоматизация процесса деплоя настроена через файл конфигурации `.github/workflows/deploy.yml`. 
Пайплайн состоит из следующих шагов:
1. **Checkout:** Клонирование репозитория в runner-окружение GitHub.
2. **Setup Pages & Build:** Настройка окружения и автоматический запуск Jekyll для сборки сайта из `.md` и `.html` файлов.
3. **Upload Artifact:** Упаковка готовых файлов.
4. **Deploy:** Публикация артефакта на серверах GitHub Pages.

### 4. Оптимизация триггеров (Path Filtering)
Чтобы пайплайн не запускался вхолостую при изменении файлов, не относящихся к сайту (например, Bash-скриптов или главного README репозитория), в workflow была добавлена фильтрация по путям:
- Сборка стартует только при изменении `index.html`, `_config.yml`, стилей в папке `assets/`, а также файлов `README.md` внутри папок проектов.
- Главный README репозитория добавлен в исключения (`!README.md`).

### 5. Настройка окружения GitHub
В настройках репозитория (раздел Pages) в качестве источника (Source) был выбран пункт **GitHub Actions**. Это передало управление публикацией от стандартного механизма веток к моему кастомному workflow.

В итоге при добавлении нового проекта в репозиторий мне необходимо добавить небольшой блок метаданных в начале файла `README`, строчку с названием директории в `_config.yml` и блок с ссылкой в `index.html`, после чего сайт будет автоматически создан, а `README.md` нового проекта станет новой страницей сайта благодаря Jekyll.

---

# Deploying a static website via GitHub Pages and CI/CD

This project was completed using a task from [GitHub Pages Deployment](https://roadmap.sh/projects/github-actions-deployment-workflow)

In this project, a website was created via GitHub Pages, rules were added to update it when only certain files were changed, and Jekyll was used.

### 1. Creating index.html
The file `index.html` was created, which contains links to pages from my other projects.

### 2. Integrating Jekyll
To turn the documentation into web pages, the Jekyll engine was used:
* The `_config.yml` configuration file was added to the repository root for global site settings (name, description, and selection of the built-in `slate` theme).
* A metadata block (Front Matter) has been added to the top of each `README.md` file in my projects: `--- layout: default ---`. This instructs Jekyll to wrap Markdown text in an HTML template during the build.
* To customize styles (to create a full-fledged dark theme), CSS variables in the `assets/` folder have been overridden.

### 3. Configuring CI/CD (GitHub Actions)
Deployment automation is configured via the `.github/workflows/deploy.yml` configuration file.
The pipeline consists of the following steps:
1. **Checkout:** Cloning the repository into the GitHub runner environment.
2. **Setup Pages & Build:** Setting up the environment and automatically running Jekyll to build the site from `.md` and `.html` files.
3. **Upload Artifact:** Packaging the completed files.
4. **Deploy:** Publish the artifact to GitHub Pages servers.

### 4. Trigger Optimization (Path Filtering)
To prevent the pipeline from being triggered when files unrelated to the site are changed (for example, Bash scripts or the main README repository), path filtering was added to the workflow:
- The build is triggered only when changes are made to index.html, _config.yml, styles in the assets/ folder, and README.md files within project folders.
- The main README repository has been added to the exceptions (!README.md).

### 5. Configuring the GitHub Environment
In the repository settings (Pages section), **GitHub Actions** was selected as the Source. This transferred publishing control from the standard branching mechanism to my custom workflow.

As a result, when adding a new project to the repository, I need to add a small block of metadata at the beginning of the README file, a line with the directory name in _config.yml, and a block with a link in index.html. After this, the site will be automatically created, and the new project's README.md file will become a new page on the site thanks to Jekyll.

### Project files:
* [index.html](https://github.com/Zakerru/Roadmap-sh-devops-projects/blob/main/index.html)
* [_config.yml](https://github.com/Zakerru/Roadmap-sh-devops-projects/blob/main/_config.yml)
* [deploy.yml](https://github.com/Zakerru/Roadmap-sh-devops-projects/blob/main/.github/workflows/deploy.yml)
