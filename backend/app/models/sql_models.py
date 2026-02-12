from app import db
from datetime import datetime

class User(db.Model):
    __tablename__ = 'users'
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(50), unique=True, nullable=False)
    full_name = db.Column(db.String(100))
    email = db.Column(db.String(120), unique=True, nullable=False)
    password_hash = db.Column(db.String(256), nullable=False)
    role = db.Column(db.String(20), default='manager') # super_admin, manager, supervisor
    is_active = db.Column(db.Boolean, default=True)
    last_login = db.Column(db.DateTime)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

class Agent(db.Model):
    __tablename__ = 'agents'
    id = db.Column(db.Integer, primary_key=True)
    matricule = db.Column(db.String(20), unique=True, nullable=False)
    full_name = db.Column(db.String(100), nullable=False)
    phone = db.Column(db.String(20), unique=True, nullable=False)
    password_hash = db.Column(db.String(256), nullable=False)
    email = db.Column(db.String(120), unique=True, nullable=True)
    address = db.Column(db.String(200), nullable=True)
    photo_url = db.Column(db.Text, nullable=True)
    birth_date = db.Column(db.Date, nullable=True)
    hire_date = db.Column(db.Date, nullable=True)
    average_rating = db.Column(db.Float, default=5.0)
    punctuality_rate = db.Column(db.Float, default=100.0)
    tricycle_plate = db.Column(db.String(20))
    is_active = db.Column(db.Boolean, default=True)
    last_lat = db.Column(db.Float)
    last_lng = db.Column(db.Float)
    last_seen = db.Column(db.DateTime)
    is_on_duty = db.Column(db.Boolean, default=False)
    
    deliveries = db.relationship('Delivery', backref='agent', lazy=True)
    orders = db.relationship('Order', backref='agent', lazy=True)
    tours = db.relationship('Tour', backref='agent', lazy=True)

class Client(db.Model):
    __tablename__ = 'clients'
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), nullable=False)
    responsible_name = db.Column(db.String(100))
    phone = db.Column(db.String(20), unique=True, nullable=False)
    address = db.Column(db.String(200))
    gps_lat = db.Column(db.Float)
    gps_lng = db.Column(db.Float)
    email = db.Column(db.String(120), unique=True, nullable=True)
    photo_url = db.Column(db.Text, nullable=True)
    pin_hash = db.Column(db.String(256))
    is_active = db.Column(db.Boolean, default=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    deliveries = db.relationship('Delivery', backref='client', lazy=True)
    orders = db.relationship('Order', backref='client', lazy=True)

class Delivery(db.Model):
    __tablename__ = 'deliveries'
    id = db.Column(db.Integer, primary_key=True)
    date = db.Column(db.DateTime, default=datetime.utcnow)
    agent_id = db.Column(db.Integer, db.ForeignKey('agents.id'), nullable=False)
    client_id = db.Column(db.Integer, db.ForeignKey('clients.id'), nullable=False)
    # Colonnes quantity supprimées (migration Phase 10)
    total_amount = db.Column(db.Float, nullable=False)
    gps_lat_delivery = db.Column(db.Float)
    gps_lng_delivery = db.Column(db.Float)
    photo_url = db.Column(db.Text)
    signature_url = db.Column(db.Text)
    status = db.Column(db.String(20), default='completed')

    # Relation One-to-Many
    items = db.relationship('DeliveryItem', backref='delivery', lazy=True, cascade="all, delete-orphan")

class Order(db.Model):
    __tablename__ = 'orders'
    id = db.Column(db.Integer, primary_key=True)
    client_id = db.Column(db.Integer, db.ForeignKey('clients.id'), nullable=False)
    agent_id = db.Column(db.Integer, db.ForeignKey('agents.id'), nullable=True)
    # Colonnes quantity supprimées
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    preferred_delivery_time = db.Column(db.String(100))
    status = db.Column(db.String(20), default='pending') 
    instructions = db.Column(db.Text)

    # Relation One-to-Many
    items = db.relationship('OrderItem', backref='order', lazy=True, cascade="all, delete-orphan")

class Product(db.Model):
    __tablename__ = 'products'
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), unique=True, nullable=False)
    price = db.Column(db.Float, nullable=False)
    is_active = db.Column(db.Boolean, default=True)

class DeliveryItem(db.Model):
    __tablename__ = 'delivery_items'
    id = db.Column(db.Integer, primary_key=True)
    delivery_id = db.Column(db.Integer, db.ForeignKey('deliveries.id'), nullable=False)
    product_id = db.Column(db.Integer, db.ForeignKey('products.id'), nullable=False)
    quantity = db.Column(db.Integer, nullable=False)
    
    # Relation pour accéder aux infos du produit (nom, prix) via l'item
    product = db.relationship('Product', backref='delivery_items_list')

