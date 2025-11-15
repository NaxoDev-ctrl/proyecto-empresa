from django.shortcuts import render

# Create your views here.

from rest_framework import viewsets, status, filters
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from django.db.models import Q
from django.core.exceptions import ValidationError
from datetime import date
import openpyxl

from .models import (
    Usuario, Linea, Turno, Colaborador,
    Producto, MateriaPrima, Receta,
    Tarea, TareaColaborador,
    Maquina, TipoEvento,
    HojaProcesos, EventoProceso, EventoMaquina,
    Trazabilidad, TrazabilidadMateriaPrima,
    Reproceso, Merma, FotoEtiqueta, FirmaTrazabilidad
)
from .serializers import (
    UsuarioSerializer, LineaSerializer, TurnoSerializer,
    ColaboradorSerializer, ColaboradorCreateSerializer,
    ProductoSerializer, ProductoConRecetaSerializer,
    MateriaPrimaSerializer, RecetaSerializer,
    TareaListSerializer, TareaDetailSerializer, TareaCreateUpdateSerializer,
    MaquinaSerializer, TipoEventoSerializer,
    HojaProcesosListSerializer, HojaProcesosDetailSerializer,
    EventoProcesoListSerializer, EventoProcesoCreateUpdateSerializer,
    TrazabilidadListSerializer, TrazabilidadDetailSerializer, TrazabilidadCreateUpdateSerializer,
    FirmaTrazabilidadSerializer

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
    
# ============================================================================
# VIEWSET: Máquinas
# ============================================================================
class MaquinaViewSet(viewsets.ReadOnlyModelViewSet):
    """
    ViewSet para Máquinas.
    Solo lectura (las máquinas se gestionan desde el admin).
    """
    serializer_class = MaquinaSerializer
    permission_classes = [IsAuthenticated]
    queryset = Maquina.objects.filter(activa=True).order_by('nombre')
    filter_backends = [filters.SearchFilter, filters.OrderingFilter]
    search_fields = ['codigo', 'nombre']
    ordering_fields = ['codigo', 'nombre']


# ============================================================================
# VIEWSET: Tipos de Eventos
# ============================================================================
class TipoEventoViewSet(viewsets.ReadOnlyModelViewSet):
    """
    ViewSet para Tipos de Eventos.
    Solo lectura (los tipos de eventos se gestionan desde el admin).
    """
    serializer_class = TipoEventoSerializer
    permission_classes = [IsAuthenticated]
    queryset = TipoEvento.objects.filter(activo=True).order_by('orden')
    filter_backends = [filters.SearchFilter]
    search_fields = ['nombre', 'codigo']


# ============================================================================
# VIEWSET: Hoja de Procesos
# ============================================================================
class HojaProcesosViewSet(viewsets.ModelViewSet):
    """
    ViewSet para Hojas de Procesos.
    Permite crear, listar y ver detalles de hojas de procesos.
    """
    permission_classes = [IsAuthenticated]
    filter_backends = [filters.SearchFilter, filters.OrderingFilter]
    search_fields = ['tarea__producto__nombre', 'tarea__linea__nombre']
    ordering_fields = ['fecha_inicio', 'finalizada']
    
    def get_queryset(self):
        """
        Filtra hojas de procesos según parámetros de query.
        """
        queryset = HojaProcesos.objects.select_related(
            'tarea__linea',
            'tarea__turno',
            'tarea__producto'
        ).prefetch_related('eventos__tipo_evento')
        
        # Filtros opcionales
        finalizada = self.request.query_params.get('finalizada', None)
        fecha = self.request.query_params.get('fecha', None)
        linea_id = self.request.query_params.get('linea', None)
        
        if finalizada is not None:
            finalizada_bool = finalizada.lower() == 'true'
            queryset = queryset.filter(finalizada=finalizada_bool)
        
        if fecha:
            queryset = queryset.filter(tarea__fecha=fecha)
        
        if linea_id:
            queryset = queryset.filter(tarea__linea_id=linea_id)
        
        return queryset.order_by('-fecha_inicio')
    
    def get_serializer_class(self):
        """Retorna el serializer apropiado según la acción"""
        if self.action == 'list':
            return HojaProcesosListSerializer
        return HojaProcesosDetailSerializer
    
    @action(detail=True, methods=['post'], permission_classes=[IsAuthenticated])
    def finalizar(self, request, pk=None):
        """
        Endpoint: POST /api/hojas-procesos/{id}/finalizar/
        Finaliza una hoja de procesos.
        """
        hoja = self.get_object()
        
        try:
            hoja.finalizar()
            serializer = HojaProcesosDetailSerializer(hoja)
            return Response({
                'success': True,
                'message': 'Hoja de procesos finalizada correctamente',
                'hoja_procesos': serializer.data
            })
        except Exception as e:
            return Response(
                {'error': str(e)},
                status=status.HTTP_400_BAD_REQUEST
            )
    
    @action(detail=False, methods=['get'])
    def por_tarea(self, request):
        """
        Endpoint: GET /api/hojas-procesos/por_tarea/?tarea_id=1
        Obtiene la hoja de procesos de una tarea específica.
        """
        tarea_id = request.query_params.get('tarea_id')
        
        if not tarea_id:
            return Response(
                {'error': 'Se requiere el parámetro "tarea_id"'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        try:
            hoja = HojaProcesos.objects.select_related(
                'tarea__linea',
                'tarea__turno',
                'tarea__producto'
            ).prefetch_related('eventos__tipo_evento').get(tarea_id=tarea_id)
            
            serializer = HojaProcesosDetailSerializer(hoja)
            return Response(serializer.data)
        except HojaProcesos.DoesNotExist:
            return Response(
                {'error': 'No existe hoja de procesos para esta tarea'},
                status=status.HTTP_404_NOT_FOUND
            )


# ============================================================================
# VIEWSET: Eventos de Proceso
# ============================================================================
class EventoProcesoViewSet(viewsets.ModelViewSet):
    """
    ViewSet para Eventos de Proceso.
    Permite CRUD completo de eventos dentro de una hoja de procesos.
    """
    permission_classes = [IsAuthenticated]
    filter_backends = [filters.OrderingFilter]
    ordering_fields = ['hora_inicio']
    
    def get_queryset(self):
        """
        Filtra eventos según parámetros de query.
        """
        queryset = EventoProceso.objects.select_related(
            'hoja_procesos__tarea',
            'tipo_evento'
        ).prefetch_related('evento_maquinas__maquina')
        
        # Filtro por hoja de procesos
        hoja_id = self.request.query_params.get('hoja_procesos', None)
        if hoja_id:
            queryset = queryset.filter(hoja_procesos_id=hoja_id)
        
        return queryset.order_by('hora_inicio')
    
    def get_serializer_class(self):
        """Retorna el serializer apropiado según la acción"""
        if self.action in ['create', 'update', 'partial_update']:
            return EventoProcesoCreateUpdateSerializer
        return EventoProcesoListSerializer
    
    @action(detail=True, methods=['post'], permission_classes=[IsAuthenticated])
    def finalizar_evento(self, request, pk=None):
        """
        Endpoint: POST /api/eventos-proceso/{id}/finalizar_evento/
        Marca la hora de fin de un evento.
        """
        from django.utils import timezone
        
        evento = self.get_object()
        
        if evento.hora_fin:
            return Response(
                {'error': 'Este evento ya tiene hora de fin'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        evento.hora_fin = timezone.now()
        evento.save()
        
        serializer = EventoProcesoListSerializer(evento)
        return Response({
            'success': True,
            'message': 'Evento finalizado correctamente',
            'evento': serializer.data
        })


# ============================================================================
# VIEWSET: Trazabilidad
# ============================================================================
class TrazabilidadViewSet(viewsets.ModelViewSet):
    """
    ViewSet para Trazabilidades.
    Permite CRUD completo y gestión de firmas/estados.
    """
    permission_classes = [IsAuthenticated]
    filter_backends = [filters.SearchFilter, filters.OrderingFilter]
    search_fields = [
        'hoja_procesos__tarea__producto__nombre',
        'hoja_procesos__tarea__linea__nombre'
    ]
    ordering_fields = ['fecha_creacion', 'estado']
    
    def get_queryset(self):
        """
        Filtra trazabilidades según parámetros de query.
        """
        queryset = Trazabilidad.objects.select_related(
            'hoja_procesos__tarea__linea',
            'hoja_procesos__tarea__turno',
            'hoja_procesos__tarea__producto'
        ).prefetch_related(
            'materias_primas_usadas__materia_prima',
            'reprocesos',
            'mermas',
            'firmas__usuario',
            'foto_etiqueta'
        )
        
        # Filtros opcionales
        estado = self.request.query_params.get('estado', None)
        fecha = self.request.query_params.get('fecha', None)
        turno_id = self.request.query_params.get('turno', None)
        
        if estado:
            queryset = queryset.filter(estado=estado)
        
        if fecha:
            queryset = queryset.filter(hoja_procesos__tarea__fecha=fecha)
        
        if turno_id:
            queryset = queryset.filter(hoja_procesos__tarea__turno_id=turno_id)
        
        return queryset.order_by('-fecha_creacion')
    
    def get_serializer_class(self):
        """Retorna el serializer apropiado según la acción"""
        if self.action == 'list':
            return TrazabilidadListSerializer
        elif self.action in ['create', 'update', 'partial_update']:
            return TrazabilidadCreateUpdateSerializer
        return TrazabilidadDetailSerializer
    
    @action(detail=False, methods=['get'])
    def por_fecha_turno(self, request):
        """
        Endpoint: GET /api/trazabilidades/por_fecha_turno/?fecha=2025-10-05&turno=1
        Retorna las trazabilidades de una fecha y turno específicos.
        """
        fecha = request.query_params.get('fecha')
        turno_id = request.query_params.get('turno')
        
        if not fecha or not turno_id:
            return Response(
                {'error': 'Se requieren los parámetros "fecha" y "turno"'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        trazabilidades = self.get_queryset().filter(
            hoja_procesos__tarea__fecha=fecha,
            hoja_procesos__tarea__turno_id=turno_id
        )
        
        serializer = TrazabilidadListSerializer(trazabilidades, many=True)
        return Response(serializer.data)
    
    @action(detail=True, methods=['post'], permission_classes=[IsAuthenticated])
    def cambiar_estado(self, request, pk=None):
        """
        Endpoint: POST /api/trazabilidades/{id}/cambiar_estado/
        Cambia el estado de una trazabilidad.
        Body: {"estado": "liberado", "motivo_retencion": "opcional si es retenido"}
        """
        trazabilidad = self.get_object()
        nuevo_estado = request.data.get('estado')
        motivo_retencion = request.data.get('motivo_retencion')
        
        if nuevo_estado not in ['en_revision', 'liberado', 'retenido']:
            return Response(
                {'error': 'Estado inválido. Debe ser: en_revision, liberado o retenido'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Validar que control de calidad puede cambiar estado
        if request.user.rol != 'control_calidad':
            return Response(
                {'error': 'Solo Control de Calidad puede cambiar el estado'},
                status=status.HTTP_403_FORBIDDEN
            )
        
        # Si es retenido, el motivo es obligatorio
        if nuevo_estado == 'retenido' and not motivo_retencion:
            return Response(
                {'error': 'El motivo de retención es obligatorio cuando el estado es "Retenido"'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        try:
            trazabilidad.estado = nuevo_estado
            if nuevo_estado == 'retenido':
                trazabilidad.motivo_retencion = motivo_retencion
            trazabilidad.full_clean()
            trazabilidad.save()
            
            serializer = TrazabilidadDetailSerializer(trazabilidad)
            return Response({
                'success': True,
                'message': f'Estado cambiado a {trazabilidad.get_estado_display()}',
                'trazabilidad': serializer.data
            })
        except ValidationError as e:
            return Response(
                {'error': str(e)},
                status=status.HTTP_400_BAD_REQUEST
            )
    
    @action(detail=True, methods=['post'], permission_classes=[IsAuthenticated])
    def subir_foto_etiqueta(self, request, pk=None):
        """
        Endpoint: POST /api/trazabilidades/{id}/subir_foto_etiqueta/
        Sube la foto de etiquetas para una trazabilidad.
        Body: form-data con campo 'foto'
        """
        trazabilidad = self.get_object()
        
        if 'foto' not in request.FILES:
            return Response(
                {'error': 'No se envió ninguna foto'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        foto = request.FILES['foto']
        
        # Validar que sea una imagen
        if not foto.content_type.startswith('image/'):
            return Response(
                {'error': 'El archivo debe ser una imagen'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Crear o actualizar foto de etiqueta
        foto_etiqueta, created = FotoEtiqueta.objects.update_or_create(
            trazabilidad=trazabilidad,
            defaults={'foto': foto}
        )
        
        serializer = TrazabilidadDetailSerializer(trazabilidad)
        return Response({
            'success': True,
            'message': 'Foto de etiqueta subida correctamente',
            'trazabilidad': serializer.data
        })


# ============================================================================
# VIEWSET: Firmas de Trazabilidad
# ============================================================================
class FirmaTrazabilidadViewSet(viewsets.ModelViewSet):
    """
    ViewSet para Firmas de Trazabilidad.
    Permite crear y listar firmas (no modificar ni eliminar).
    """
    serializer_class = FirmaTrazabilidadSerializer
    permission_classes = [IsAuthenticated]
    http_method_names = ['get', 'post']  # Solo GET y POST
    
    def get_queryset(self):
        """
        Filtra firmas según parámetros de query.
        """
        queryset = FirmaTrazabilidad.objects.select_related(
            'trazabilidad__hoja_procesos__tarea',
            'usuario'
        )
        
        # Filtro por trazabilidad
        trazabilidad_id = self.request.query_params.get('trazabilidad', None)
        if trazabilidad_id:
            queryset = queryset.filter(trazabilidad_id=trazabilidad_id)
        
        # Filtro por tipo de firma
        tipo_firma = self.request.query_params.get('tipo_firma', None)
        if tipo_firma:
            queryset = queryset.filter(tipo_firma=tipo_firma)
        
        return queryset.order_by('-fecha_firma')
    
    def perform_create(self, serializer):
        """
        Al crear una firma, valida que el usuario tenga el rol correcto
        y asigna automáticamente el usuario actual.
        """
        trazabilidad = serializer.validated_data['trazabilidad']
        tipo_firma = serializer.validated_data['tipo_firma']
        
        # Validar que el usuario tenga el rol correcto
        if tipo_firma == 'supervisor' and self.request.user.rol != 'supervisor':
            raise ValidationError('Debes ser supervisor para firmar como supervisor')
        
        if tipo_firma == 'control_calidad' and self.request.user.rol != 'control_calidad':
            raise ValidationError('Debes ser control de calidad para firmar como control de calidad')
        
        # Validar que no exista ya una firma de este tipo
        if FirmaTrazabilidad.objects.filter(
            trazabilidad=trazabilidad,
            tipo_firma=tipo_firma
        ).exists():
            raise ValidationError(f'Ya existe una firma de {tipo_firma} para esta trazabilidad')
        
        serializer.save(usuario=self.request.user)
    
    @action(detail=False, methods=['post'], permission_classes=[IsAuthenticated])
    def firmar(self, request):
        """
        Endpoint: POST /api/firmas-trazabilidad/firmar/
        Crea una firma para una trazabilidad.
        Body: {"trazabilidad_id": 1}
        """
        trazabilidad_id = request.data.get('trazabilidad_id')
        
        if not trazabilidad_id:
            return Response(
                {'error': 'Se requiere el campo "trazabilidad_id"'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        try:
            trazabilidad = Trazabilidad.objects.get(id=trazabilidad_id)
        except Trazabilidad.DoesNotExist:
            return Response(
                {'error': 'La trazabilidad no existe'},
                status=status.HTTP_404_NOT_FOUND
            )
        
        # Determinar tipo de firma según el rol del usuario
        if request.user.rol == 'supervisor':
            tipo_firma = 'supervisor'
        elif request.user.rol == 'control_calidad':
            tipo_firma = 'control_calidad'
        else:
            return Response(
                {'error': 'Tu rol no tiene permisos para firmar'},
                status=status.HTTP_403_FORBIDDEN
            )
        
        # Validar que no exista ya una firma de este tipo
        if FirmaTrazabilidad.objects.filter(
            trazabilidad=trazabilidad,
            tipo_firma=tipo_firma
        ).exists():
            return Response(
                {'error': f'Ya existe una firma de {tipo_firma} para esta trazabilidad'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        try:
            # Crear la firma
            firma = FirmaTrazabilidad.objects.create(
                trazabilidad=trazabilidad,
                tipo_firma=tipo_firma,
                usuario=request.user
            )
            
            serializer = FirmaTrazabilidadSerializer(firma)
            return Response({
                'success': True,
                'message': f'Firma de {tipo_firma} creada correctamente',
                'firma': serializer.data
            }, status=status.HTTP_201_CREATED)
        except ValidationError as e:
            return Response(
                {'error': str(e)},
                status=status.HTTP_400_BAD_REQUEST
            )




