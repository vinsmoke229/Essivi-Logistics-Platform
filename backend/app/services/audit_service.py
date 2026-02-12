from app import mongo_client
from datetime import datetime

def log_activity(user_id, user_type, action, details=None):
    """
    Enregistre une action dans MongoDB (Collection: activity_logs)
    """
    if not mongo_client:
        print("⚠️ MongoDB non connecté, log ignoré.")
        return

    db = mongo_client.get_database() 
    logs_collection = db.activity_logs

    log_entry = {
        "timestamp": datetime.utcnow(),
        "user_id": str(user_id),
        "user_type": user_type,
        "action": action,     
        "details": details or {} 
    }

    try:
        logs_collection.insert_one(log_entry)
        print(f"📝 Log MongoDB enregistré : {action}")
    except Exception as e:
        print(f"❌ Erreur Log MongoDB : {e}")