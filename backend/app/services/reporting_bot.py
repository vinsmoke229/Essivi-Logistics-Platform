from flask_apscheduler import APScheduler
from app.models.sql_models import Delivery, User, Agent
from app.services.notification_service import notification_service
from datetime import datetime, timedelta
from app import db
import sqlalchemy as sa
import os

scheduler = APScheduler()

def send_daily_digest(app):
    """Calcule et envoie le résumé des activités du jour aux admins."""
    with app.app_context():
        today = datetime.utcnow().date()
        
        # 1. Calcul des statistiques du jour
        deliveries = Delivery.query.filter(Delivery.date >= today).all()
        total_revenue = sum(d.total_amount for d in deliveries)
        total_vitale = sum(d.quantity_vitale for d in deliveries)
        total_voltic = sum(d.quantity_voltic for d in deliveries)
        
        # 2. Top Livreur
        top_agent_data = db.session.query(
            Delivery.agent_id, 
            sa.func.sum(Delivery.total_amount).label('revenue')
        ).filter(Delivery.date >= today).group_by(Delivery.agent_id).order_by(sa.text('revenue DESC')).first()
        
        top_agent_name = "N/A"
        if top_agent_data:
            agent = Agent.query.get(top_agent_data.agent_id)
            if agent:
                top_agent_name = f"{agent.full_name} ({top_agent_data.revenue:,.0f} F)"

        # 3. Récupérer les admins
        admins = User.query.filter_by(role='admin').all()
        admin_emails = [a.email for a in admins if a.email]
        
        if not admin_emails:
            print("Aucun administrateur trouvé pour l'envoi du rapport.")
            return

        # 4. Préparation du contenu HTML
        subject = f"📊 Rapport Journalier ESSIVI - {today.strftime('%d/%m/%Y')}"
        
        html_content = f"""
        <html>
        <body style="font-family: Arial, sans-serif; color: #333;">
            <div style="max-width: 600px; margin: 0 auto; border: 1px solid #eee; padding: 20px; border-radius: 10px;">
                <h2 style="color: #2563eb; text-align: center;">Résumé ESSIVI - {today.strftime('%d/%m/%Y')}</h2>
                <hr>
                <div style="margin: 20px 0;">
                    <p><strong>💰 Chiffre d'Affaires :</strong> <span style="font-size: 1.2em; color: #059669;">{total_revenue:,.0f} FCFA</span></p>
                    <p><strong>📦 Total Livraisons :</strong> {len(deliveries)}</p>
                    <p><strong>💧 Vitale (Packs) :</strong> {total_vitale}</p>
                    <p><strong>💧 Voltic (Packs) :</strong> {total_voltic}</p>
                    <p><strong>🏆 Livreur du jour :</strong> {top_agent_name}</p>
                </div>
                <div style="background: #f8fafc; padding: 15px; border-radius: 5px; font-size: 0.9em; color: #64748b;">
                    Ce rapport a été généré automatiquement par le Bot ESSIVI.
                </div>
            </div>
        </body>
        </html>
        """

        # 5. Envoi
        for email in admin_emails:
            try:
                notification_service.send_email(email, subject, html_content)
                print(f"Rapport envoyé à {email}")
            except Exception as e:
                print(f"Erreur envoi rapport à {email}: {e}")

def init_scheduler(app):
    """Initialise et démarre le planificateur de tâches."""
    if not app.debug or os.environ.get("WERKZEUG_RUN_MAIN") == "true":
        scheduler.init_app(app)
        
        # Planifier l'envoi tous les jours à 20:00 (ajustable)
        @scheduler.task('cron', id='do_daily_report', hour=20, minute=0)
        def daily_report_task():
            send_daily_digest(app)
            
        scheduler.start()
        print("⏰ Scheduler ESSIVI démarré (Rapport quotidien à 20:00)")
