"""
Routes Socket.IO pour les événements temps réel
"""
from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt
from app.services.socketio_service import (
    emit_to_user, emit_to_admins, emit_to_agents, emit_to_all,
    notify_new_delivery, notify_agent_position_update, notify_low_stock,
    notify_delivery_status_update, notify_new_order, notify_system_alert,
    get_connected_users
)
from datetime import datetime

socketio_bp = Blueprint('socketio', __name__, url_prefix='/api/socketio')

@socketio_bp.route('/connected-users', methods=['GET'])
@jwt_required()
def get_connected_users_endpoint():
    """Récupérer la liste des utilisateurs connectés"""
    try:
        claims = get_jwt()
        if claims.get('type') != 'admin':
            return jsonify({"msg": "Accès réservé aux administrateurs"}), 403
        
        connected = get_connected_users()
        return jsonify({
            'connected_users': connected,
            'total_count': len(connected),
            'timestamp': datetime.utcnow().isoformat()
        }), 200
    
    except Exception as e:
        return jsonify({"msg": f"Erreur: {str(e)}"}), 500

@socketio_bp.route('/send-notification', methods=['POST'])
@jwt_required()
def send_notification():
    """Envoyer une notification personnalisée"""
    try:
        claims = get_jwt()
        data = request.get_json()
        
        # Seuls les admins peuvent envoyer des notifications
        if claims.get('type') != 'admin':
            return jsonify({"msg": "Accès réservé aux administrateurs"}), 403
        
        target_user = data.get('target_user')
        event = data.get('event', 'custom_notification')
        message = data.get('message', '')
        notification_data = data.get('data', {})
        
        if target_user:
            # Notification à un utilisateur spécifique
            emit_to_user(target_user, event, {
                'message': message,
                'data': notification_data,
                'sender': claims.get('sub'),
                'timestamp': datetime.utcnow().isoformat()
            })
        else:
            # Notification à tous
            target_type = data.get('target_type', 'all')
            if target_type == 'admins':
                emit_to_admins(event, {
                    'message': message,
                    'data': notification_data,
                    'sender': claims.get('sub'),
                    'timestamp': datetime.utcnow().isoformat()
                })
            elif target_type == 'agents':
                emit_to_agents(event, {
                    'message': message,
                    'data': notification_data,
                    'sender': claims.get('sub'),
                    'timestamp': datetime.utcnow().isoformat()
                })
            else:
                emit_to_all(event, {
                    'message': message,
                    'data': notification_data,
                    'sender': claims.get('sub'),
                    'timestamp': datetime.utcnow().isoformat()
                })
        
        return jsonify({
            "msg": "Notification envoyée avec succès",
            "target": target_user or target_type,
            "event": event
        }), 200
    
    except Exception as e:
        return jsonify({"msg": f"Erreur: {str(e)}"}), 500

@socketio_bp.route('/test-delivery', methods=['POST'])
@jwt_required()
def test_delivery_notification():
    """Tester l'envoi de notification de livraison"""
    try:
        claims = get_jwt()
        if claims.get('type') != 'admin':
            return jsonify({"msg": "Accès réservé aux administrateurs"}), 403
        
        data = request.get_json()
        delivery_data = {
            'id': data.get('delivery_id', 'test-001'),
            'client_name': data.get('client_name', 'Client Test'),
            'agent_name': data.get('agent_name', 'Agent Test'),
            'status': data.get('status', 'en cours'),
            'amount': data.get('amount', 5000)
        }
        
        notify_new_delivery(delivery_data)
        
        return jsonify({
            "msg": "Notification de livraison test envoyée",
            "delivery": delivery_data
        }), 200
    
    except Exception as e:
        return jsonify({"msg": f"Erreur: {str(e)}"}), 500

@socketio_bp.route('/test-stock-alert', methods=['POST'])
@jwt_required()
def test_stock_alert():
    """Tester l'envoi d'alerte de stock"""
    try:
        claims = get_jwt()
        if claims.get('type') != 'admin':
            return jsonify({"msg": "Accès réservé aux administrateurs"}), 403
        
        data = request.get_json()
        product_data = {
            'id': data.get('product_id', 'test-001'),
            'name': data.get('product_name', 'Vitale 1.5L'),
            'current_stock': data.get('current_stock', 5),
            'threshold': data.get('threshold', 10),
            'unit': 'bouteilles'
        }
        
        notify_low_stock(product_data)
        
        return jsonify({
            "msg": "Alerte de stock test envoyée",
            "product": product_data
        }), 200
    
    except Exception as e:
        return jsonify({"msg": f"Erreur: {str(e)}"}), 500

@socketio_bp.route('/broadcast-message', methods=['POST'])
@jwt_required()
def broadcast_message():
    """Diffuser un message à tous les utilisateurs"""
    try:
        claims = get_jwt()
        data = request.get_json()
        
        # Seuls les admins peuvent diffuser des messages
        if claims.get('type') != 'admin':
            return jsonify({"msg": "Accès réservé aux administrateurs"}), 403
        
        message = data.get('message', '')
        message_type = data.get('type', 'info')  # info, warning, error, success
        
        emit_to_all('broadcast_message', {
            'message': message,
            'type': message_type,
            'sender': claims.get('sub'),
            'sender_name': claims.get('name', 'Admin'),
            'timestamp': datetime.utcnow().isoformat()
        })
        
        return jsonify({
            "msg": "Message diffusé avec succès",
            "message": message,
            "type": message_type
        }), 200
    
    except Exception as e:
        return jsonify({"msg": f"Erreur: {str(e)}"}), 500
