from app import create_app, db
from app.models.sql_models import User
from werkzeug.security import generate_password_hash

app = create_app()

def seed_database():
    with app.app_context():
        
        if User.query.filter_by(email="admin@essivi.com").first():
            print("⚠️ L'administrateur existe déjà.")
            return

        print("🌱 Création du Super Administrateur...")
        
        
        admin = User(
            username="SuperAdmin",
            email="admin@essivi.com",
            
            password_hash=generate_password_hash("admin123"),
            role="super_admin"
        )

        
        db.session.add(admin)
        db.session.commit()
        
        print("✅ Super Administrateur créé avec succès !")
        print("📧 Email: admin@essivi.com")
        print("🔑 Pass : admin123")

if __name__ == "__main__":
    seed_database()