from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt
from flask_socketio import SocketIO, emit, join_room, leave_room
from app import db
from datetime import datetime
import json


socketio = SocketIO(cors_allowed_origins="*", async_mode='threading')

notifications_bp = Blueprint('notifications', __name__, url_prefix='/api/notifications')


connected_users = {}

@socketio.on('connect')
def handle_connect():
    """Gérer la connexion d'un utilisateur"""
    try:
        
        token = request.args.get('token')
        if not token:
            emit('error', {'msg': 'Token manquant'})
            return False
        
        
        from flask_jwt_extended import decode_token
        try:
            decoded = decode_token(token)
            user_id = decoded['sub']
            user_type = decoded.get('type', 'unknown')
            role = decoded.get('role', 'user')
        except:
            emit('error', {'msg': 'Token invalide'})
            return False
        
        
        connected_users[request.sid] = {
            'user_id': user_id,
            'user_type': user_type,
            'role': role,
            'connected_at': datetime.utcnow()
        }
        
        
        if role == 'admin':
            join_room('admins')
        elif role == 'manager':
            join_room('managers')
        elif role == 'agent':
            join_room('agents')
        
        
        join_room(f'user_{user_id}')
        
        emit('connected', {
            'msg': 'Connecté avec succès',
            'user_id': user_id,
            'role': role,
            'timestamp': datetime.utcnow().isoformat()
        })
        
        print(f"✅ Utilisateur {user_id} ({role}) connecté")
        
    except Exception as e:
        emit('error', {'msg': f'Erreur de connexion: {str(e)}'})
        return False

@socketio.on('disconnect')
def handle_disconnect():
    """Gérer la déconnexion d'un utilisateur"""
    if request.sid in connected_users:
        user_info = connected_users[request.sid]
        print(f"❌ Utilisateur {user_info['user_id']} déconnecté")
        del connected_users[request.sid]

@socketio.on('join_room')
def handle_join_room(data):
    """Rejoindre une room spécifique"""
    try:
        room_name = data.get('room')
        if room_name:
            join_room(room_name)
            emit('joined_room', {'room': room_name})
    except Exception as e:
        emit('error', {'msg': f'Erreur: {str(e)}'})

@socketio.on('leave_room')
def handle_leave_room(data):
    """Quitter une room spécifique"""
    try:
        room_name = data.get('room')
        if room_name:
            leave_room(room_name)
            emit('left_room', {'room': room_name})
    except Exception as e:
        emit('error', {'msg': f'Erreur: {str(e)}'})



def notify_low_stock(product_info):
    """Notifier tous les admins du stock bas"""
    notification = {
        'type': 'low_stock_alert',
        'title': '⚠️ Stock Critique',
        'message': f"Stock bas pour {product_info.get('product_name', 'Produit')}",
        'data': product_info,
        'timestamp': datetime.utcnow().isoformat(),
        'priority': 'high'
    }
    
    socketio.emit('notification', notification, room='admins')
    print(f"📢 Notification stock bas envoyée aux admins")

def notify_new_order(order_info):
    """Notifier les managers d'une nouvelle commande"""
    notification = {
        'type': 'new_order',
        'title': '📦 Nouvelle Commande',
        'message': f"Nouvelle commande de {order_info.get('client_name', 'Client')}",
        'data': order_info,
        'timestamp': datetime.utcnow().isoformat(),
        'priority': 'medium'
    }
    
    socketio.emit('notification', notification, room='managers')
    print(f"📢 Notification nouvelle commande envoyée aux managers")

def notify_delivery_status_change(delivery_info):
    """Notifier du changement de statut d'une livraison"""
    notification = {
        'type': 'delivery_status_change',
        'title': '🚚 Mise à jour Livraison',
        'message': f"Livraison #{delivery_info.get('id')} : {delivery_info.get('status')}",
        'data': delivery_info,
        'timestamp': datetime.utcnow().isoformat(),
        'priority': 'medium'
    }
    
    
    if delivery_info.get('agent_id'):
        socketio.emit('notification', notification, room=f"user_{delivery_info['agent_id']}")
    
    
    socketio.emit('notification', notification, room='admins')
    print(f"📢 Notification statut livraison envoyée")

