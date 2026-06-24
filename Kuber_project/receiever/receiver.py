from flask import Flask, request
import os

app = Flask(__name__)

BASE_UPLOAD_FOLDER = './received_logs'
os.makedirs(BASE_UPLOAD_FOLDER, exist_ok=True)

@app.route('/upload', methods=['POST'])
def upload_file():
    if 'file' not in request.files:
        return "Нет файла в запросе", 400

    file = request.files['file']

    site_name = request.form.get('site', 'unknown_site')

    site_name = "".join(c for c in site_name if c.isalnum() or c in ('-', '_')).strip()

    site_folder = os.path.join(BASE_UPLOAD_FOLDER, site_name)
    os.makedirs(site_folder, exist_ok=True)

    save_path = os.path.join(site_folder, 'server_report.log')
    file.save(save_path)

    print(f"--- [УСПЕХ] Получен отчет от сайта: {site_name}. Сохранен в {save_path} ---")
    return f"Файл для сайта {site_name} успешно принят", 200

if __name__ == '__main__':

    app.run(host='0.0.0.0', port=5000)
