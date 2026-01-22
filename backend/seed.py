from app import create_app, db
from app.models.sql_models import User
from werkzeug.security import generate_password_hash

app = create_app()

def seed_database():
    with app.app_context():
        # Vérifier si l'admin existe déjà pour ne pas créer de doublon
        if User.query.filter_by(email="admin@essivi.com").first():
            print("⚠️ L'administrateur existe déjà.")
            return

        print("🌱 Création du Super Administrateur...")
        
        # Création de l'objet User
        admin = User(
            username="SuperAdmin",
            email="admin@essivi.com",
            # Hachage du mot de passe (On ne stocke JAMAIS en clair !)
            password_hash=generate_password_hash("admin123"),
            role="super_admin"
        )

        # Ajout et validation dans la base
        db.session.add(admin)
        db.session.commit()
        
        print("✅ Super Administrateur créé avec succès !")
        print("📧 Email: admin@essivi.com")
        print("🔑 Pass : admin123")

if __name__ == "__main__":
    seed_database()