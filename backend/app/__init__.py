from flask import Flask, request, jsonify
from flask_sqlalchemy import SQLAlchemy
from flask_migrate import Migrate
from flask_cors import CORS
from flask_jwt_extended import JWTManager
from pymongo import MongoClient
import os
from dotenv import load_dotenv

# 1. Charger le .env en priorité absolue
load_dotenv()

db = SQLAlchemy()
migrate = Migrate()
jwt = JWTManager()
mongo_client = None

def create_app():
    app = Flask(__name__)
    
    # 2. Récupération de l'URL Postgres depuis le .env
    # On met une valeur par défaut pour SQLite uniquement si Postgres n'est pas trouvé
    db_url = os.environ.get('DATABASE_URL')
    
    # DEBUG CRITIQUE : Pour voir dans ton terminal quelle base est lue
    print("\n" + "!"*60)
    print(f"🔌 BACKEND CONNECTÉ À : {db_url}")
    print("!"*60 + "\n")

    app.config['SQLALCHEMY_DATABASE_URI'] = db_url
    app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
    app.config['JWT_SECRET_KEY'] = os.environ.get('JWT_SECRET_KEY', 'super-secure-key')
    app.config['MONGO_URI'] = os.environ.get('MONGO_URI', 'mongodb://localhost:27017/essivi_logs')

    db.init_app(app)
    migrate.init_app(app, db)
    jwt.init_app(app)
    
    app.url_map.strict_slashes = False
    CORS(app, resources={r"/api/*": {"origins": "*"}}, supports_credentials=True, expose_headers=["Authorization"])

    # Connexion MongoDB
    global mongo_client
    try:
        mongo_client = MongoClient(app.config['MONGO_URI'])
        print("✅ MongoDB OK")
    except Exception as e:
        print(f"❌ Erreur MongoDB: {e}")

    @app.route('/')
    def index():
        return {"msg": "ESSIVI API ONLINE", "database": "PostgreSQL"}
    
    # --- ENREGISTREMENT DES ROUTES ---
    from app.routes.auth_routes import auth_bp
    from app.routes.agent_routes import agent_bp
    from app.routes.client_routes import client_bp
    from app.routes.delivery_routes import delivery_bp
    from app.routes.tour_routes import tour_bp
    from app.routes.order_routes import order_bp
    from app.routes.audit_routes import audit_bp
    from app.routes.stats_routes import stats_bp

    app.register_blueprint(auth_bp)
    app.register_blueprint(agent_bp)
    app.register_blueprint(client_bp)
    app.register_blueprint(delivery_bp)
    app.register_blueprint(tour_bp)
    app.register_blueprint(order_bp)
    app.register_blueprint(audit_bp)
    app.register_blueprint(stats_bp)

    return app