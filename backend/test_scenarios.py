import requests

# URL de ton serveur (celui qui tourne dans l'autre fenêtre)
BASE_URL = "http://127.0.0.1:5000/api"

def run_test():
    print("🚀 DÉMARRAGE DU SCÉNARIO DE TEST COMPLET...\n")

    # --- 1. CONNEXION ADMIN ---
    print("1️⃣  Connexion SuperAdmin...")
    login_payload = {"identifier": "admin@essivi.com", "password": "admin123"}
    resp = requests.post(f"{BASE_URL}/auth/login", json=login_payload)
    
    if resp.status_code != 200:
        print(f"❌ Erreur Login Admin: {resp.text}")
        return
    
    admin_token = resp.json().get('access_token')
    admin_headers = {"Authorization": f"Bearer {admin_token}"}
    print("✅ Admin connecté !\n")

    # --- 2. CRÉATION D'UN AGENT ---
    print("2️⃣  Création de l'Agent 'Koffi'...")
    agent_data = {
        "matricule": "AGT-TEST-01",
        "full_name": "Koffi Le Rapide",
        "phone": "90112233",
        "password": "pass",
        "tricycle_plate": "TG-9999-Z"
    }
    # On supprime d'abord s'il existe (pour pouvoir relancer le test)
    # Note: Dans un vrai test on ferait un nettoyage DB, ici on tente juste de créer
    resp = requests.post(f"{BASE_URL}/agents/", json=agent_data, headers=admin_headers)
    if resp.status_code in [201, 409]: # 201=Créé, 409=Existe déjà
        print(f"✅ Agent géré (Status: {resp.status_code})")
    else:
        print(f"❌ Erreur création agent: {resp.text}")
        return

    # --- 3. CRÉATION D'UN CLIENT ---
    print("\n3️⃣  Création du Client 'Maquis 2000'...")
    client_data = {
        "name": "Maquis 2000",
        "phone": "99887766",
        "address": "Tokoin, Lomé",
        "gps_lat": 6.13,
        "gps_lng": 1.22
    }
    resp = requests.post(f"{BASE_URL}/clients/", json=client_data, headers=admin_headers)
    
    client_id = None
    if resp.status_code == 201:
        client_id = resp.json().get('id')
        print(f"✅ Client créé avec ID: {client_id}")
    elif resp.status_code == 409:
        print("⚠️ Le client existe déjà, on continue...")
        # On va essayer de récupérer le client existant (si tu as codé la recherche, sinon on met ID 1 au hasard)
        client_id = 1 
    else:
        print(f"❌ Erreur création client: {resp.text}")
        return

    # --- 4. CONNEXION EN TANT QU'AGENT ---
    print("\n4️⃣  Connexion de l'Agent...")
    agent_login = {"identifier": "AGT-TEST-01", "password": "pass"}
    resp = requests.post(f"{BASE_URL}/auth/login", json=agent_login)
    
    if resp.status_code != 200:
        print(f"❌ L'agent n'arrive pas à se connecter: {resp.text}")
        return
    
    agent_token = resp.json().get('access_token')
    agent_headers = {"Authorization": f"Bearer {agent_token}"}
    print("✅ Agent connecté !\n")

    # --- 5. FAIRE UNE LIVRAISON ---
    print("5️⃣  L'Agent enregistre une livraison...")
    delivery_data = {
        "client_id": client_id,
        "quantity_vitale": 10,
        "quantity_voltic": 5,
        "total_amount": 15000,
        "gps_lat": 6.13005,
        "gps_lng": 1.22005
    }
    resp = requests.post(f"{BASE_URL}/deliveries/", json=delivery_data, headers=agent_headers)
    
    if resp.status_code == 201:
        print("✅ SUCCÈS TOTAL : Livraison enregistrée !")
        print(f"📄 Reçu : {resp.json()}")
    else:
        print(f"❌ Erreur livraison: {resp.text}")

if __name__ == "__main__":
    run_test()