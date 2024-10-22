from flask import Flask, jsonify, request
from flask_cors import CORS  # Import Flask-CORS
from collections import Counter
import socket
import requests
import time  # Import time module to calculate execution time

app = Flask(__name__)
CORS(app)  # Enable CORS for all routes

# Diviser le texte en trois parties
def divide_text(text):
    words = text.split()
    part1_end = len(words) // 3
    part2_end = 2 * (len(words) // 3)
    part1 = ' '.join(words[:part1_end])
    part2 = ' '.join(words[part1_end:part2_end])
    part3 = ' '.join(words[part2_end:])
    return part1, part2, part3

# Fonction map pour compter les mots dans une partie du texte
def map_word_count(text_chunk):
    words = text_chunk.split()
    return Counter(words)

# Envoyer une partie du texte à une machine distante
def send_to_machine(url, text_part):
    data = {'text': text_part}
    response = requests.post(url, json=data)
    return response.json()

def send_to_machine_socket(ip, port, text_chunk):
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.connect((ip, port))
        s.sendall(text_chunk.encode())  # Envoyer le texte
        response = s.recv(4096)  # Recevoir la réponse
    return response.decode()  # Retourner la réponse

# Fusionner les résultats des différentes machines
def merge_results(local_result, remote_result1, remote_result2):
    final_count = Counter(local_result)
    final_count.update(remote_result1)
    final_count.update(remote_result2)
    return final_count

# API endpoint to upload a file and process it
@app.route('/api/upload_file', methods=['POST'])
def upload_file():
    # Check if a file is included in the request
    if 'file' not in request.files:
        return jsonify({"error": "No file part"}), 400

    file = request.files['file']

    # If the user does not select a file, the browser might submit an empty file part
    if file.filename == '':
        return jsonify({"error": "No selected file"}), 400

    # Read the file content
    text = file.read().decode('utf-8')

    # Start timing for multiple machine processing
    start_time = time.time()

    # Diviser le texte en trois parties
    part1, part2, part3 = divide_text(text)

    # Traiter la première partie localement
    local_result = map_word_count(part1)

    # Envoyer la deuxième partie à Machine 2 et obtenir le résultat
    remote_result1 = send_to_machine_socket("192.168.1.33", 5001, part2)

    # Envoyer la troisième partie à Machine 3 et obtenir le résultat
    remote_result2 = send_to_machine("http://192.168.1.106:5000/process_text", part3)

    # Fusionner les résultats
    final_result = merge_results(local_result, remote_result1, remote_result2)

    # Stop timing for multiple machine processing
    execution_time = time.time() - start_time

    # Convert final result to a list of dictionaries to send to React
    data = [{'word': word, 'count': count} for word, count in final_result.items()]

    # Start timing for solo processing (single machine)
    start_time2 = time.time()

    # Traiter le text localement (en une seule fois)
    solo_result = map_word_count(text)

    time.sleep(1)

    # Stop timing for solo processing
    solo_execution_time = time.time() - start_time2

    # Convert solo result to a list of dictionaries
    solo_data = [{'word': word, 'count': count} for word, count in solo_result.items()]

    # Prepare the response with execution times
    response = {
        'data': data,
        'multiple_execution_time': execution_time,
        'solo_execution_time': solo_execution_time
    }

    # Return the JSON response with execution times
    return jsonify(response)

# Run the Flask app
if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)
