from rest_framework import permissions


class IsSupervisor(permissions.BasePermission):
    """
    Permiso que solo permite acceso a usuarios con rol 'supervisor'.
    """
    
    def has_permission(self, request, view):
        return (
            request.user and
            request.user.is_authenticated and
            hasattr(request.user, 'rol') and
            request.user.rol == 'supervisor'
        )


class IsControlCalidad(permissions.BasePermission):
    """
    Permiso que solo permite acceso a usuarios con rol 'control_calidad'.
    """
    
    def has_permission(self, request, view):
        return (
            request.user and
            request.user.is_authenticated and
            hasattr(request.user, 'rol') and
            request.user.rol == 'control_calidad'
        )


class IsSupervisorOrReadOnly(permissions.BasePermission):
    """
    Permiso que permite lectura a todos los usuarios autenticados,
    pero solo permite escritura (POST, PUT, PATCH, DELETE) a supervisores.
    """
    
    def has_permission(self, request, view):
        # Permitir lectura a cualquier usuario autenticado
        if request.method in permissions.SAFE_METHODS:
            return request.user and request.user.is_authenticated
        
        # Permitir escritura solo a supervisores
        return (
            request.user and
            request.user.is_authenticated and
            hasattr(request.user, 'rol') and
            request.user.rol == 'supervisor'
        )