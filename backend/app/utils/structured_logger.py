import logging
import json
import sys
from datetime import datetime
from typing import Dict, Any, Optional
from functools import wraps
from flask import request, g
import traceback

class StructuredLogger:
    """Logger structuré avec niveaux et métadonnées"""
    
    def __init__(self, name: str = 'essivi'):
        self.logger = logging.getLogger(name)
        self.logger.setLevel(logging.DEBUG)
        
        
        formatter = StructuredFormatter()
        
        
        console_handler = logging.StreamHandler(sys.stdout)
        console_handler.setFormatter(formatter)
        self.logger.addHandler(console_handler)
        
        
        try:
            file_handler = logging.FileHandler('logs/app.log')
            file_handler.setFormatter(formatter)
            self.logger.addHandler(file_handler)
        except:
            pass  
    
    def _log(self, level: int, message: str, **kwargs):
        """Méthode interne pour logging structuré"""
        log_data = {
            'timestamp': datetime.utcnow().isoformat(),
            'level': logging.getLevelName(level),
            'message': message,
            'module': kwargs.get('module', 'app'),
            'function': kwargs.get('function'),
            'line': kwargs.get('line'),
            'user_id': kwargs.get('user_id'),
            'request_id': getattr(g, 'request_id', None),
            'ip_address': getattr(request, 'remote_addr', None) if request else None,
            'user_agent': getattr(request, 'user_agent', {}).get('string', None) if request else None,
            'method': getattr(request, 'method', None) if request else None,
            'url': getattr(request, 'url', None) if request else None,
            'extra': kwargs
        }
        
        
        log_data = {k: v for k, v in log_data.items() if v is not None}
        
        self.logger.log(level, json.dumps(log_data, default=str))
    
    def debug(self, message: str, **kwargs):
        self._log(logging.DEBUG, message, **kwargs)
    
    def info(self, message: str, **kwargs):
        self._log(logging.INFO, message, **kwargs)
    
    def warning(self, message: str, **kwargs):
        self._log(logging.WARNING, message, **kwargs)
    
    def error(self, message: str, **kwargs):
        self._log(logging.ERROR, message, **kwargs)
    
    def critical(self, message: str, **kwargs):
        self._log(logging.CRITICAL, message, **kwargs)
    
    def security(self, message: str, **kwargs):
        """Log spécial pour événements de sécurité"""
        self._log(logging.WARNING, message, security_event=True, **kwargs)
    
    def performance(self, message: str, duration: float = None, **kwargs):
        """Log spécial pour métriques de performance"""
        self._log(logging.INFO, message, performance_metric=True, duration=duration, **kwargs)
    
    def audit(self, message: str, **kwargs):
        """Log spécial pour audit trail"""
        self._log(logging.INFO, message, audit_event=True, **kwargs)

class StructuredFormatter(logging.Formatter):
    """Formatter pour logs structurés en JSON"""
    
    def format(self, record):
        try:
            log_data = json.loads(record.getMessage())
            return json.dumps(log_data, ensure_ascii=False, indent=2)
        except:
            
            return json.dumps({
                'timestamp': datetime.utcnow().isoformat(),
                'level': record.levelname,
                'message': record.getMessage(),
                'module': record.module,
                'function': record.funcName,
                'line': record.lineno
            }, ensure_ascii=False)


logger = StructuredLogger()

def log_function_call(func):
    """Décorateur pour logger les appels de fonction"""
    @wraps(func)
    def wrapper(*args, **kwargs):
        start_time = datetime.utcnow()
        
        logger.debug(
            f"Appel fonction: {func.__name__}",
            function=func.__name__,
            module=func.__module__,
            args_count=len(args),
            kwargs_count=len(kwargs)
        )
        
        try:
            result = func(*args, **kwargs)
            duration = (datetime.utcnow() - start_time).total_seconds()
            
            logger.performance(
                f"Fonction exécutée: {func.__name__}",
                duration=duration,
                function=func.__name__,
                module=func.__module__
            )
            
            return result
        except Exception as e:
            duration = (datetime.utcnow() - start_time).total_seconds()
            
            logger.error(
                f"Erreur fonction: {func.__name__}",
                error=str(e),
                traceback=traceback.format_exc(),
                duration=duration,
                function=func.__name__,
                module=func.__module__
            )
            
            raise
    return wrapper

def log_api_request(func):
    """Décorateur pour logger les requêtes API"""
    @wraps(func)
    def wrapper(*args, **kwargs):
        start_time = datetime.utcnow()
        
        logger.info(
            f"API Request: {request.method} {request.url}",
            method=request.method,
            url=request.url,
            endpoint=request.endpoint,
            ip_address=request.remote_addr,
            user_agent=request.user_agent.string if request.user_agent else None
        )
        
        try:
            result = func(*args, **kwargs)
            duration = (datetime.utcnow() - start_time).total_seconds()
            
            logger.info(
                f"API Response: {request.method} {request.url}",
                method=request.method,
                url=request.url,
                status=200,
                duration=duration,
                response_type=type(result).__name__
            )
            
            return result
        except Exception as e:
            duration = (datetime.utcnow() - start_time).total_seconds()
            
            logger.error(
                f"API Error: {request.method} {request.url}",
                method=request.method,
                url=request.url,
                error=str(e),
                status=500,
                duration=duration,
                traceback=traceback.format_exc()
            )
            
            raise
    return wrapper

def log_security_event(event_type: str, details: Dict[str, Any] = None):
    """Logger pour événements de sécurité"""
    logger.security(
        f"Security Event: {event_type}",
        event_type=event_type,
        details=details or {}
    )

def log_database_query(query: str, duration: float, params: Any = None):
    """Logger pour requêtes base de données"""
    logger.performance(
        "Database Query",
        duration=duration,
        query_type=query.split()[0] if query else 'unknown',
        query_length=len(query),
        params_count=len(params) if params else 0
    )

def log_cache_operation(operation: str, key: str, hit: bool = None):
    """Logger pour opérations cache"""
    logger.info(
        f"Cache {operation}: {key}",
        cache_operation=operation,
        cache_key=key,
        cache_hit=hit
    )

def log_external_service(service: str, operation: str, duration: float, status: str):
    """Logger pour appels services externes"""
    logger.performance(
        f"External Service: {service} {operation}",
        duration=duration,
        external_service=service,
        operation=operation,
        status=status
    )

def log_business_event(event_type: str, entity_type: str, entity_id: Any, details: Dict[str, Any] = None):
    """Logger pour événements métier"""
    logger.audit(
        f"Business Event: {event_type}",
        business_event=event_type,
        entity_type=entity_type,
        entity_id=entity_id,
        details=details or {}
    )

def log_structured_action(action: str, details: Dict[str, Any] = None):
    """Logger pour les actions utilisateur (Structure simple)"""
    logger.info(
        f"User Action: {action}",
        user_action=action,
        details=details or {}
    )


__all__ = [
    'logger',
    'StructuredLogger',
    'log_function_call',
    'log_api_request',
    'log_security_event',
    'log_database_query',
    'log_cache_operation',
    'log_external_service',
    'log_business_event',
    'log_structured_action'
]
