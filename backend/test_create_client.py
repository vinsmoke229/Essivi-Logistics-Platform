import requests

base_url = "http://127.0.0.1:5000/api"

# 1. Connexion Admin
login_payload = {"identifier": "admin@essivi.com", "password": "admin123"}
resp = requests.post(f"{base_url}/auth/login", json=login_payload)
token = resp.json().get('access_token')

if not token:
    print("❌ Pas de token")
    exit()

# 2. Création Client
headers = {"Authorization": f"Bearer {token}"}
client_payload = {
    "name": "Boutique Maman Essi",
    "responsible_name": "Essi",
    "phone": "99887766",
    "address": "Grand Marché, Lomé",
    "gps_lat": 6.1300,
    "gps_lng": 1.2200
}

resp_client = requests.post(f"{base_url}/clients/", json=client_payload, headers=headers)
print(f"Code Client: {resp_client.status_code}")
print("Réponse:", resp_client.json())