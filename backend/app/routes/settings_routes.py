from flask import Blueprint, jsonify, request, send_file
from app import db
from app.models.sql_models import SystemSettings, AuditLog, User
from flask_jwt_extended import jwt_required, get_jwt
from datetime import datetime
import os
import json
from werkzeug.utils import secure_filename
from app.utils.helpers import roles_required
from werkzeug.security import generate_password_hash
import subprocess
import traceback

settings_bp = Blueprint('settings', __name__, url_prefix='/api/settings')


UPLOAD_FOLDER = 'uploads/system'
BACKUP_FOLDER = 'uploads/backups'
for folder in [UPLOAD_FOLDER, BACKUP_FOLDER]:
    if not os.path.exists(folder):
        os.makedirs(folder, exist_ok=True)

def get_raw_settings():
    """Fonction utilitaire interne pour récupérer tous les paramètres"""
    settings = SystemSettings.query.all()
    result = {}
    for setting in settings:
        try:
            if setting.value and (setting.value.startswith('{') or setting.value.startswith('[')):
                result[setting.key] = json.loads(setting.value)
            elif setting.value == 'true': result[setting.key] = True
            elif setting.value == 'false': result[setting.key] = False
            else: result[setting.key] = setting.value
        except:
            result[setting.key] = setting.value
    
        defaults = {
            'platform_name': 'ESSIVI Delivery',
            'company_name': 'ESSIVI SARL',
            'company_logo': '/api/settings/logo-file/default_logo.png',
            'company_phone': '+228 00 00 00 00',
            'company_email': 'contact@essivi.com',
            'company_address': 'Lomé, Togo',
            'currency': 'FCFA',
            'timezone': 'Africa/Lome',
            'unit_price_vitale': 500,
            'unit_price_voltic': 600,
            'delivery_unit': 'Bouteille 1.5L',
            'avg_delivery_time': 45,
            'notifications_enabled': True,
            'notification_email': True,
            'notification_sms': False,
            'email_template_order': "Bonjour {client}, votre commande {order_id} est confirmée.",
            'sms_template_delivery': "Votre livreur {agent} arrive dans {time} min.",
            'low_stock_threshold': 10
        }
    
    for key, value in defaults.items():
        if key not in result:
            result[key] = value
            
    return result

@settings_bp.route('/system', methods=['GET'])
@jwt_required()
def get_system_settings():
    try:
        return jsonify(get_raw_settings()), 200
    except Exception as e:
        return jsonify({"msg": f"Erreur: {str(e)}"}), 500

@settings_bp.route('/system', methods=['PUT'])
@jwt_required()
@roles_required(['super_admin'])
def update_system_settings():
    try:
        data = request.get_json()
        for key, value in data.items():
            if isinstance(value, (dict, list)): val_str = json.dumps(value)
            elif isinstance(value, bool): val_str = 'true' if value else 'false'
            else: val_str = str(value)
            
            setting = SystemSettings.query.filter_by(key=key).first()
            if setting:
                setting.value = val_str
                setting.updated_at = datetime.utcnow()
            else:
                db.session.add(SystemSettings(key=key, value=val_str, category='general'))
        
        db.session.commit()
        return jsonify({"msg": "Configuration mise à jour"}), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({"msg": f"Erreur: {str(e)}"}), 500

@settings_bp.route('/logo', methods=['POST'])
@jwt_required()
@roles_required(['super_admin'])
def upload_logo():
    try:
        if 'logo' not in request.files: return jsonify({"msg": "Aucun fichier"}), 400
        file = request.files['logo']
        filename = secure_filename(f"logo_{datetime.now().strftime('%Y%m%d%H%M%S')}.png")
        file.save(os.path.join(UPLOAD_FOLDER, filename))
        url = f"/api/settings/logo-file/{filename}"
        
        setting = SystemSettings.query.filter_by(key='company_logo').first()
        if setting: setting.value = url
        else: db.session.add(SystemSettings(key='company_logo', value=url))
        db.session.commit()
        
        return jsonify({"msg": "Logo mis à jour", "url": url}), 200
    except Exception as e:
        return jsonify({"msg": f"Erreur upload: {str(e)}"}), 500

@settings_bp.route('/logo-file/<filename>', methods=['GET'])
def get_logo_file(filename):
    filepath = os.path.join(UPLOAD_FOLDER, filename)
    if os.path.exists(filepath): return send_file(filepath)
    return jsonify({"msg": "Non trouvé"}), 404


@settings_bp.route('/pricing', methods=['GET'])
@jwt_required()
def get_pricing():
    settings = get_raw_settings()
    return jsonify({
        'Vitale': settings.get('unit_price_vitale', 500),
        'Voltic': settings.get('unit_price_voltic', 600),
        'unit': settings.get('delivery_unit', 'Bouteille')
    }), 200


