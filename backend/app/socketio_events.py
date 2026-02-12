"""
Gestionnaires d'événements Socket.IO pour le système temps réel
Gère les connexions, déconnexions et les rooms (salles) par commande
"""
from flask_socketio import join_room, leave_room, emit
from flask import request
from app import socketio
from datetime import datetime


connected_users = {}

@socketio.on('connect')
def handle_connect():
    """Gestion de la connexion d'un client Socket.IO"""
    client_id = request.sid
    
    
    auth = request.args.get('token') or (request.headers.get('Authorization') or '').replace('Bearer ', '')
    
    connected_users[client_id] = {
        'sid': client_id,
        'connected_at': datetime.utcnow().isoformat(),
        'auth': bool(auth),
        'rooms': []
    }
    
    print(f"✅ Client connecté: {client_id}")
    emit('connection_established', {
        'sid': client_id,
        'timestamp': datetime.utcnow().isoformat(),
        'message': 'Connexion Socket.IO établie avec succès'
    })

@socketio.on('disconnect')
def handle_disconnect():
    """Gestion de la déconnexion d'un client"""
    client_id = request.sid
    
    if client_id in connected_users:
        del connected_users[client_id]
    
    print(f"❌ Client déconnecté: {client_id}")

@socketio.on('join_order')
def handle_join_order(data):
    """
    Permet à un client de rejoindre la room d'une commande spécifique
    Format: {'order_id': '123'}
    """
    try:
        order_id = data.get('order_id')
        
        if not order_id:
            emit('error', {'message': 'order_id manquant'})
            return
        
        room_name = f'order_{order_id}'
        join_room(room_name)
        
        
        client_id = request.sid
        if client_id in connected_users:
            if 'rooms' not in connected_users[client_id]:
                connected_users[client_id]['rooms'] = []
            connected_users[client_id]['rooms'].append(room_name)
        
        print(f"🚪 Client {client_id} a rejoint la room: {room_name}")
        
        emit('room_joined', {
            'room': room_name,
            'order_id': order_id,
            'timestamp': datetime.utcnow().isoformat(),
            'message': f'Vous suivez maintenant la commande #{order_id}'
        })
        
    except Exception as e:
        print(f"❌ Erreur join_order: {str(e)}")
        emit('error', {'message': f'Erreur lors de la jonction: {str(e)}'})

@socketio.on('leave_order')
def handle_leave_order(data):
    """
    Permet à un client de quitter la room d'une commande
    Format: {'order_id': '123'}
    """
    try:
        order_id = data.get('order_id')
        
        if not order_id:
            emit('error', {'message': 'order_id manquant'})
            return
        
        room_name = f'order_{order_id}'
        leave_room(room_name)
        
        
        client_id = request.sid
        if client_id in connected_users and 'rooms' in connected_users[client_id]:
            if room_name in connected_users[client_id]['rooms']:
                connected_users[client_id]['rooms'].remove(room_name)
        
        print(f"🚪 Client {client_id} a quitté la room: {room_name}")
        
        emit('room_left', {
            'room': room_name,
            'order_id': order_id,
            'timestamp': datetime.utcnow().isoformat(),
            'message': f'Vous ne suivez plus la commande #{order_id}'
        })
        
    except Exception as e:
        print(f"❌ Erreur leave_order: {str(e)}")
        emit('error', {'message': f'Erreur lors de la sortie: {str(e)}'})

@socketio.on('join_admin_map')
def handle_join_admin_map():
    """
    Permet aux administrateurs de rejoindre la room globale de la carte
    """
    try:
        room_name = 'admin_map'
        join_room(room_name)
        
        client_id = request.sid
        if client_id in connected_users:
            if 'rooms' not in connected_users[client_id]:
                connected_users[client_id]['rooms'] = []
            connected_users[client_id]['rooms'].append(room_name)
        
        print(f"🗺️ Admin {client_id} a rejoint la room: {room_name}")
        
        emit('room_joined', {
            'room': room_name,
            'timestamp': datetime.utcnow().isoformat(),
            'message': 'Vous suivez maintenant tous les agents en temps réel'
        })
        
    except Exception as e:
        print(f"❌ Erreur join_admin_map: {str(e)}")
        emit('error', {'message': f'Erreur: {str(e)}'})

@socketio.on('ping')
def handle_ping():
    """Répondre aux pings pour vérifier la connexion"""
    emit('pong', {
        'timestamp': datetime.utcnow().isoformat(),
        'server_time': datetime.utcnow().isoformat()
    })

@socketio.on('get_connection_info')
def handle_get_connection_info():
    """Retourner les informations de connexion du client"""
    client_id = request.sid
    
    info = connected_users.get(client_id, {})
    info['sid'] = client_id
    info['current_time'] = datetime.utcnow().isoformat()
    
    emit('connection_info', info)


def get_connected_users_list():
    """Retourne la liste des utilisateurs connectés"""
    return list(connected_users.values())