class OrderItem(db.Model):
    __tablename__ = 'order_items'
    id = db.Column(db.Integer, primary_key=True)
    order_id = db.Column(db.Integer, db.ForeignKey('orders.id'), nullable=False)
    product_id = db.Column(db.Integer, db.ForeignKey('products.id'), nullable=False)
    quantity = db.Column(db.Integer, nullable=False)

    product = db.relationship('Product', backref='order_items_list')

class Evaluation(db.Model):
    __tablename__ = 'evaluations'
    id = db.Column(db.Integer, primary_key=True)
    rating = db.Column(db.Integer, nullable=False)
    comment = db.Column(db.Text, nullable=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    delivery_id = db.Column(db.Integer, db.ForeignKey('deliveries.id'), unique=True, nullable=False)
    client_id = db.Column(db.Integer, db.ForeignKey('clients.id'), nullable=False)

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
    
    # Gestion du stock véhicule
    stock_vitale_loaded = db.Column(db.Integer, default=0)  # Stock Vitale emporté
    stock_voltic_loaded = db.Column(db.Integer, default=0)  # Stock Voltic emporté
    stock_vitale_delivered = db.Column(db.Integer, default=0)  # Livré pendant la tournée
    stock_voltic_delivered = db.Column(db.Integer, default=0)
    status = db.Column(db.String(20), default='pending')  # pending, in_progress, completed

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

# ===== MODÈLES DE STOCK =====

class StockItem(db.Model):
    __tablename__ = 'stock_items'
    id = db.Column(db.Integer, primary_key=True)
    product_id = db.Column(db.Integer, db.ForeignKey('products.id'), nullable=False)
    location = db.Column(db.String(100), default='Entrepôt Principal')
    total_stock = db.Column(db.Integer, default=0)
    available_stock = db.Column(db.Integer, default=0)
    reserved_stock = db.Column(db.Integer, default=0)
    unit_price = db.Column(db.Float, default=0.0)
    unit = db.Column(db.String(20), default='unités')
    low_stock_threshold = db.Column(db.Integer, default=10)
    last_restock_date = db.Column(db.DateTime)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    product = db.relationship('Product', backref='stock_items')
    movements = db.relationship('StockMovement', backref='stock_item', lazy=True)

class StockMovement(db.Model):
    __tablename__ = 'stock_movements'
    id = db.Column(db.Integer, primary_key=True)
    stock_item_id = db.Column(db.Integer, db.ForeignKey('stock_items.id'), nullable=False)
    movement_type = db.Column(db.String(20), nullable=False)  # 'in', 'out', 'transfer'
    quantity = db.Column(db.Integer, nullable=False)
    reference = db.Column(db.String(50))  # Référence de la commande, livraison, etc.
    agent_id = db.Column(db.Integer, db.ForeignKey('agents.id'), nullable=True)
    client_id = db.Column(db.Integer, db.ForeignKey('clients.id'), nullable=True)
    notes = db.Column(db.Text)
    timestamp = db.Column(db.DateTime, default=datetime.utcnow)
    
    agent = db.relationship('Agent', backref='stock_movements')
    client = db.relationship('Client', backref='stock_movements')

class VehicleStock(db.Model):
    __tablename__ = 'vehicle_stocks'
    id = db.Column(db.Integer, primary_key=True)
    agent_id = db.Column(db.Integer, db.ForeignKey('agents.id'), nullable=False)
    product_id = db.Column(db.Integer, db.ForeignKey('products.id'), nullable=False)
    current_stock = db.Column(db.Integer, default=0)
    max_capacity = db.Column(db.Integer, default=50)
    last_updated = db.Column(db.DateTime, default=datetime.utcnow)
    status = db.Column(db.String(20), default='loading')  # 'loading', 'in_transit', 'delivered', 'returned'
    
    agent = db.relationship('Agent', backref='vehicle_stocks')
    product = db.relationship('Product', backref='vehicle_stocks')

# ===== MODÈLES DE PARAMÈTRES =====

class SystemSettings(db.Model):
    __tablename__ = 'system_settings'
    id = db.Column(db.Integer, primary_key=True)
    key = db.Column(db.String(100), unique=True, nullable=False)
    value = db.Column(db.Text)
    description = db.Column(db.Text)
    category = db.Column(db.String(50), default='general')
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

class AgentLocation(db.Model):
    __tablename__ = 'agent_locations'
    id = db.Column(db.Integer, primary_key=True)
    agent_id = db.Column(db.Integer, db.ForeignKey('agents.id'), nullable=False)
    lat = db.Column(db.Float, nullable=False)
    lng = db.Column(db.Float, nullable=False)
    timestamp = db.Column(db.DateTime, default=datetime.utcnow)
    
    agent = db.relationship('Agent', backref='location_history')