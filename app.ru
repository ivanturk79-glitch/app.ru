import os
import requests
from flask import Flask, request, jsonify, send_from_directory
from flask_cors import CORS

app = Flask(__name__)
CORS(app)  # Разрешаем запросы из Telegram / браузера

CACHE_DIR = "cache"
os.makedirs(CACHE_DIR, exist_ok=True)

@app.route('/search', methods=['GET'])
def search_music():
    query = request.args.get('q', '')
    if not query:
        return jsonify({"results": []})
    
    try:
        # Используем открытый архив музыки для поиска
        url = f"https://api.jamendo.com/v3.0/tracks/?client_id=59929853&format=jsonjson&limit=15&search={requests.utils.quote(query)}&audioformat=mp32"
        response = requests.get(url)
        data = response.json()
        
        tracks = []
        for item in data.get('results', []):
            tracks.append({
                "id": item['id'],
                "title": item['name'],
                "artist": item['artist_name'],
                "cover": item['image'],
                "audio_url": item['audio'] # Ссылка на полный трек
            })
        return jsonify({"results": tracks})
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/stream', methods=['GET'])
def stream_music():
    audio_url = request.args.get('url', '')
    track_id = request.args.get('id', 'track')
    
    if not audio_url:
        return "No URL provided", 400
    
    filename = f"{track_id}.mp3"
    file_path = os.path.join(CACHE_DIR, filename)
    
    # КЭШИРОВАНИЕ: Если файл уже скачан на сервер, отдаем его моментально!
    if os.path.exists(file_path):
        return send_from_directory(CACHE_DIR, filename)
    
    try:
        # Если файла нет — скачиваем его с источника на сервер
        r = requests.get(audio_url, stream=True)
        if r.status_code == 200:
            with open(file_path, 'wb') as f:
                for chunk in r.iter_content(chunk_size=8192):
                    f.write(chunk)
            # Отдаем скачанный файл пользователю
            return send_from_directory(CACHE_DIR, filename)
        else:
            return "Failed to fetch audio", 400
    except Exception as e:
        return str(e), 500

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 5000))
    app.run(host='0.0.0.0', port=port)
