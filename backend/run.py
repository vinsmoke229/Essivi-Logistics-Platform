import eventlet
eventlet.monkey_patch()

from app import create_app

app, socketio = create_app()

if __name__ == '__main__':
    # Utilisation de socketio.run avec eventlet (automatique via monkey_patch)
    print("🚀 Démarrage Serveur avec EVENTLET (Patch Windows Applied)")
    socketio.run(app, host='0.0.0.0', port=5000, debug=True)