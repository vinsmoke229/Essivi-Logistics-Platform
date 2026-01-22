from app import create_app, db
from app.models.sql_models import User, Agent, Client
from werkzeug.security import generate_password_hash

app = create_app()

def reset_db():
    with app.app_context():
        print("🗑️  Nettoyage de la base de données...")
        db.drop_all()
        print("🏗️  Création des tables...")
        db.create_all()
        
        print("🌱 Création du SuperAdmin...")
        admin = User(
            username="SuperAdmin",
            email="admin@essivi.com",
            password_hash=generate_password_hash("admin123"),
            role="super_admin"
        )
        db.session.add(admin)

        print("🚚 Création de l'Agent DE SECOURS...")
        # C'est lui qui va marcher à 100%
        agent = Agent(
            matricule="SOS",
            full_name="Agent Secours",
            phone="0000",  # Identifiant simple
            password_hash=generate_password_hash("0000"), # Mot de passe simple
            tricycle_plate="SOS-MOTO",
            is_active=True
        )
        db.session.add(agent)

        # On ajoute aussi le client pour ton test de livraison
        client = Client(
            name="Maquis Test",
            phone="99009900",
            responsible_name="M. Test",
            gps_lat=6.13,
            gps_lng=1.22
        )
        db.session.add(client)

        db.session.commit()
        print("✅ Base de données réinitialisée avec AGENT '0000' VALIDE !")

if __name__ == "__main__":
    reset_db()