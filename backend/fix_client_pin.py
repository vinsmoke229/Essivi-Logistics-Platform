from app import create_app, db
from app.models.sql_models import Client
from werkzeug.security import generate_password_hash, check_password_hash

app = create_app()

def fix_client_pin():
    with app.app_context():
        # Trouver le client avec le téléphone 92929292
        client = Client.query.filter_by(phone='92929292').first()
        
        if client:
            print(f"🔍 Client trouvé : {client.name} (ID: {client.id})")
            print(f"🔍 Téléphone : {client.phone}")
            print(f"🔍 PIN hash actuel : {client.pin_hash}")
            
            # Générer un nouveau PIN hash pour "1234"
            new_pin_hash = generate_password_hash("1234")
            print(f"🔍 Nouveau PIN hash pour '1234' : {new_pin_hash}")
            
            # Mettre à jour le PIN
            client.pin_hash = new_pin_hash
            db.session.commit()
            
            print("✅ PIN mis à jour avec succès !")
            
            # Vérifier le PIN
            if check_password_hash(new_pin_hash, "1234"):
                print("✅ Vérification du PIN : OK")
            else:
                print("❌ Vérification du PIN : ÉCHEC")
        else:
            print("❌ Client non trouvé avec le téléphone 92929292")
            
            # Lister tous les clients
            all_clients = Client.query.all()
            print(f"📋 Liste de tous les clients ({len(all_clients)}):")
            for c in all_clients:
                print(f"  - {c.name} (ID: {c.id}, Téléphone: {c.phone}, PIN: {'OUI' if c.pin_hash else 'NON'})")

if __name__ == "__main__":
    fix_client_pin()