@settings_bp.route('/backups', methods=['GET'])
@jwt_required()
@roles_required(['super_admin'])
def list_backups():
    try:
        backups = []
        if os.path.exists(BACKUP_FOLDER):
            for f in os.listdir(BACKUP_FOLDER):
                if f.endswith('.sql') or f.endswith('.backup'):
                    path = os.path.join(BACKUP_FOLDER, f)
                    stats = os.stat(path)
                    backups.append({
                        "id": f,
                        "filename": f,
                        "created_at": datetime.fromtimestamp(stats.st_ctime).isoformat(),
                        "size": stats.st_size
                    })
        return jsonify(sorted(backups, key=lambda x: x['created_at'], reverse=True)), 200
    except Exception as e:
        return jsonify({"msg": str(e)}), 500

@settings_bp.route('/backup', methods=['POST'])
@jwt_required()
@roles_required(['super_admin'])
def create_backup():
    """
    Crée une sauvegarde réelle de la base de données PostgreSQL avec pg_dump
    """
    try:
        filename = f"backup_{datetime.now().strftime('%Y%m%d_%H%M%S')}.sql"
        path = os.path.join(BACKUP_FOLDER, filename)
        
        
        db_user = os.environ.get('DB_USER', 'postgres')
        db_password = os.environ.get('DB_PASSWORD', 'inf123')
        db_host = os.environ.get('DB_HOST', '127.0.0.1')
        db_port = os.environ.get('DB_PORT', '5432')
        db_name = os.environ.get('DB_NAME', 'essivi_db')
        
        
        env = os.environ.copy()
        env['PGPASSWORD'] = db_password
        
        cmd = [
            'pg_dump',
            '-h', db_host,
            '-p', db_port,
            '-U', db_user,
            '-d', db_name,
            '-F', 'p',  
            '-f', path
        ]
        
        
        print(f"🚀 Executing command: {' '.join(cmd)}")
        
        try:
            result = subprocess.run(cmd, env=env, capture_output=True, text=True, check=True)
        except Exception as e:
            print("❌ CRASH LORS DE L'EXÉCUTION DE PG_DUMP")
            traceback.print_exc()
            return jsonify({
                "msg": "La sauvegarde a échoué (Exception système)",
                "error": str(e)
            }), 500
        
        if result.returncode != 0:
            print(f"❌ Erreur pg_dump: {result.stderr}")
            
            with open(path, 'w', encoding='utf-8') as f:
                f.write(f"-- ESSIVI DATABASE BACKUP --\n")
                f.write(f"-- Date: {datetime.now().isoformat()}\n")
                f.write(f"-- Note: pg_dump non disponible, sauvegarde partielle\n")
            return jsonify({
                "msg": "Sauvegarde créée (mode dégradé)",
                "filename": filename,
                "backup_url": f"/api/settings/backup-file/{filename}",
                "warning": "pg_dump non disponible"
            }), 200
        
        print(f"✅ Sauvegarde créée: {filename}")
        return jsonify({
            "msg": "Sauvegarde créée avec succès",
            "filename": filename,
            "backup_url": f"/api/settings/backup-file/{filename}"
        }), 200
        
    except Exception as e:
        print(f"❌ Erreur backup: {str(e)}")
        return jsonify({"msg": f"Erreur: {str(e)}"}), 500

@settings_bp.route('/backup-file/<filename>', methods=['GET'])
@jwt_required()
@roles_required(['super_admin'])
def get_backup_file(filename):
    """Servir le fichier backup pour téléchargement"""
    filepath = os.path.join(BACKUP_FOLDER, filename)
    if os.path.exists(filepath):
        return send_file(filepath, as_attachment=True)
    return jsonify({"msg": "Fichier non trouvé"}), 404


@settings_bp.route('/security-logs', methods=['GET'])
@jwt_required()
@roles_required(['super_admin'])
def get_security_logs():
    try:
        logs = AuditLog.query.order_by(AuditLog.timestamp.desc()).limit(50).all()
        return jsonify([{
            "id": l.id,
            "action": l.action,
            "user": l.user.username if l.user else "System",
            "timestamp": l.timestamp.isoformat(),
            "ip_address": l.ip_address or "0.0.0.0"
        } for l in logs]), 200
    except Exception as e:
        return jsonify({"msg": str(e)}), 500

@settings_bp.route('/change-password', methods=['POST'])
@jwt_required()
def change_password():
    try:
        data = request.get_json()
        user_id = get_jwt().get('sub')
        user = User.query.get(user_id)
        if not user: return jsonify({"msg": "Utilisateur non trouvé"}), 404
        
        
        
        user.password_hash = generate_password_hash(data.get('new_password'))
        db.session.commit()
        return jsonify({"msg": "Mot de passe changé"}), 200
    except Exception as e:
        return jsonify({"msg": str(e)}), 500

@settings_bp.route('/test-email', methods=['POST'])
@jwt_required()
def test_email():
    return jsonify({"msg": "Email de test envoyé (simulation)"}), 200
