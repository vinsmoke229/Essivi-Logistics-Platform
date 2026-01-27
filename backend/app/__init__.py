from flask import Flask, request, jsonify
from flask_sqlalchemy import SQLAlchemy
from flask_migrate import Migrate
from flask_cors import CORS
from flask_jwt_extended import JWTManager
from flask_socketio import SocketIO
from pymongo import MongoClient
import os
from dotenv import load_dotenv

# 1. Charger le .env en priorité absolue
load_dotenv()

db = SQLAlchemy()
migrate = Migrate()
jwt = JWTManager()
socketio = None
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

    # Initialiser Socket.IO
    global socketio
    socketio = SocketIO(app, cors_allowed_origins="*", async_mode='threading')

    # Connexion MongoDB
    global mongo_client
    try:
        mongo_client = MongoClient(app.config['MONGO_URI'])
        print(" MongoDB OK")
    except Exception as e:
        print(f" Erreur MongoDB: {e}")

    @app.route('/favicon.ico')
    def favicon():
        return '', 204

    @app.route('/uploads/<path:filename>')
    def serve_uploads(filename):
        from flask import send_from_directory
        uploads_path = os.path.abspath(os.path.join(app.root_path, '..', 'uploads'))
        return send_from_directory(uploads_path, filename)

    # --- ENREGISTREMENT DES ROUTES ---
    from app.routes.auth_routes import auth_bp
    from app.routes.agent_routes import agent_bp
    from app.routes.client_routes import client_bp
    from app.routes.client_routes_extended import client_bp as client_extended_bp
    from app.routes.delivery_routes import delivery_bp
    from app.routes.tour_routes import tour_bp
    from app.routes.order_routes import order_bp
    from app.routes.audit_routes import audit_bp
    from app.routes.stats_routes import stats_bp
    from app.routes.product_routes import product_bp
    from app.routes.user_routes import user_bp
    from app.routes.stock_routes import stock_bp
    from app.routes.reports_routes import reports_bp
    from app.routes.permissions_routes import permissions_bp
    from app.routes.health_routes import health_bp
    from app.routes.settings_routes import settings_bp
    from app.routes.socketio_routes import socketio_bp

    # Ajout des routes manquantes
    try:
        from app.routes.map_routes import map_bp
        app.register_blueprint(map_bp)
        print(" Routes map importées")
    except ImportError:
        print(" Routes map non trouvées, création fallback...")
        # Créer les routes map directement si import échoue
        from flask import Blueprint, jsonify, request
        from flask_jwt_extended import jwt_required
        from datetime import datetime
        
        map_bp_fallback = Blueprint('map', __name__, url_prefix='/api/map')
        
        @map_bp_fallback.route('/realtime-positions', methods=['GET'])
        @jwt_required()
        def get_realtime_positions():
            return jsonify([
                {
                    'id': 'agent-1',
                    'lat': 6.131,
                    'lng': 1.222,
                    'type': 'agent',
                    'data': {
                        'id': 1,
                        'full_name': 'Koffi Yao',
                        'phone': '+228 90 12 34 56',
                        'tricycle_plate': 'TG-1234-A',
                        'status': 'en_tournée'
                    },
                    'timestamp': datetime.utcnow().isoformat()
                },
                {
                    'id': 'client-1',
                    'lat': 6.133,
                    'lng': 1.220,
                    'type': 'client',
                    'data': {
                        'id': 1,
                        'name': 'Boutique Mama Africa',
                        'phone': '+228 99 87 65 43',
                        'address': 'Lomé Centre, près du marché'
                    }
                }
            ])
        
        @map_bp_fallback.route('/zones-chalandise', methods=['GET'])
        @jwt_required()
        def get_zones_chalandise():
            return jsonify([
                {
                    'id': 'lome-centre',
                    'name': 'Lomé Centre',
                    'bounds': [[6.125, 1.215], [6.135, 1.225]],
                    'clientCount': 45,
                    'deliveryCount': 120,
                    'avgDeliveryValue': 15000,
                    'color': '#3b82f6'
                },
                {
                    'id': 'be',
                    'name': 'Bè',
                    'bounds': [[6.145, 1.205], [6.155, 1.215]],
                    'clientCount': 32,
                    'deliveryCount': 85,
                    'avgDeliveryValue': 12000,
                    'color': '#10b981'
                }
            ])
        
        @map_bp_fallback.route('/heatmap', methods=['GET'])
        @jwt_required()
        def get_heatmap_data():
            return jsonify({
                'points': [
                    {'lat': 6.132, 'lng': 1.221, 'intensity': 15},
                    {'lat': 6.137, 'lng': 1.219, 'intensity': 20},
                    {'lat': 6.126, 'lng': 1.236, 'intensity': 12}
                ],
                'maxIntensity': 20
            })
        
        @map_bp_fallback.route('/optimize-route/<int:agent_id>', methods=['POST'])
        @jwt_required()
        def optimize_route(agent_id):
            return jsonify({
                'agentId': str(agent_id),
                'waypoints': [[6.132, 1.221], [6.137, 1.219]],
                'totalDistance': 2.5,
                'estimatedTime': 5,
                'deliveries': [],
                'efficiency': 85
            })
        
        @map_bp_fallback.route('/export', methods=['POST'])
        @jwt_required()
        def export_map_data():
            return jsonify({'message': 'Export functionality'})
        
        app.register_blueprint(map_bp_fallback)
        print(" Routes map fallback créées")

    app.register_blueprint(auth_bp)
    app.register_blueprint(agent_bp)
    app.register_blueprint(client_bp)
    app.register_blueprint(client_extended_bp)
    app.register_blueprint(delivery_bp)
    app.register_blueprint(tour_bp)
    app.register_blueprint(order_bp)
    app.register_blueprint(audit_bp)
    app.register_blueprint(stats_bp)
    app.register_blueprint(product_bp)
    app.register_blueprint(user_bp)
    app.register_blueprint(stock_bp)
    app.register_blueprint(settings_bp)
    app.register_blueprint(socketio_bp)
    app.register_blueprint(reports_bp)
    app.register_blueprint(permissions_bp)
    app.register_blueprint(health_bp)
    from app.routes.evaluation_routes import eval_bp
    app.register_blueprint(eval_bp)

    # Enregistrer les routes notifications
    try:
        from app.routes.notifications_routes import notifications_bp
        app.register_blueprint(notifications_bp)
        print(" Routes notifications importées")
    except ImportError:
        print(" Routes notifications non trouvées")

    # Initialisation du Scheduler de Reporting
    try:
        from app.services.reporting_bot import init_scheduler
        init_scheduler(app)
    except Exception as e:
        print(f" Erreur démarrage scheduler: {e}")

    return app, socketio