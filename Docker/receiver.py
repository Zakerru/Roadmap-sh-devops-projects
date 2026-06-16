from flask import Flask, request
import os

app = Flask(__name__)

UPLOAD_FOLDER = './received_logs'
os.makedirs(UPLOAD_FOLDER, exist_ok=True)

@app.route('/upload', methods=['POST'])
def upload_file():
    if 'file' in request.files:
        file = request.files['file']
        file.save(os.path.join(UPLOAD_FOLDER, 'server_report.log'))
        print("--- Отчет успешно получен и сохранен! ---")
        return "Файл получен", 200
    return "Нет файла", 400

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
