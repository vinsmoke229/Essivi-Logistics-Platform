from app import create_app, db
from app.models.sql_models import User
from werkzeug.security import generate_password_hash

def seed_rbac_users():
    app, _ = create_app()
    with app.app_context():
        test_users = [
            {
                "username": "admin_essivi",
                "email": "admin@essivi.com",
                "full_name": "Super Administrateur",
                "role": "super_admin",
                "password": "password123"
            },
            {
                "username": "manager_essivi",
                "email": "manager@essivi.com",
                "full_name": "Gestionnaire Logistique",
                "role": "manager",
                "password": "password123"
            },
            {
                "username": "visu_essivi",
                "email": "visu@essivi.com",
                "full_name": "Superviseur Lecture",
                "role": "supervisor",
                "password": "password123"
            }
        ]

        for u_data in test_users:
            user = User.query.filter_by(email=u_data['email']).first()
            if not user:
                new_user = User(
                    username=u_data['username'],
                    email=u_data['email'],
                    full_name=u_data['full_name'],
                    role=u_data['role'],
                    password_hash=generate_password_hash(u_data['password']),
                    is_active=True
                )
                db.session.add(new_user)
                print(f"✅ Créé : {u_data['email']} ({u_data['role']})")
            else:
                user.role = u_data['role'] 
                user.password_hash = generate_password_hash(u_data['password'])
                print(f"🔄 Mis à jour : {u_data['email']}")
        
        db.session.commit()
        print("🚀 Seed RBAC Users terminé!")

if __name__ == "__main__":
    seed_rbac_users()
