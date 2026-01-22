from app import db
from datetime import datetime
from sqlalchemy import Date

# 1. Table des Utilisateurs du Back-office (Admin, Gestionnaire)
class User(db.Model):
    __tablename__ = 'users'
    
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(50), unique=True, nullable=False)
    email = db.Column(db.String(120), unique=True, nullable=False)
    password_hash = db.Column(db.String(256), nullable=False)
    role = db.Column(db.String(20), default='admin') # admin, manager, supervisor
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    def __repr__(self):
        return f'<User {self.username}>'

# 2. Table des Agents Commerciaux (Livreurs)
class Agent(db.Model):
    __tablename__ = 'agents'

    id = db.Column(db.Integer, primary_key=True)
    matricule = db.Column(db.String(20), unique=True, nullable=False)
    full_name = db.Column(db.String(100), nullable=False)
    phone = db.Column(db.String(20), unique=True, nullable=False)
    password_hash = db.Column(db.String(256), nullable=False)
    
    email = db.Column(db.String(120), unique=True, nullable=True)
    address = db.Column(db.String(200), nullable=True)
    photo_url = db.Column(db.Text, nullable=True) # Text pour Base64
    date_of_birth = db.Column(db.Date, nullable=True)
    hire_date = db.Column(db.Date, nullable=True, default=datetime.utcnow)
    
    tricycle_plate = db.Column(db.String(20))
    is_active = db.Column(db.Boolean, default=True)
    
    last_lat = db.Column(db.Float)
    last_lng = db.Column(db.Float)
    last_seen = db.Column(db.DateTime)
    
    deliveries = db.relationship('Delivery', backref='agent', lazy=True)
    orders = db.relationship('Order', backref='agent', lazy=True)

    def __repr__(self):
        return f'<Agent {self.full_name}>'

# 3. Table des Clients (Points de vente)
class Client(db.Model):
    __tablename__ = 'clients'

    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), nullable=False)
    responsible_name = db.Column(db.String(100))
    phone = db.Column(db.String(20), unique=True, nullable=False)
    address = db.Column(db.String(200))

    email = db.Column(db.String(120), unique=True, nullable=True)
    client_type = db.Column(db.String(50), nullable=True)
    photo_of_point_of_sale = db.Column(db.Text, nullable=True) # Text pour Base64
    balance = db.Column(db.Float, default=0.0)
    
    gps_lat = db.Column(db.Float)
    gps_lng = db.Column(db.Float)
    pin_hash = db.Column(db.String(256))
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    deliveries = db.relationship('Delivery', backref='client', lazy=True)
    orders = db.relationship('Order', backref='client', lazy=True)
    evaluations = db.relationship('Evaluation', backref='client', lazy=True)

    def __repr__(self):
        return f'<Client {self.name}>'

# 4. Table des Produits
class Product(db.Model):
    __tablename__ = 'products'

    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), unique=True, nullable=False)
    price = db.Column(db.Float, nullable=False)
    is_active = db.Column(db.Boolean, default=True)

# 5. Table de liaison pour les livraisons
class DeliveryItem(db.Model):
    __tablename__ = 'delivery_items'

    id = db.Column(db.Integer, primary_key=True)
    delivery_id = db.Column(db.Integer, db.ForeignKey('deliveries.id'), nullable=False)
    product_id = db.Column(db.Integer, db.ForeignKey('products.id'), nullable=False)
    quantity = db.Column(db.Integer, nullable=False)
    product = db.relationship('Product')

# 6. Table de liaison pour les commandes
class OrderItem(db.Model):
    __tablename__ = 'order_items'
    
    id = db.Column(db.Integer, primary_key=True)
    order_id = db.Column(db.Integer, db.ForeignKey('orders.id'), nullable=False)
    product_id = db.Column(db.Integer, db.ForeignKey('products.id'), nullable=False)
    quantity = db.Column(db.Integer, nullable=False)
    product = db.relationship('Product')

