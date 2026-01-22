from flask import Blueprint, request, jsonify
from app import db
from app.models.sql_models import User, Agent, Client
from werkzeug.security import check_password_hash
from flask_jwt_extended import create_access_token

auth_bp = Blueprint('auth', __name__, url_prefix='/api/auth')

@auth_bp.route('/login', methods=['POST'])
def login():
    data = request.get_json()
    identifier = data.get('identifier')
    password = data.get('password')

    # --- 🕵️ ZONE ESPION : ON AFFICHE CE QUI ARRIVE ---
    print("\n" + "="*50)
    print(f"📡 TENTATIVE DE CONNEXION REÇUE")
    print(f"👉 Identifiant reçu : '{identifier}'")
    print(f"👉 Mot de passe reçu : '{password}'")
    # --------------------------------------------------

    if not identifier or not password:
        return jsonify({"msg": "Identifiant et mot de passe requis"}), 400

    # 1. Vérification ADMIN
    user = User.query.filter_by(email=identifier).first()
    if user:
        print(f"👤 Compte ADMIN trouvé : {user.username}")
        if check_password_hash(user.password_hash, password):
            print("✅ Mot de passe Admin OK")
            access_token = create_access_token(
                identity=str(user.id), 
                additional_claims={'role': user.role, 'type': 'admin'}
            )
            return jsonify(access_token=access_token, role=user.role, type='admin', name=user.username, identifier=user.email), 200
        else:
            print("❌ Mot de passe Admin INCORRECT")

    # 2. Vérification AGENT
    # On cherche par Matricule OU par Téléphone
    agent = Agent.query.filter((Agent.matricule == identifier) | (Agent.phone == identifier)).first()
    
    if agent:
        print(f"🚚 Compte AGENT trouvé : {agent.full_name} (Matricule: {agent.matricule})")
        
        if check_password_hash(agent.password_hash, password):
            print("✅ Mot de passe Agent OK")
            
            if not agent.is_active:
                print("⛔ Compte Agent désactivé par l'admin")
                return jsonify({"msg": "Compte agent désactivé"}), 403
            
            access_token = create_access_token(
                identity=str(agent.id), 
                additional_claims={'role': 'agent', 'type': 'agent'}
            )
            print("🚀 Token généré et envoyé !")
            print("="*50 + "\n")
            return jsonify(access_token=access_token, role='agent', type='agent', name=agent.full_name, identifier=agent.matricule or agent.phone), 200
        else:
            print("❌ Mot de passe Agent INCORRECT")
    else:
        print("❌ Aucun Agent trouvé avec cet identifiant (ni matricule, ni téléphone)")

    # 3. Vérification CLIENT
    client = Client.query.filter_by(phone=identifier).first()
    if client:
        print(f"🛒 Compte CLIENT trouvé : {client.name}")
        if client.pin_hash and check_password_hash(client.pin_hash, password):
            print("✅ Code PIN Client OK")
            access_token = create_access_token(
                identity=str(client.id), 
                additional_claims={'role': 'client', 'type': 'client'}
            )
            return jsonify(access_token=access_token, role='client', type='client', name=client.name, identifier=client.phone), 200
        else:
            print("❌ Code PIN Client INCORRECT")

    print("⛔ ÉCHEC FINAL : Aucune correspondance trouvée.")
    print("="*50 + "\n")
    return jsonify({"msg": "Identifiant ou mot de passe incorrect"}), 401