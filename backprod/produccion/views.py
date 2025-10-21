from django.shortcuts import render

# Create your views here.

from rest_framework import viewsets, status, filters
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from django.db.models import Q
from datetime import date
import openpyxl

from .models import (
    Usuario, Linea, Turno, Colaborador,
    Producto, MateriaPrima, Receta,
    Tarea, TareaColaborador
)
from .serializers import (
    UsuarioSerializer, LineaSerializer, TurnoSerializer,
    ColaboradorSerializer, ColaboradorCreateSerializer,
    ProductoSerializer, ProductoConRecetaSerializer,
    MateriaPrimaSerializer, RecetaSerializer,
    TareaListSerializer, TareaDetailSerializer, TareaCreateUpdateSerializer
)
from .permissions import IsSupervisor, IsSupervisorOrReadOnly


# ============================================================================
# VIEWSET: Usuario Actual
# ============================================================================
class UsuarioViewSet(viewsets.ReadOnlyModelViewSet):
    """
    ViewSet para obtener información del usuario autenticado.
    Solo lectura.
    """
    serializer_class = UsuarioSerializer
    permission_classes = [IsAuthenticated]
    
    def get_queryset(self):
        """Solo retorna el usuario autenticado"""
        return Usuario.objects.filter(id=self.request.user.id)
    
    @action(detail=False, methods=['get'])
    def me(self, request):
        """
        Endpoint: GET /api/usuarios/me/
        Retorna la información del usuario autenticado.
        """
        serializer = self.get_serializer(request.user)
        return Response(serializer.data)


# ============================================================================
# VIEWSET: Líneas
# ============================================================================
class LineaViewSet(viewsets.ReadOnlyModelViewSet):
    """
    ViewSet para Líneas de Producción.
    Solo lectura (las líneas se gestionan desde el admin).
    """
    serializer_class = LineaSerializer
    permission_classes = [IsAuthenticated]
    queryset = Linea.objects.filter(activa=True).order_by('nombre')
    filter_backends = [filters.SearchFilter]
    search_fields = ['nombre']


# ============================================================================
# VIEWSET: Turnos
# ============================================================================
class TurnoViewSet(viewsets.ReadOnlyModelViewSet):
    """
    ViewSet para Turnos.
    Solo lectura (los turnos se gestionan desde el admin).
    """
    serializer_class = TurnoSerializer
    permission_classes = [IsAuthenticated]
    queryset = Turno.objects.filter(activo=True).order_by('hora_inicio')