# 7. Table des Livraisons
class Delivery(db.Model):
    __tablename__ = 'deliveries'

    id = db.Column(db.Integer, primary_key=True)
    date = db.Column(db.DateTime, default=datetime.utcnow)
    
    agent_id = db.Column(db.Integer, db.ForeignKey('agents.id'), nullable=False)
    client_id = db.Column(db.Integer, db.ForeignKey('clients.id'), nullable=False)
    
    quantity_vitale = db.Column(db.Integer, default=0)
    quantity_voltic = db.Column(db.Integer, default=0)

    total_amount = db.Column(db.Float, nullable=False)
    
    gps_lat_delivery = db.Column(db.Float)
    gps_lng_delivery = db.Column(db.Float)
    
    photo_url = db.Column(db.Text) # CORRECTION ICI : Text pour accepter de longues chaînes
    signature_url = db.Column(db.Text) # CORRECTION ICI : Text pour accepter de longues chaînes
    
    status = db.Column(db.String(20), default='completed')

    items = db.relationship('DeliveryItem', backref='delivery', lazy=True, cascade="all, delete-orphan")
    evaluation = db.relationship('Evaluation', backref='delivery', uselist=False, lazy=True, cascade="all, delete-orphan")

    def __repr__(self):
        return f'<Delivery {self.id} - {self.total_amount} FCFA>'
    
# 8. Table des Commandes
class Order(db.Model):
    __tablename__ = 'orders'

    id = db.Column(db.Integer, primary_key=True)
    client_id = db.Column(db.Integer, db.ForeignKey('clients.id'), nullable=False)
    agent_id = db.Column(db.Integer, db.ForeignKey('agents.id'), nullable=True)
    
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    preferred_delivery_time = db.Column(db.String(100))
    status = db.Column(db.String(20), default='pending') 
    
    instructions = db.Column(db.Text)
    items = db.relationship('OrderItem', backref='order', lazy=True, cascade="all, delete-orphan")

    def __repr__(self):
        return f'<Order {self.id} Client-{self.client_id}>'

# 9. Table des Évaluations
class Evaluation(db.Model):
    __tablename__ = 'evaluations'

    id = db.Column(db.Integer, primary_key=True)
    rating = db.Column(db.Integer, nullable=False)
    comment = db.Column(db.Text, nullable=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    delivery_id = db.Column(db.Integer, db.ForeignKey('deliveries.id'), unique=True, nullable=False)
    client_id = db.Column(db.Integer, db.ForeignKey('clients.id'), nullable=False)

    def __repr__(self):
        return f'<Evaluation {self.id} - {self.rating} stars>'

# 10. Table des Tournées
class Tour(db.Model):
    __tablename__ = 'tours'

    id = db.Column(db.Integer, primary_key=True)
    agent_id = db.Column(db.Integer, db.ForeignKey('agents.id'), nullable=False)
    
    start_time = db.Column(db.DateTime, default=datetime.utcnow)
    end_time = db.Column(db.DateTime, nullable=True)
    
    start_lat = db.Column(db.Float)
    start_lng = db.Column(db.Float)
    
    end_lat = db.Column(db.Float, nullable=True)
    end_lng = db.Column(db.Float, nullable=True)

    total_deliveries = db.Column(db.Integer, default=0)
    total_cash_collected = db.Column(db.Float, default=0.0)

    def __repr__(self):
        return f'<Tour Agent-{self.agent_id}>'

# 11. Table des Logs d'Audit
class AuditLog(db.Model):
    __tablename__ = 'audit_logs'

    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=True)
    agent_id = db.Column(db.Integer, db.ForeignKey('agents.id'), nullable=True)
    
    action = db.Column(db.String(100), nullable=False)
    entity_type = db.Column(db.String(50))
    entity_id = db.Column(db.Integer)
    
    details = db.Column(db.Text)
    ip_address = db.Column(db.String(45))
    timestamp = db.Column(db.DateTime, default=datetime.utcnow)

    user = db.relationship('User', backref='audit_logs', lazy=True)
    agent = db.relationship('Agent', backref='audit_logs_agent', lazy=True)

    def __repr__(self):
        return f'<AuditLog {self.action} by ID:{self.user_id or self.agent_id}>'