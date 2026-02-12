import socketio


sio = socketio.Client()

@sio.event
def connect():
    print('✅ Connexion Socket.IO établie')
    print('🔑 Envoi du token de test...')
    
    
    sio.emit('authenticate', {'token': 'test-token'})

@sio.event
def disconnect():
    print('❌ Déconnecté du serveur Socket.IO')

@sio.event
def connection_established(data):
    print(f'🎉 Connexion confirmée: {data}')

@sio.event
def custom_notification(data):
    print(f'📢 Notification reçue: {data}')

@sio.event
def connect_error(data):
    print(f'❌ Erreur de connexion: {data}')

if __name__ == '__main__':
    try:
        print('🔌 Tentative de connexion au serveur Socket.IO...')
        sio.connect('http://1.1.1.17:5000')
        print('🎯 Connecté avec succès !')
        print('📡 En attente de messages...')
        
        
        sio.wait()
        
    except Exception as e:
        print(f'❌ Erreur: {e}')
    finally:
        sio.disconnect()
