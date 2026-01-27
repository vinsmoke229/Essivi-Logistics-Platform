from app import create_app, db
from sqlalchemy import text

# Créer l'application Flask (déballage du tuple : app, socketio)
app_tuple = create_app()
if isinstance(app_tuple, tuple):
    app = app_tuple[0]
else:
    app = app_tuple

print("✅ Application Flask chargée")
# Vérification de sécurité pour éviter une nouvelle erreur d'attribut si app est None
if app and hasattr(app, 'config'):
    print(f"🔌 Base de données : {app.config['SQLALCHEMY_DATABASE_URI']}")
else:
    print("❌ Erreur: Impossible de récupérer l'objet app Flask")
    exit(1)

with app.app_context():
    print("🚀 Démarrage de la migration manuelle...")
    
    queries = [
        "ALTER TABLE tours ADD COLUMN IF NOT EXISTS stock_vitale_loaded INTEGER DEFAULT 0;",
        "ALTER TABLE tours ADD COLUMN IF NOT EXISTS stock_voltic_loaded INTEGER DEFAULT 0;",
        "ALTER TABLE tours ADD COLUMN IF NOT EXISTS stock_vitale_delivered INTEGER DEFAULT 0;",
        "ALTER TABLE tours ADD COLUMN IF NOT EXISTS stock_voltic_delivered INTEGER DEFAULT 0;",
        "ALTER TABLE tours ADD COLUMN IF NOT EXISTS status VARCHAR(20) DEFAULT 'pending';"
    ]
    
    try:
        # Utiliser la connexion SQLAlchemy de Flask
        with db.engine.connect() as conn:
            for q in queries:
                try:
                    conn.execute(text(q))
                    print(f"✅ Exécuté : {q}")
                except Exception as e:
                    # Ignorer si la colonne existe déjà
                    print(f"⚠️ Note : {e}")
            
            conn.commit()
            print("\n✨ Migration terminée avec succès !")
            
    except Exception as e:
        print(f"❌ Erreur critique : {e}")
