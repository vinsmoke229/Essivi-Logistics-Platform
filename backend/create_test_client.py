from app import create_app, db
from app.models.sql_models import Client
from werkzeug.security import generate_password_hash

app = create_app()

def create_test_client():
    with app.app_context():
        # Vérifier si le client existe déjà
        existing_client = Client.query.filter_by(phone="00228912345678").first()
        if existing_client:
            print("⚠️ Le client de test existe déjà.")
            print("📱 Téléphone: 00228912345678")
            print("🔑 PIN: 1234")
            return

        print("🌱 Création du Client de Test...")
        
        # Création du client
        client = Client(
            name="Boutique Test ESSIVI",
            responsible_name="Client Test",
            phone="00228912345678",
            address="Lomé, Bè",
            gps_lat=6.1300,
            gps_lng=1.2200,
            pin_hash=generate_password_hash("1234")
        )

        # Ajout et validation dans la base
        db.session.add(client)
        db.session.commit()
        
        print("✅ Client de test créé avec succès !")
        print("📱 Téléphone: 00228912345678")
        print("🔑 PIN: 1234")

if __name__ == "__main__":
    create_test_client()
