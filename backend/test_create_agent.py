import requests

base_url = "http://127.0.0.1:5000/api"


login_payload = {
    "identifier": "admin@essivi.com",
    "password": "admin123"
}
response = requests.post(f"{base_url}/auth/login", json=login_payload)
token = response.json().get('access_token')

if not token:
    print("❌ Échec connexion Admin")
    exit()

print("✅ Connexion Admin OK. Token récupéré.")


headers = {"Authorization": f"Bearer {token}"}
agent_payload = {
    "matricule": "AGT-001",
    "full_name": "Jean Koffi",
    "phone": "90909090",
    "password": "agentpass123",
    "tricycle_plate": "TG-1234-A"
}

response_agent = requests.post(f"{base_url}/agents/", json=agent_payload, headers=headers)

print(f"Code création : {response_agent.status_code}")
print("Réponse :", response_agent.json())