# ============================================================================
# VIEWSET: Colaboradores
# ============================================================================
class ColaboradorViewSet(viewsets.ModelViewSet):
    """
    ViewSet para Colaboradores.
    Permite listar, crear, actualizar y eliminar colaboradores.
    """
    serializer_class = ColaboradorSerializer
    permission_classes = [IsAuthenticated, IsSupervisorOrReadOnly]
    queryset = Colaborador.objects.filter(activo=True).order_by('codigo')
    filter_backends = [filters.SearchFilter, filters.OrderingFilter]
    search_fields = ['codigo', 'nombre', 'apellido']
    ordering_fields = ['codigo', 'nombre', 'apellido']
    
    @action(detail=False, methods=['post'], permission_classes=[IsAuthenticated, IsSupervisor])
    def cargar_excel(self, request):
        """
        Endpoint: POST /api/colaboradores/cargar_excel/
        Carga colaboradores desde un archivo Excel.
        
        Expected format:
        {
            "colaboradores": [
                {"codigo": "001", "nombre": "Juan", "apellido": "Pérez"},
                {"codigo": "002", "nombre": "María", "apellido": "González"}
            ]
        }
        """
        serializer = ColaboradorCreateSerializer(data=request.data)
        
        if serializer.is_valid():
            resultado = serializer.save()
            
            return Response({
                'success': True,
                'message': 'Colaboradores cargados exitosamente',
                'creados': len(resultado['creados']),
                'actualizados': len(resultado['actualizados']),
                'total': len(resultado['creados']) + len(resultado['actualizados'])
            }, status=status.HTTP_201_CREATED)
        
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
    
    @action(detail=False, methods=['post'], permission_classes=[IsAuthenticated, IsSupervisor])
    def cargar_excel_archivo(self, request):
        """
        Endpoint: POST /api/colaboradores/cargar_excel_archivo/
        Carga colaboradores desde un archivo Excel subido directamente.
        
        Expected: Multipart form data con el campo 'archivo'
        """
        if 'archivo' not in request.FILES:
            return Response(
                {'error': 'No se ha enviado ningún archivo'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        archivo = request.FILES['archivo']
        
        # Validar extensión
        if not archivo.name.endswith(('.xlsx', '.xls')):
            return Response(
                {'error': 'El archivo debe ser un Excel (.xlsx o .xls)'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        try:
            # Leer el archivo Excel
            workbook = openpyxl.load_workbook(archivo)
            sheet = workbook.active
            
            colaboradores_data = []
            
            # Leer desde la fila 2 (asumiendo que la fila 1 tiene headers)
            for row in sheet.iter_rows(min_row=2, values_only=True):
                if row[0]:  # Si hay código
                    colaboradores_data.append({
                        'codigo': str(row[0]).strip(),
                        'nombre': str(row[1]).strip() if row[1] else '',
                        'apellido': str(row[2]).strip() if row[2] else ''
                    })
            
            if not colaboradores_data:
                return Response(
                    {'error': 'El archivo no contiene datos válidos'},
                    status=status.HTTP_400_BAD_REQUEST
                )
            
            # Usar el serializer para crear/actualizar
            serializer = ColaboradorCreateSerializer(
                data={'colaboradores': colaboradores_data}
            )
            
            if serializer.is_valid():
                resultado = serializer.save()
                
                return Response({
                    'success': True,
                    'message': 'Colaboradores cargados exitosamente desde Excel',
                    'creados': len(resultado['creados']),
                    'actualizados': len(resultado['actualizados']),
                    'total': len(resultado['creados']) + len(resultado['actualizados'])
                }, status=status.HTTP_201_CREATED)
            
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
        
        except Exception as e:
            return Response(
                {'error': f'Error al procesar el archivo: {str(e)}'},
                status=status.HTTP_400_BAD_REQUEST
            )


# ============================================================================
# VIEWSET: Productos
# ============================================================================
class ProductoViewSet(viewsets.ReadOnlyModelViewSet):
    """
    ViewSet para Productos.
    Solo lectura (los productos se gestionan desde el admin).
    """
    permission_classes = [IsAuthenticated]
    queryset = Producto.objects.filter(activo=True).order_by('codigo')
    filter_backends = [filters.SearchFilter, filters.OrderingFilter]
    search_fields = ['codigo', 'nombre']
    ordering_fields = ['codigo', 'nombre']
    
    def get_serializer_class(self):
        """Retorna serializer con receta para detalle"""
        if self.action == 'retrieve':
            return ProductoConRecetaSerializer
        return ProductoSerializer


# ============================================================================
# VIEWSET: Tareas
# ============================================================================
class TareaViewSet(viewsets.ModelViewSet):
    """
    ViewSet para Tareas.
    CRUD completo para supervisores.
    """
    permission_classes = [IsAuthenticated, IsSupervisorOrReadOnly]
    filter_backends = [filters.SearchFilter, filters.OrderingFilter]
    search_fields = ['producto__codigo', 'producto__nombre', 'observaciones']
    ordering_fields = ['fecha', 'estado']
    
    def get_queryset(self):
        """
        Filtra tareas según parámetros de query.
        """
        queryset = Tarea.objects.select_related(
            'linea', 'turno', 'producto', 'supervisor_asignador'
        ).prefetch_related('tarea_colaboradores__colaborador')
        
        # Filtros opcionales
        fecha = self.request.query_params.get('fecha', None)
        linea_id = self.request.query_params.get('linea', None)
        turno_id = self.request.query_params.get('turno', None)
        estado = self.request.query_params.get('estado', None)
        
        if fecha:
            queryset = queryset.filter(fecha=fecha)
        
        if linea_id:
            queryset = queryset.filter(linea_id=linea_id)
        
        if turno_id:
            queryset = queryset.filter(turno_id=turno_id)
        
        if estado:
            queryset = queryset.filter(estado=estado)
        
        return queryset.order_by('-fecha', 'turno', 'linea')
    
    def get_serializer_class(self):
        """Retorna el serializer apropiado según la acción"""
        if self.action == 'list':
            return TareaListSerializer
        elif self.action in ['create', 'update', 'partial_update']:
            return TareaCreateUpdateSerializer
        return TareaDetailSerializer
    
    def perform_create(self, serializer):
        """
        Al crear una tarea, asigna automáticamente el supervisor actual
        si no se especificó uno.
        """
        if 'supervisor_asignador' not in serializer.validated_data:
            serializer.save(supervisor_asignador=self.request.user)
        else:
            serializer.save()
    
    @action(detail=False, methods=['get'])
    def hoy(self, request):
        """
        Endpoint: GET /api/tareas/hoy/
        Retorna las tareas del día actual.
        """
        tareas = self.get_queryset().filter(fecha=date.today())
        serializer = TareaListSerializer(tareas, many=True)
        return Response(serializer.data)
    
    @action(detail=False, methods=['get'])
    def por_linea_turno(self, request):
        """
        Endpoint: GET /api/tareas/por_linea_turno/?linea=1&turno=1&fecha=2025-10-05
        Retorna las tareas de una línea y turno específicos.
        """
        linea_id = request.query_params.get('linea')
        turno_id = request.query_params.get('turno')
        fecha_param = request.query_params.get('fecha', date.today())
        
        if not linea_id or not turno_id:
            return Response(
                {'error': 'Se requieren los parámetros "linea" y "turno"'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        tareas = self.get_queryset().filter(
            linea_id=linea_id,
            turno_id=turno_id,
            fecha=fecha_param
        )
        
        serializer = TareaListSerializer(tareas, many=True)
        return Response(serializer.data)
    
    @action(detail=True, methods=['post'], permission_classes=[IsAuthenticated])
    def iniciar(self, request, pk=None):
        """
        Endpoint: POST /api/tareas/{id}/iniciar/
        Inicia una tarea (cambia estado a 'en_curso').
        """
        tarea = self.get_object()
        
        try:
            tarea.iniciar()
            serializer = TareaDetailSerializer(tarea)
            return Response({
                'success': True,
                'message': 'Tarea iniciada correctamente',
                'tarea': serializer.data
            })
        except Exception as e:
            return Response(
                {'error': str(e)},
                status=status.HTTP_400_BAD_REQUEST
            )
    
    @action(detail=True, methods=['post'], permission_classes=[IsAuthenticated])
    def finalizar(self, request, pk=None):
        """
        Endpoint: POST /api/tareas/{id}/finalizar/
        Finaliza una tarea (cambia estado a 'finalizada').
        """
        tarea = self.get_object()
        
        try:
            tarea.finalizar()
            serializer = TareaDetailSerializer(tarea)
            return Response({
                'success': True,
                'message': 'Tarea finalizada correctamente',
                'tarea': serializer.data
            })
        except Exception as e:
            return Response(
                {'error': str(e)},
                status=status.HTTP_400_BAD_REQUEST
            )
    
    @action(detail=True, methods=['get'])
    def verificar_bloqueo(self, request, pk=None):
        """
        Endpoint: GET /api/tareas/{id}/verificar_bloqueo/
        Verifica si una tarea puede ser iniciada o está bloqueada.
        """
        tarea = self.get_object()
        
        # Verificar si hay otra tarea en curso en la misma línea
        tarea_en_curso = Tarea.objects.filter(
            linea=tarea.linea,
            estado='en_curso'
        ).exclude(pk=tarea.pk).first()
        
        if tarea_en_curso:
            return Response({
                'bloqueada': True,
                'motivo': 'Ya hay una tarea en curso en esta línea',
                'tarea_en_curso': {
                    'id': tarea_en_curso.id,
                    'producto': tarea_en_curso.producto.nombre,
                    'fecha_inicio': tarea_en_curso.fecha_inicio
                }
            })
        
        if tarea.estado != 'pendiente':
            return Response({
                'bloqueada': True,
                'motivo': f'La tarea ya está {tarea.get_estado_display().lower()}',
                'estado_actual': tarea.estado
            })
        
        return Response({
            'bloqueada': False,
            'mensaje': 'La tarea puede ser iniciada'
        })
    
    def destroy(self, request, *args, **kwargs):
        """
        DELETE /api/tareas/{id}/
        Solo supervisores pueden eliminar tareas.
        """
        tarea = self.get_object()
        
        # Solo permitir eliminar tareas pendientes
        if tarea.estado != 'pendiente':
            return Response(
                {'error': 'Solo se pueden eliminar tareas pendientes'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        return super().destroy(request, *args, **kwargs)