def notify_agent_position_update(agent_info):
    """Notifier de la mise à jour de position d'un agent"""
    notification = {
        'type': 'agent_position_update',
        'title': '📍 Position Agent',
        'message': f"Mise à jour position: {agent_info.get('agent_name', 'Agent')}",
        'data': agent_info,
        'timestamp': datetime.utcnow().isoformat(),
        'priority': 'low'
    }
    
    
    socketio.emit('agent_position', notification, room='admins')
    socketio.emit('agent_position', notification, room='managers')
    print(f"📢 Notification position agent envoyée")

def notify_system_alert(alert_info):
    """Notifier une alerte système"""
    notification = {
        'type': 'system_alert',
        'title': '🚨 Alerte Système',
        'message': alert_info.get('message', 'Alerte système'),
        'data': alert_info,
        'timestamp': datetime.utcnow().isoformat(),
        'priority': 'critical'
    }
    
    
    socketio.emit('system_alert', notification)
    print(f"📢 Alerte système envoyée à tous les utilisateurs")



@notifications_bp.route('/send', methods=['POST'])
@jwt_required()
def send_notification():
    """Envoyer une notification manuelle"""
    try:
        data = request.get_json()
        notification_type = data.get('type')
        target_role = data.get('target_role')  
        message = data.get('message')
        title = data.get('title')
        
        notification = {
            'type': 'manual_notification',
            'title': title,
            'message': message,
            'data': data.get('data', {}),
            'timestamp': datetime.utcnow().isoformat(),
            'priority': data.get('priority', 'medium')
        }
        
        
        if target_role == 'all':
            socketio.emit('notification', notification)
        elif target_role == 'admin':
            socketio.emit('notification', notification, room='admins')
        elif target_role == 'manager':
            socketio.emit('notification', notification, room='managers')
        elif target_role == 'agent':
            socketio.emit('notification', notification, room='agents')
        else:
            
            user_id = data.get('user_id')
            if user_id:
                socketio.emit('notification', notification, room=f"user_{user_id}")
        
        return jsonify({
            'msg': 'Notification envoyée avec succès',
            'target': target_role,
            'timestamp': notification['timestamp']
        }), 200
        
    except Exception as e:
        return jsonify({"msg": f"Erreur: {str(e)}"}), 500

@notifications_bp.route('/connected-users', methods=['GET'])
@jwt_required()
def get_connected_users():
    """Lister les utilisateurs connectés"""
    try:
        claims = get_jwt()
        if claims.get('role') not in ['admin', 'manager']:
            return jsonify({"msg": "Accès refusé"}), 403
        
        users_list = []
        for sid, user_info in connected_users.items():
            users_list.append({
                'sid': sid,
                'user_id': user_info['user_id'],
                'user_type': user_info['user_type'],
                'role': user_info['role'],
                'connected_at': user_info['connected_at'].isoformat()
            })
        
        return jsonify({
            'connected_users': users_list,
            'total_count': len(users_list),
            'timestamp': datetime.utcnow().isoformat()
        }), 200
        
    except Exception as e:
        return jsonify({"msg": f"Erreur: {str(e)}"}), 500

@notifications_bp.route('/history', methods=['GET'])
@jwt_required()
def get_notification_history():
    """Historique des notifications (si stocké en base)"""
    try:
        
        
        
        history = [
            {
                'id': 1,
                'type': 'low_stock_alert',
                'title': '⚠️ Stock Critique',
                'message': 'Stock bas pour Vitale 1.5L',
                'timestamp': '2024-01-24T10:30:00',
                'read': False,
                'priority': 'high'
            },
            {
                'id': 2,
                'type': 'new_order',
                'title': '📦 Nouvelle Commande',
                'message': 'Nouvelle commande de Boutique Mama Africa',
                'timestamp': '2024-01-24T09:15:00',
                'read': True,
                'priority': 'medium'
            }
        ]
        
        return jsonify({
            'notifications': history,
            'total_count': len(history),
            'unread_count': len([n for n in history if not n['read']])
        }), 200
        
    except Exception as e:
        return jsonify({"msg": f"Erreur: {str(e)}"}), 500
