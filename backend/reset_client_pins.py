from app import create_app, db
from app.models.sql_models import Client
from werkzeug.security import generate_password_hash

app, _ = create_app()

with app.app_context():
    clients = Client.query.all()
    print(f"🔄 Mise à jour de {len(clients)} clients...")
    
    default_pin_hash = generate_password_hash('0000')
    
    for client in clients:
        client.pin_hash = default_pin_hash
        print(f"✅ PIN Réinitialisé pour: {client.name} ({client.phone})")
    
    db.session.commit()
    print("\n✨ Tous les clients peuvent désormais se connecter avec '0000'.")
