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

        print("📍 Création du client IAI TOGO...")
        # On utilise les coordonnées exactes que tu as fournies
        client = Client(
            name="IAI TOGO (Salle Jury)",
            phone="99009900",
            responsible_name="Président du Jury",
            gps_lat=6.125414,  # TA LATITUDE
            gps_lng=1.210354   # TA LONGITUDE
        )
        db.session.add(client)

        db.session.commit()
        print("✅ Base de données réinitialisée avec succès !")
        print("✅ Agent: 0000 / 0000")
        print("✅ Client: IAI TOGO (Prêt pour GPS)")

if __name__ == "__main__":
    reset_db()