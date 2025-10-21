from django.urls import path, include
from rest_framework.routers import DefaultRouter
from rest_framework_simplejwt.views import TokenObtainPairView, TokenRefreshView

from .views import (
    UsuarioViewSet,
    LineaViewSet,
    TurnoViewSet,
    ColaboradorViewSet,
    ProductoViewSet,
    TareaViewSet
)

# Router para los ViewSets
router = DefaultRouter()
router.register(r'usuarios', UsuarioViewSet, basename='usuario')
router.register(r'lineas', LineaViewSet, basename='linea')
router.register(r'turnos', TurnoViewSet, basename='turno')
router.register(r'colaboradores', ColaboradorViewSet, basename='colaborador')
router.register(r'productos', ProductoViewSet, basename='producto')
router.register(r'tareas', TareaViewSet, basename='tarea')

urlpatterns = [
    # Autenticación JWT
    path('auth/login/', TokenObtainPairView.as_view(), name='token_obtain_pair'),
    path('auth/refresh/', TokenRefreshView.as_view(), name='token_refresh'),
    
    # Endpoints de la API
    path('', include(router.urls)),
]