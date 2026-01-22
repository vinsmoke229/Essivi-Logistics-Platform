import requests

base_url = "http://127.0.0.1:5000/api"

# 1. Connexion en tant qu'AGENT (Jean Koffi créé à l'étape 4)
# Note : On utilise le matricule ou le téléphone
login_payload = {
    "identifier": "AGT-001", 
    "password": "agentpass123"
}

print("🔄 Tentative de connexion de l'Agent...")
resp = requests.post(f"{base_url}/auth/login", json=login_payload)

if resp.status_code != 200:
    print("❌ Échec connexion Agent:", resp.json())
    exit()

token = resp.json().get('access_token')
print(f"✅ Agent connecté ! (Role: {resp.json().get('role')})")

# 2. Enregistrement de la Livraison
headers = {"Authorization": f"Bearer {token}"}

delivery_payload = {
    "client_id": 1,         # ID de la boutique créée juste avant
    "quantity_vitale": 20,
    "quantity_voltic": 30,
    "total_amount": 25000,  # 25.000 FCFA
    "gps_lat": 6.1305,      # Position GPS exacte de la livraison
    "gps_lng": 1.2205
}

print("🚚 Envoi de la livraison...")
resp_del = requests.post(f"{base_url}/deliveries/", json=delivery_payload, headers=headers)

print(f"Code Livraison: {resp_del.status_code}")
print("Réponse:", resp_del.json())