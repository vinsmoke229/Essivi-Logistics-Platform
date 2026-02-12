import os
from app import create_app, db
from app.models.sql_models import User, Agent
from werkzeug.security import generate_password_hash


db_path = os.path.abspath("force_test.db")
app = create_app()
app.config['SQLALCHEMY_DATABASE_URI'] = f'sqlite:///{db_path}'

def start_force():
    with app.app_context():
        print(f"🔥 CRÉATION DE LA BASE ICI : {db_path}")
        db.drop_all()
        db.create_all()
        
        print("👤 Création de l'Agent 0000...")
        agent = Agent(
            matricule="SOS",
            full_name="Agent Sauveur",
            phone="0000",
            
            password_hash=generate_password_hash("0000"),
            is_active=True,
            tricycle_plate="MOTO-X"
        )
        db.session.add(agent)
        
        
        admin = User(
            username="Admin",
            email="admin@essivi.com",
            password_hash=generate_password_hash("admin123"),
            role="super_admin"
        )
        db.session.add(admin)
        
        db.session.commit()
        print("✅ AGENT '0000' / '0000' CRÉÉ ET VALIDÉ !")

    print("🚀 LANCEMENT DU SERVEUR...")
    
    app.run(host='0.0.0.0', port=5000, debug=True)

if __name__ == "__main__":
    start_force()