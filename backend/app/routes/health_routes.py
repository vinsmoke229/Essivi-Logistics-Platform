from flask import Blueprint, jsonify, request
from datetime import datetime, timedelta
import psutil
import os
import sys
from sqlalchemy import text
from app import db
from pymongo import MongoClient
from app.utils.structured_logger import logger

health_bp = Blueprint('health', __name__, url_prefix='/health')

class HealthCheck:
    """Classe pour les health checks complets"""
    
    @staticmethod
    def check_database():
        """Vérifier la connexion PostgreSQL"""
        try:
            start_time = datetime.utcnow()
            
            
            result = db.session.execute(text('SELECT 1'))
            result.fetchone()
            
            duration = (datetime.utcnow() - start_time).total_seconds()
            
            return {
                'status': 'healthy',
                'response_time_ms': int(duration * 1000),
                'timestamp': datetime.utcnow().isoformat()
            }
        except Exception as e:
            logger.error("Database health check failed", error=str(e))
            return {
                'status': 'unhealthy',
                'error': str(e),
                'timestamp': datetime.utcnow().isoformat()
            }
    
    @staticmethod
    def check_mongodb():
        """Vérifier la connexion MongoDB"""
        try:
            start_time = datetime.utcnow()
            
            
            mongo_uri = os.environ.get('MONGO_URI', 'mongodb://127.0.0.1:27017/essivi_logs')
            client = MongoClient(mongo_uri, serverSelectionTimeoutMS=2000)
            
            
            db_info = client.server_info()
            
            duration = (datetime.utcnow() - start_time).total_seconds()
            client.close()
            
            return {
                'status': 'healthy',
                'response_time_ms': int(duration * 1000),
                'version': db_info.get('version'),
                'timestamp': datetime.utcnow().isoformat()
            }
        except Exception as e:
            logger.error("MongoDB health check failed", error=str(e))
            return {
                'status': 'unhealthy',
                'error': str(e),
                'timestamp': datetime.utcnow().isoformat()
            }
    
    @staticmethod
    def check_system_resources():
        """Vérifier les ressources système"""
        try:
            
            cpu_percent = psutil.cpu_percent(interval=1)
            cpu_count = psutil.cpu_count()
            
            
            memory = psutil.virtual_memory()
            
            
            disk = psutil.disk_usage('/')
            
            
            network = psutil.net_io_counters()
            
            return {
                'status': 'healthy',
                'cpu': {
                    'usage_percent': cpu_percent,
                    'count': cpu_count
                },
                'memory': {
                    'total_gb': round(memory.total / (1024**3), 2),
                    'available_gb': round(memory.available / (1024**3), 2),
                    'usage_percent': memory.percent
                },
                'disk': {
                    'total_gb': round(disk.total / (1024**3), 2),
                    'free_gb': round(disk.free / (1024**3), 2),
                    'usage_percent': round((disk.used / disk.total) * 100, 2)
                },
                'network': {
                    'bytes_sent': network.bytes_sent,
                    'bytes_recv': network.bytes_recv
                },
                'timestamp': datetime.utcnow().isoformat()
            }
        except Exception as e:
            logger.error("System resources health check failed", error=str(e))
            return {
                'status': 'unhealthy',
                'error': str(e),
                'timestamp': datetime.utcnow().isoformat()
            }
    
    @staticmethod
    def check_application():
        """Vérifier l'état de l'application"""
        try:
            
            python_version = sys.version
            
            
            env_vars = {
                'FLASK_ENV': os.environ.get('FLASK_ENV'),
                'DATABASE_URL': 'SET' if os.environ.get('DATABASE_URL') else 'MISSING',
                'JWT_SECRET_KEY': 'SET' if os.environ.get('JWT_SECRET_KEY') else 'MISSING',
                'MONGO_URI': 'SET' if os.environ.get('MONGO_URI') else 'MISSING'
            }
            
            
            uptime = datetime.utcnow() - datetime.fromtimestamp(psutil.boot_time())
            
            return {
                'status': 'healthy',
                'python_version': python_version,
                'environment': env_vars,
                'uptime_hours': round(uptime.total_seconds() / 3600, 2),
                'timestamp': datetime.utcnow().isoformat()
            }
        except Exception as e:
            logger.error("Application health check failed", error=str(e))
            return {
                'status': 'unhealthy',
                'error': str(e),
                'timestamp': datetime.utcnow().isoformat()
            }
    
    @staticmethod
    def check_dependencies():
        """Vérifier les dépendances critiques"""
        try:
            dependencies = {}
            
            
            try:
                import flask
                dependencies['flask'] = flask.__version__
            except ImportError:
                dependencies['flask'] = 'MISSING'
            
            try:
                import sqlalchemy
                dependencies['sqlalchemy'] = sqlalchemy.__version__
            except ImportError:
                dependencies['sqlalchemy'] = 'MISSING'
            
            try:
                import pymongo
                dependencies['pymongo'] = pymongo.version
            except ImportError:
                dependencies['pymongo'] = 'MISSING'
            
            try:
                import jwt
                dependencies['jwt'] = jwt.__version__
            except ImportError:
                dependencies['jwt'] = 'MISSING'
            
            
            missing_deps = [k for k, v in dependencies.items() if v == 'MISSING']
            
            return {
                'status': 'healthy' if not missing_deps else 'degraded',
                'dependencies': dependencies,
                'missing': missing_deps,
                'timestamp': datetime.utcnow().isoformat()
            }
        except Exception as e:
            logger.error("Dependencies health check failed", error=str(e))
            return {
                'status': 'unhealthy',
                'error': str(e),
                'timestamp': datetime.utcnow().isoformat()
            }

