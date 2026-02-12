import requests

url = "http://127.0.0.1:5000/api/auth/login"


payload = {
    "identifier": "admin@essivi.com",
    "password": "admin123"
}

try:
    response = requests.post(url, json=payload)
    print(f"Status Code: {response.status_code}")
    print("Réponse du serveur :")
    print(response.json())
except Exception as e:
    print(f"Erreur : {e}")