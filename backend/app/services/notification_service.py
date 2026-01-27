from flask import current_app
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
import requests
import os
from typing import Optional

class NotificationService:
    """Service centralisé pour les notifications email et SMS"""
    
    def __init__(self):
        self.smtp_server = os.getenv('SMTP_SERVER', 'smtp.gmail.com')
        self.smtp_port = int(os.getenv('SMTP_PORT', '587'))
        self.smtp_username = os.getenv('SMTP_USERNAME', '')
        self.smtp_password = os.getenv('SMTP_PASSWORD', '')
        self.from_email = os.getenv('FROM_EMAIL', 'noreply@essivi.com')
        
        # Configuration SMS (exemple avec API Twilio)
        self.sms_api_key = os.getenv('SMS_API_KEY', '')
        self.sms_api_secret = os.getenv('SMS_API_SECRET', '')
        self.sms_from_number = os.getenv('SMS_FROM_NUMBER', '')
    
    def send_email(
        self, 
        to_email: str, 
        subject: str, 
        html_content: str, 
        text_content: Optional[str] = None
    ) -> bool:
        """Envoyer un email HTML"""
        try:
            if not self.smtp_username or not self.smtp_password:
                print("⚠️ Configuration SMTP manquante - Email simulation")
                print(f"TO: {to_email}")
                print(f"SUBJECT: {subject}")
                print(f"CONTENT: {html_content[:100]}...")
                return True
            
            # Créer le message
            msg = MIMEMultipart('alternative')
            msg['Subject'] = subject
            msg['From'] = f"ESSIVI <{self.from_email}>"
            msg['To'] = to_email
            
            # Ajouter les versions texte et HTML
            if text_content:
                text_part = MIMEText(text_content, 'plain')
                msg.attach(text_part)
            
            html_part = MIMEText(html_content, 'html')
            msg.attach(html_part)
            
            # Envoyer l'email
            with smtplib.SMTP(self.smtp_server, self.smtp_port) as server:
                server.starttls()
                server.login(self.smtp_username, self.smtp_password)
                server.send_message(msg)
            
            print(f"✅ Email envoyé à {to_email}: {subject}")
            return True
            
        except Exception as e:
            print(f"❌ Erreur envoi email à {to_email}: {str(e)}")
            return False
    
    def send_sms(self, to_phone: str, message: str) -> bool:
        """Envoyer un SMS (exemple avec Twilio)"""
        try:
            if not self.sms_api_key or not self.sms_from_number:
                print("⚠️ Configuration SMS manquante - SMS simulation")
                print(f"TO: {to_phone}")
                print(f"MESSAGE: {message}")
                return True
            
            # Exemple avec API Twilio
            url = f"https://api.twilio.com/2010-04-01/Accounts/{self.sms_api_key}/Messages.json"
            data = {
                'From': self.sms_from_number,
                'To': to_phone,
                'Body': message
            }
            
            response = requests.post(
                url,
                auth=(self.sms_api_key, self.sms_api_secret),
                data=data
            )
            
            if response.status_code == 201:
                print(f"✅ SMS envoyé à {to_phone}")
                return True
            else:
                print(f"❌ Erreur SMS: {response.text}")
                return False
                
        except Exception as e:
            print(f"❌ Erreur envoi SMS à {to_phone}: {str(e)}")
            return False
    
    def get_settings(self):
        """Récupérer les paramètres depuis la base de données sans imports circulaires"""
        try:
            from app.models.sql_models import SystemSettings
            settings = SystemSettings.query.all()
            result = {}
            for s in settings:
                if s.value == 'true': result[s.key] = True
                elif s.value == 'false': result[s.key] = False
                else: result[s.key] = s.value
            return result
        except:
            return {}

    def send_delivery_notification(self, agent_email: str, agent_phone: str, delivery_info: dict) -> bool:
        """Notifier un agent ou client pour une nouvelle livraison avec modèles dynamiques"""
        settings = self.get_settings()
        
        # Vérifier si les notifications sont activées globalement
        if not settings.get('notifications_enabled', True):
            print("🚫 Notifications désactivées dans les paramètres.")
            return False

        # --- EMAIL ---
        email_sent = False
        if settings.get('notification_email', True):
            template = settings.get('email_template_order', "Bonjour {client}, votre commande {order_id} est confirmée.")
            subject = f"📦 Livraison ESSIVI - {delivery_info.get('client_name', 'Client')}"
            
            # Remplacement des tags
            message_body = template.format(
                client=delivery_info.get('client_name', 'Client'),
                order_id=delivery_info.get('id', 'N/A'),
                amount=delivery_info.get('total_amount', 0)
            )
            
            html_content = f"""
            <html>
            <body style="font-family: Arial, sans-serif;">
                <div style="padding: 20px; border: 1px solid #eee; border-radius: 10px;">
                    <h2 style="color: #2563eb;">ESSIVI Delivery</h2>
                    <p>{message_body}</p>
                    <hr>
                    <p><strong>Détails:</strong> Vitale: {delivery_info.get('quantity_vitale', 0)} | Voltic: {delivery_info.get('quantity_voltic', 0)}</p>
                    <p><strong>Livreur:</strong> {delivery_info.get('agent_name', 'Assigné')}</p>
                </div>
            </body>
            </html>
            """
            email_sent = self.send_email(agent_email, subject, html_content, message_body)

        # --- SMS ---
        sms_sent = False
        if settings.get('notification_sms', False):
            template = settings.get('sms_template_delivery', "Votre livreur {agent} arrive dans {time} min.")
            
            sms_body = template.format(
                agent=delivery_info.get('agent_name', 'Livreur'),
                time=settings.get('avg_delivery_time', 45)
            )
            sms_sent = self.send_sms(agent_phone, sms_body)
        
        return email_sent or sms_sent
    
    def send_low_stock_alert(self, admin_email: str, product_info: dict) -> bool:
        """Alerte stock bas aux administrateurs"""
        settings = self.get_settings()
        if not settings.get('notifications_enabled', True):
            return False
            
        subject = f"⚠️ Alerte Stock Critique - {product_info.get('product_name', 'Produit')}"
        
        html_content = f"""
        <html>
        <body>
            <h2>🚨 Alerte Stock Critique</h2>
            
            <h3>Produit concerné:</h3>
            <ul>
                <li><strong>Nom:</strong> {product_info.get('product_name', 'N/A')}</li>
                <li><strong>Stock actuel:</strong> {product_info.get('current_stock', 0)} unités</li>
                <li><strong>Seuil d'alerte:</strong> {product_info.get('threshold', 0)} unités</li>
                <li><strong>Statut:</strong> {'RUPTURE' if product_info.get('current_stock', 0) == 0 else 'STOCK BAS'}</li>
            </ul>
            
            <p><strong>Veuillez réapprovisionner ce produit dès que possible.</strong></p>
            
            <hr>
            <p><small>Ceci est une alerte automatique de la plateforme ESSIVI</small></p>
        </body>
        </html>
        """
        
        text_content = f"""
        ALERTE STOCK CRITIQUE - ESSIVI
        
        Produit: {product_info.get('product_name', 'N/A')}
        Stock actuel: {product_info.get('current_stock', 0)} unités
        Seuil d'alerte: {product_info.get('threshold', 0)} unités
        
        Veuillez réapprovisionner ce produit dès que possible.
        """
        
        return self.send_email(admin_email, subject, html_content, text_content)
    
    def send_welcome_email(self, user_email: str, user_name: str, user_type: str, temp_password: str = None) -> bool:
        """Email de bienvenue pour les nouveaux utilisateurs"""
        settings = self.get_settings()
        if not settings.get('notifications_enabled', True):
            return False

        subject = "Bienvenue sur la plateforme ESSIVI"
        
        if temp_password:
            html_content = f"""
            <html>
            <body>
                <h2>👋 Bienvenue {user_name} sur ESSIVI</h2>
                
                <p>Votre compte {user_type} a été créé avec succès.</p>
                
                <h3>Vos identifiants de connexion:</h3>
                <ul>
                    <li><strong>Email:</strong> {user_email}</li>
                    <li><strong>Mot de passe temporaire:</strong> {temp_password}</li>
                </ul>
                
                <p><strong>Veuillez changer votre mot de passe lors de votre première connexion.</strong></p>
                
                <p><a href="#" style="background: #2563eb; color: white; padding: 10px 20px; text-decoration: none; border-radius: 5px;">Se connecter</a></p>
                
                <hr>
                <p><small>Ceci est un message automatique de la plateforme ESSIVI</small></p>
            </body>
            </html>
            """
            text_content = f"""
            BIENVENUE SUR ESSIVI
            
            Bonjour {user_name},
            
            Votre compte {user_type} a été créé avec succès.
            
            Identifiants:
            Email: {user_email}
            Mot de passe temporaire: {temp_password}
            
            Veuillez changer votre mot de passe lors de votre première connexion.
            """
        else:
            html_content = f"""
            <html>
            <body>
                <h2>👋 Bienvenue {user_name} sur ESSIVI</h2>
                <p>Votre compte {user_type} a été configuré avec succès.</p>
                <p>Vous pouvez maintenant vous connecter à la plateforme.</p>
                <hr>
                <p><small>Ceci est un message automatique de la plateforme ESSIVI</small></p>
            </body>
            </html>
            """
            text_content = f"""
            BIENVENUE SUR ESSIVI
            
            Bonjour {user_name},
            
            Votre compte {user_type} a été configuré avec succès.
            Vous pouvez maintenant vous connecter à la plateforme.
            """
        
        return self.send_email(user_email, subject, html_content, text_content)

# Instance globale du service
notification_service = NotificationService()