@health_bp.route('/')
def health_check():
    """Health check principal"""
    try:
        
        checks = {
            'database': HealthCheck.check_database(),
            'mongodb': HealthCheck.check_mongodb(),
            'system': HealthCheck.check_system_resources(),
            'application': HealthCheck.check_application(),
            'dependencies': HealthCheck.check_dependencies()
        }
        
        
        statuses = [check.get('status') for check in checks.values()]
        
        if 'unhealthy' in statuses:
            overall_status = 'unhealthy'
        elif 'degraded' in statuses:
            overall_status = 'degraded'
        else:
            overall_status = 'healthy'
        
        
        response_time = (datetime.utcnow() - datetime.utcnow()).total_seconds()
        
        response = {
            'status': overall_status,
            'timestamp': datetime.utcnow().isoformat(),
            'version': '1.0.0',
            'response_time_ms': int(response_time * 1000),
            'checks': checks
        }
        
        
        status_code = 200 if overall_status == 'healthy' else 503
        
        logger.info(
            f"Health check: {overall_status}",
            health_status=overall_status,
            checks_count=len(checks)
        )
        
        return jsonify(response), status_code
        
    except Exception as e:
        logger.error("Health check failed", error=str(e))
        return jsonify({
            'status': 'unhealthy',
            'error': str(e),
            'timestamp': datetime.utcnow().isoformat()
        }), 503

@health_bp.route('/ready')
def readiness_check():
    """Readiness probe pour Kubernetes"""
    try:
        
        db_check = HealthCheck.check_database()
        
        if db_check['status'] == 'healthy':
            return jsonify({
                'status': 'ready',
                'timestamp': datetime.utcnow().isoformat()
            }), 200
        else:
            return jsonify({
                'status': 'not_ready',
                'database': db_check,
                'timestamp': datetime.utcnow().isoformat()
            }), 503
            
    except Exception as e:
        return jsonify({
            'status': 'not_ready',
            'error': str(e),
            'timestamp': datetime.utcnow().isoformat()
        }), 503

@health_bp.route('/live')
def liveness_check():
    """Liveness probe pour Kubernetes"""
    try:
        
        return jsonify({
            'status': 'alive',
            'timestamp': datetime.utcnow().isoformat()
        }), 200
    except Exception as e:
        return jsonify({
            'status': 'dead',
            'error': str(e),
            'timestamp': datetime.utcnow().isoformat()
        }), 503

@health_bp.route('/metrics')
def metrics_check():
    """Métriques détaillées pour monitoring"""
    try:
        
        system_metrics = HealthCheck.check_system_resources()
        
        
        app_metrics = {
            'uptime_hours': system_metrics.get('system', {}).get('uptime', 0),
            'memory_usage_mb': system_metrics.get('system', {}).get('memory', {}).get('used', 0) / (1024*1024),
            'cpu_usage_percent': system_metrics.get('system', {}).get('cpu', {}).get('usage_percent', 0)
        }
        
        return jsonify({
            'timestamp': datetime.utcnow().isoformat(),
            'system': system_metrics,
            'application': app_metrics
        }), 200
        
    except Exception as e:
        logger.error("Metrics check failed", error=str(e))
        return jsonify({
            'error': str(e),
            'timestamp': datetime.utcnow().isoformat()
        }), 503
