from rest_framework import serializers
from .models import (
    Usuario, Linea, Turno, Colaborador,
    Producto, MateriaPrima, Receta,
    Tarea, TareaColaborador, Maquina, TipoEvento,
    HojaProcesos, EventoProceso, EventoMaquina,
    Trazabilidad, TrazabilidadMateriaPrima,
    Reproceso, Merma, FotoEtiqueta, FirmaTrazabilidad, TrazabilidadColaborador
)
from django.core.exceptions import ValidationError as DjangoValidationError
import json

# ============================================================================
# SERIALIZER: Usuario
# ============================================================================
class UsuarioSerializer(serializers.ModelSerializer):
    """
    Serializer para el modelo Usuario.
    Incluye información básica del usuario autenticado.
    """
    
    nombre_completo = serializers.SerializerMethodField()
    rol_display = serializers.CharField(source='get_rol_display', read_only=True)
    
    class Meta:
        model = Usuario
        fields = [
            'id',
            'username',
            'first_name',
            'last_name',
            'nombre_completo',
            'email',
            'rol',
            'rol_display',
            'activo'
        ]
        read_only_fields = ['id', 'username']
    
    def get_nombre_completo(self, obj):
        """Retorna el nombre completo del usuario"""
        return f"{obj.first_name} {obj.last_name}".strip()


# ============================================================================
# SERIALIZER: Línea
# ============================================================================
class LineaSerializer(serializers.ModelSerializer):
    """
    Serializer para el modelo Línea.
    """
    
    class Meta:
        model = Linea
        fields = ['id', 'nombre', 'activa', 'descripcion']
        read_only_fields = ['id']


# ============================================================================
# SERIALIZER: Turno
# ============================================================================
class TurnoSerializer(serializers.ModelSerializer):
    """
    Serializer para el modelo Turno.
    """
    
    nombre_display = serializers.CharField(source='get_nombre_display', read_only=True)
    
    class Meta:
        model = Turno
        fields = ['id', 'nombre', 'nombre_display', 'hora_inicio', 'hora_fin', 'activo']
        read_only_fields = ['id']


# ============================================================================
# SERIALIZER: Colaborador
# ============================================================================
class ColaboradorSerializer(serializers.ModelSerializer):
    """
    Serializer para el modelo Colaborador.
    """
    
    nombre_completo = serializers.CharField(read_only=True)
    
    class Meta:
        model = Colaborador
        fields = [
            'id',
            'codigo',
            'nombre',
            'apellido',
            'nombre_completo',
            'activo'
        ]
        read_only_fields = ['id']


class ColaboradorCreateSerializer(serializers.Serializer):
    """
    Serializer para crear múltiples colaboradores desde un archivo Excel.
    Recibe una lista de colaboradores.
    """
    
    colaboradores = serializers.ListField(
        child=serializers.DictField(
            child=serializers.CharField()
        ),
        allow_empty=False
    )
    
    def validate_colaboradores(self, value):
        """
        Valida que cada colaborador tenga los campos necesarios
        """
        for colaborador in value:
            if 'codigo' not in colaborador:
                raise serializers.ValidationError("Cada colaborador debe tener un 'codigo'")
            if 'nombre' not in colaborador:
                raise serializers.ValidationError("Cada colaborador debe tener un 'nombre'")
            if 'apellido' not in colaborador:
                raise serializers.ValidationError("Cada colaborador debe tener un 'apellido'")
        
        return value
    
    def create(self, validated_data):
        """
        Crea o actualiza colaboradores en la base de datos
        """
        colaboradores_data = validated_data['colaboradores']
        colaboradores_creados = []
        colaboradores_actualizados = []
        
        for data in colaboradores_data:
            colaborador, created = Colaborador.objects.update_or_create(
                codigo=data['codigo'],
                defaults={
                    'nombre': data['nombre'],
                    'apellido': data['apellido'],
                    'activo': True
                }
            )
            
            if created:
                colaboradores_creados.append(colaborador)
            else:
                colaboradores_actualizados.append(colaborador)
        
        return {
            'creados': colaboradores_creados,
            'actualizados': colaboradores_actualizados
        }


# ============================================================================
# SERIALIZER: Producto
# ============================================================================
class ProductoSerializer(serializers.ModelSerializer):
    """
    Serializer para el modelo Producto.
    """

    unidad_medida_display = serializers.CharField(
        source='get_unidad_medida_display',
        read_only=True
    )
    
    class Meta:
        model = Producto
        fields = ['codigo', 'nombre', 'unidad_medida', 'unidad_medida_display', 'descripcion', 'activo']
        read_only_fields = ['codigo']


# ============================================================================
# SERIALIZER: Materia Prima
# ============================================================================
class MateriaPrimaSerializer(serializers.ModelSerializer):
    """
    Serializer para el modelo MateriaPrima.
    """
    unidad_medida_display = serializers.CharField(
        source='get_unidad_medida_display',
        read_only=True
    )
    
    class Meta:
        model = MateriaPrima
        fields = ['id', 'codigo', 'nombre', 'unidad_medida', 'unidad_medida_display', 'requiere_lote', 'activo']
        read_only_fields = ['id']


# ============================================================================
# SERIALIZER: Receta
# ============================================================================
class RecetaSerializer(serializers.ModelSerializer):
    """
    Serializer para el modelo Receta.
    Incluye información detallada de la materia prima.
    """
    
    materia_prima_detalle = MateriaPrimaSerializer(source='materia_prima', read_only=True)
    
    class Meta:
        model = Receta
        fields = [
            'id',
            'materia_prima',
            'materia_prima_detalle',
            'orden',
            'activo'
        ]
        read_only_fields = ['id']


class ProductoConRecetaSerializer(serializers.ModelSerializer):
    """
    Serializer para Producto que incluye sus materias primas (receta).
    Útil para pre-cargar materias primas en la trazabilidad.
    """
    
    materias_primas = serializers.SerializerMethodField()
    unidad_medida_display = serializers.CharField(
        source='get_unidad_medida_display',
        read_only=True
    )
    
    class Meta:
        model = Producto
        fields = ['codigo', 'nombre', 'unidad_medida', 'unidad_medida_display', 'descripcion', 'materias_primas']
    
    def get_materias_primas(self, obj):
        """
        Retorna las materias primas asociadas al producto ordenadas
        """
        recetas = obj.recetas.filter(activo=True).select_related('materia_prima').order_by('orden')
        return [
            {
                'codigo': receta.materia_prima.codigo,
                'nombre': receta.materia_prima.nombre,
                'requiere_lote': receta.materia_prima.requiere_lote
            }
            for receta in recetas
        ]


# ============================================================================
# SERIALIZER: Tarea Colaborador
# ============================================================================
class TareaColaboradorSerializer(serializers.ModelSerializer):
    """
    Serializer para TareaColaborador.
    """
    
    colaborador_detalle = ColaboradorSerializer(source='colaborador', read_only=True)
    
    class Meta:
        model = TareaColaborador
        fields = ['id', 'colaborador', 'colaborador_detalle', 'fecha_asignacion']
        read_only_fields = ['id', 'fecha_asignacion']


# ============================================================================
# SERIALIZER: Tarea (Listado)
# ============================================================================
class TareaListSerializer(serializers.ModelSerializer):
    """
    Serializer para listar tareas (vista resumida).
    """
    
    linea_nombre = serializers.CharField(source='linea.nombre', read_only=True)
    turno_nombre = serializers.CharField(source='turno.nombre', read_only=True)
    producto_codigo = serializers.CharField(source='producto.codigo', read_only=True)
    producto_nombre = serializers.CharField(source='producto.nombre', read_only=True)
    producto_unidad_medida = serializers.CharField(
        source='producto.unidad_medida',
        read_only=True
    )
    producto_unidad_medida_display = serializers.CharField(
        source='producto.get_unidad_medida_display',
        read_only=True
    )
    estado_display = serializers.CharField(source='get_estado_display', read_only=True)
    supervisor_nombre = serializers.SerializerMethodField()
    
    class Meta:
        model = Tarea
        fields = [
            'id',
            'fecha',
            'linea',
            'linea_nombre',
            'turno',
            'turno_nombre',
            'producto_codigo',
            'producto_nombre',
            'producto_unidad_medida',
            'producto_unidad_medida_display',
            'meta_produccion',
            'estado',
            'estado_display',
            'supervisor_nombre',
            'fecha_creacion'
        ]
    
    def get_supervisor_nombre(self, obj):
        """Retorna el nombre completo del supervisor"""
        return f"{obj.supervisor_asignador.first_name} {obj.supervisor_asignador.last_name}".strip()


# ============================================================================
# SERIALIZER: Tarea (Detalle)
# ============================================================================
class TareaDetailSerializer(serializers.ModelSerializer):
    """
    Serializer para ver detalle completo de una tarea.
    """
    
    linea_detalle = LineaSerializer(source='linea', read_only=True)
    turno_detalle = TurnoSerializer(source='turno', read_only=True)
    producto_detalle = ProductoConRecetaSerializer(source='producto', read_only=True)
    supervisor_detalle = UsuarioSerializer(source='supervisor_asignador', read_only=True)
    colaboradores = serializers.SerializerMethodField()
    estado_display = serializers.CharField(source='get_estado_display', read_only=True)
    duracion_minutos = serializers.IntegerField(read_only=True)
    juliano_fecha_tarea = serializers.SerializerMethodField()
    fecha_elaboracion_real = serializers.SerializerMethodField()
    
    class Meta:
        model = Tarea
        fields = [
            'id',
            'fecha',
            'fecha_elaboracion_real',
            'juliano_fecha_tarea',
            'linea',
            'linea_detalle',
            'turno',
            'turno_detalle',
            'producto',
            'producto_detalle',
            'meta_produccion',
            'observaciones',
            'estado',
            'estado_display',
            'supervisor_asignador',
            'supervisor_detalle',
            'colaboradores',
            'fecha_creacion',
            'fecha_inicio',
            'fecha_finalizacion',
            'duracion_minutos'
        ]
        read_only_fields = [
            'id',
            'fecha_creacion',
            'fecha_inicio',
            'fecha_finalizacion',
            'duracion_minutos'
        ]

    def get_juliano_fecha_tarea(self, obj):
        """Calcula el día juliano de la fecha de la tarea"""
        return obj.fecha.timetuple().tm_yday
    
    def get_fecha_elaboracion_real(self, obj):
        """
        Retorna la fecha REAL de elaboración (cuando se inició la tarea).
        Si la tarea no se ha iniciado, retorna la fecha planificada.
        """
        if obj.fecha_inicio:
            # Retornar solo la FECHA (sin hora) en formato DD-MM-YYYY
            return obj.fecha_inicio.strftime('%d-%m-%Y')
        else:
            # Si aún no se ha iniciado, mostrar la fecha planificada
            return obj.fecha.strftime('%d-%m-%Y')
    
    def get_colaboradores(self, obj):
        """Retorna los colaboradores asignados a la tarea"""
        return ColaboradorSerializer(
            [tc.colaborador for tc in obj.tarea_colaboradores.select_related('colaborador')],
            many=True
        ).data


# ============================================================================
# SERIALIZER: Tarea (Crear/Actualizar)
# ============================================================================
class TareaCreateUpdateSerializer(serializers.ModelSerializer):
    """
    Serializer para crear y actualizar tareas.
    """
    
    colaboradores_ids = serializers.ListField(
        child=serializers.IntegerField(),
        write_only=True,
        required=True,
        allow_empty=False
    )
    
    class Meta:
        model = Tarea
        fields = [
            'id',
            'fecha',
            'linea',
            'turno',
            'producto',
            'meta_produccion',
            'observaciones',
            'supervisor_asignador',
            'colaboradores_ids'
        ]
        read_only_fields = ['id']
    
    def validate_colaboradores_ids(self, value):
        """Valida que los colaboradores existan"""
        colaboradores = Colaborador.objects.filter(id__in=value, activo=True)
        
        if colaboradores.count() != len(value):
            raise serializers.ValidationError(
                "Uno o más colaboradores no existen o están inactivos"
            )
        
        return value
    
    def validate_supervisor_asignador(self, value):
        """Valida que el usuario sea supervisor"""
        if value.rol != 'supervisor':
            raise serializers.ValidationError(
                "El usuario asignador debe tener rol de supervisor"
            )
        return value
    
    def validate(self, data):
        return data
    
    def create(self, validated_data):
        """Crea la tarea y asigna colaboradores"""
        colaboradores_ids = validated_data.pop('colaboradores_ids')
        
        # Crear la tarea
        tarea = Tarea.objects.create(**validated_data)
        
        # Asignar colaboradores
        for colaborador_id in colaboradores_ids:
            TareaColaborador.objects.create(
                tarea=tarea,
                colaborador_id=colaborador_id
            )
        
        return tarea
    
    def update(self, instance, validated_data):
        """Actualiza la tarea y sus colaboradores"""
        colaboradores_ids = validated_data.pop('colaboradores_ids', None)
        
        # Actualizar campos de la tarea
        for attr, value in validated_data.items():
            setattr(instance, attr, value)
        instance.save()
        
        # Si se enviaron colaboradores, actualizar la relación
        if colaboradores_ids is not None:
            # Eliminar asignaciones anteriores
            instance.tarea_colaboradores.all().delete()
            
            # Crear nuevas asignaciones
            for colaborador_id in colaboradores_ids:
                TareaColaborador.objects.create(
                    tarea=instance,
                    colaborador_id=colaborador_id
                )
        
        return instance
    
    def to_representation(self, instance):
        """Retorna la representación detallada después de crear/actualizar"""
        return TareaDetailSerializer(instance, context=self.context).data
    

# ============================================================================
# SERIALIZER: Maquina
# ============================================================================
class MaquinaSerializer(serializers.ModelSerializer):
    """
    Serializer para el modelo Maquina.
    """
    
    class Meta:
        model = Maquina
        fields = ['id', 'codigo', 'nombre', 'activa']
        read_only_fields = ['id']


# ============================================================================
# SERIALIZER: TipoEvento
# ============================================================================
class TipoEventoSerializer(serializers.ModelSerializer):
    """
    Serializer para el modelo TipoEvento.
    """
    
    class Meta:
        model = TipoEvento
        fields = ['id', 'nombre', 'codigo', 'descripcion', 'orden', 'activo']
        read_only_fields = ['id']


# ============================================================================
# SERIALIZER: EventoMaquina
# ============================================================================
class EventoMaquinaSerializer(serializers.ModelSerializer):
    """
    Serializer para EventoMaquina.
    """
    
    maquina_detalle = MaquinaSerializer(source='maquina', read_only=True)
    
    class Meta:
        model = EventoMaquina
        fields = ['id', 'maquina', 'maquina_detalle']
        read_only_fields = ['id']


# ============================================================================
# SERIALIZER: EventoProceso (Listado)
# ============================================================================
class EventoProcesoListSerializer(serializers.ModelSerializer):
    """
    Serializer para listar eventos de proceso.
    """
    
    tipo_evento_nombre = serializers.CharField(source='tipo_evento.nombre', read_only=True)
    tipo_evento_codigo = serializers.CharField(source='tipo_evento.codigo', read_only=True)
    duracion_minutos = serializers.IntegerField(read_only=True)
    maquinas = serializers.SerializerMethodField()
    
    class Meta:
        model = EventoProceso
        fields = [
            'id',
            'tipo_evento',
            'tipo_evento_nombre',
            'tipo_evento_codigo',
            'hora_inicio',
            'hora_fin',
            'duracion_minutos',
            'observaciones',
            'maquinas'
        ]
    
    def get_maquinas(self, obj):
        """Retorna las máquinas usadas en este evento"""
        return MaquinaSerializer(
            [em.maquina for em in obj.evento_maquinas.select_related('maquina')],
            many=True
        ).data


# ============================================================================
# SERIALIZER: EventoProceso (Crear/Actualizar)
# ============================================================================
class EventoProcesoCreateUpdateSerializer(serializers.ModelSerializer):
    """
    Serializer para crear y actualizar eventos de proceso.
    """
    
    maquinas_ids = serializers.ListField(
        child=serializers.IntegerField(),
        write_only=True,
        required=False,
        allow_empty=True
    )
    
    class Meta:
        model = EventoProceso
        fields = [
            'id',
            'hoja_procesos',
            'tipo_evento',
            'hora_inicio',
            'hora_fin',
            'observaciones',
            'maquinas_ids'
        ]
        read_only_fields = ['id']
    
    def validate_maquinas_ids(self, value):
        """Valida que las máquinas existan"""
        if value:
            maquinas = Maquina.objects.filter(id__in=value, activa=True)
            if maquinas.count() != len(value):
                raise serializers.ValidationError(
                    "Una o más máquinas no existen o están inactivas"
                )
        return value
    
    def create(self, validated_data):
        """Crea el evento y asigna máquinas"""
        maquinas_ids = validated_data.pop('maquinas_ids', [])
        
        # Crear el evento
        evento = EventoProceso.objects.create(**validated_data)
        
        # Asignar máquinas
        for maquina_id in maquinas_ids:
            EventoMaquina.objects.create(
                evento=evento,
                maquina_id=maquina_id
            )
        
        return evento
    
    def update(self, instance, validated_data):
        """Actualiza el evento y sus máquinas"""
        maquinas_ids = validated_data.pop('maquinas_ids', None)
        
        # Actualizar campos del evento
        for attr, value in validated_data.items():
            setattr(instance, attr, value)
        instance.save()
        
        # Si se enviaron máquinas, actualizar la relación
        if maquinas_ids is not None:
            # Eliminar asignaciones anteriores
            instance.evento_maquinas.all().delete()
            
            # Crear nuevas asignaciones
            for maquina_id in maquinas_ids:
                EventoMaquina.objects.create(
                    evento=instance,
                    maquina_id=maquina_id
                )
        
        return instance
    
    def to_representation(self, instance):
        """Retorna la representación detallada"""
        return EventoProcesoListSerializer(instance, context=self.context).data


# ============================================================================
# SERIALIZER: HojaProcesos (Listado)
# ============================================================================
class HojaProcesosListSerializer(serializers.ModelSerializer):
    """
    Serializer para listar hojas de procesos.
    """
    
    tarea_id = serializers.IntegerField(source='tarea.id', read_only=True)
    producto_nombre = serializers.CharField(source='tarea.producto.nombre', read_only=True)
    linea_nombre = serializers.CharField(source='tarea.linea.nombre', read_only=True)
    
    class Meta:
        model = HojaProcesos
        fields = [
            'id',
            'tarea',
            'tarea_id',
            'producto_nombre',
            'linea_nombre',
            'fecha_inicio',
            'fecha_finalizacion',
            'finalizada'
        ]


# ============================================================================
# SERIALIZER: HojaProcesos (Detalle)
# ============================================================================
class HojaProcesosDetailSerializer(serializers.ModelSerializer):
    """
    Serializer para ver detalle completo de una hoja de procesos.
    """
    
    tarea_detalle = TareaDetailSerializer(source='tarea', read_only=True)
    eventos = EventoProcesoListSerializer(many=True, read_only=True)
    tiene_trazabilidad = serializers.SerializerMethodField()
    
    class Meta:
        model = HojaProcesos
        fields = [
            'id',
            'tarea',
            'tarea_detalle',
            'fecha_inicio',
            'fecha_finalizacion',
            'finalizada',
            'eventos',
            'tiene_trazabilidad'
        ]
    def get_tiene_trazabilidad(self, obj):
        """
        Verifica si existe un registro de Trazabilidad asociado a esta hoja de procesos.
        Utiliza la relación OneToOne inversa 'trazabilidad'.
        
        Relación: HojaProcesos <-- OneToOne(related_name='trazabilidad') -- Trazabilidad
        
        Returns:
            bool: True si existe trazabilidad, False en caso contrario
        """
        return hasattr(obj, 'trazabilidad') and obj.trazabilidad is not None


# ============================================================================
# SERIALIZER: Reproceso
# ============================================================================
class ReprocesoSerializer(serializers.ModelSerializer):
    """
    Serializer para Reproceso.
    """

    causas_display = serializers.CharField(
        source='get_causas_display',
        read_only=True
    )
    
    class Meta:
        model = Reproceso
        fields = ['id', 'cantidad', 'causas', 'causas_display']
        read_only_fields = ['id']


# ============================================================================
# SERIALIZER: Merma
# ============================================================================
class MermaSerializer(serializers.ModelSerializer):
    """
    Serializer para Merma.
    """
    causas_display = serializers.CharField(
        source='get_causas_display',
        read_only=True
    )
    
    class Meta:
        model = Merma
        fields = ['id', 'cantidad', 'causas', 'causas_display']
        read_only_fields = ['id']


# ============================================================================
# SERIALIZER: TrazabilidadMateriaPrima
# ============================================================================
class TrazabilidadMateriaPrimaSerializer(serializers.ModelSerializer):
    """
    Serializer para TrazabilidadMateriaPrima.
    """
    
    materia_prima_detalle = MateriaPrimaSerializer(source='materia_prima', read_only=True)
    unidad_medida_display = serializers.CharField(source='get_unidad_medida_display', read_only=True)

    reprocesos = ReprocesoSerializer(many=True, read_only=True)
    mermas = MermaSerializer(many=True, read_only=True)
    
    class Meta:
        model = TrazabilidadMateriaPrima
        fields = [
            'id',
            'materia_prima',
            'materia_prima_detalle',
            'lote',
            'cantidad_usada',
            'unidad_medida',
            'unidad_medida_display',
            'reprocesos',
            'mermas'
        ]
        read_only_fields = ['id']


# ============================================================================
# SERIALIZER: FotoEtiqueta
# ============================================================================
class FotoEtiquetaSerializer(serializers.ModelSerializer):
    """
    Serializer para FotoEtiqueta.
    """
    
    class Meta:
        model = FotoEtiqueta
        fields = ['id', 'foto', 'fecha_subida']
        read_only_fields = ['id', 'fecha_subida']


# ============================================================================
# SERIALIZER: FirmaTrazabilidad
# ============================================================================
class FirmaTrazabilidadSerializer(serializers.ModelSerializer):
    """
    Serializer para FirmaTrazabilidad.
    """
    
    usuario_detalle = UsuarioSerializer(source='usuario', read_only=True)
    tipo_firma_display = serializers.CharField(source='get_tipo_firma_display', read_only=True)
    
    class Meta:
        model = FirmaTrazabilidad
        fields = [
            'id',
            'tipo_firma',
            'tipo_firma_display',
            'usuario',
            'usuario_detalle',
            'fecha_firma'
        ]
        read_only_fields = ['id', 'fecha_firma']

    def get_usuario_nombre(self, obj):
        """Obtener nombre completo del usuario"""
        if obj.usuario:
            # ✅ CORRECCIÓN: Usar get_full_name() o construir el nombre manualmente
            if hasattr(obj.usuario, 'get_full_name'):
                nombre = obj.usuario.get_full_name()
                if nombre and nombre.strip():
                    return nombre
            
            # Fallback: construir nombre desde first_name y last_name
            first = obj.usuario.first_name or ''
            last = obj.usuario.last_name or ''
            nombre_completo = f"{first} {last}".strip()
            
            if nombre_completo:
                return nombre_completo
            
            # Último fallback: username
            return obj.usuario.username
        
        return None


# ============================================================================
# SERIALIZER: Trazabilidad (Listado)
# ============================================================================
class TrazabilidadListSerializer(serializers.ModelSerializer):
    """
    Serializer para listar trazabilidades.
    """
    
    hoja_procesos = serializers.SerializerMethodField()
    firmas = serializers.SerializerMethodField()
    estado_display = serializers.CharField(source='get_estado_display', read_only=True)
    
    class Meta:
        model = Trazabilidad
        fields = [
            'id',
            'hoja_procesos',
            'cantidad_producida',
            'juliano',
            'lote',
            'estado',
            'estado_display',
            'observaciones',
            'fecha_creacion',
            'firmas'
        ]
    
    def get_hoja_procesos(self, obj):
        """Expandir hoja_procesos con tarea completa"""
        if not obj.hoja_procesos:
            return None
        
        hoja = obj.hoja_procesos
        tarea = hoja.tarea
        
        return {
            'id': hoja.id,
            'tarea': {
                'id': tarea.id,
                'fecha': tarea.fecha,
                'producto': {
                    'codigo': tarea.producto.codigo,
                    'nombre': tarea.producto.nombre,
                },
                'linea': {
                    'id': tarea.linea.id,
                    'nombre': tarea.linea.nombre,
                },
                'turno': {
                    'id': tarea.turno.id,
                    'nombre': tarea.turno.nombre,
                },
            }
        }
    
    def get_firmas(self, obj):
        """Obtener firmas con información del usuario"""
        firmas = obj.firmas.all()
        return [
            {
                'id': firma.id,
                'tipo_firma': firma.tipo_firma,
                'fecha_firma': firma.fecha_firma,
                'usuario_nombre': firma.usuario.get_full_name() or firma.usuario.username,
            }
            for firma in firmas
        ]

# ============================================================================
# SERIALIZER: Trazabilidad (Detalle)
# ============================================================================
class TrazabilidadDetailSerializer(serializers.ModelSerializer):
    """
    Serializer para ver detalle completo de una trazabilidad.
    """
    
    hoja_procesos_detalle = serializers.SerializerMethodField()
    materias_primas_usadas = TrazabilidadMateriaPrimaSerializer(many=True, read_only=True)
    reprocesos = ReprocesoSerializer(many=True, read_only=True)
    mermas = MermaSerializer(many=True, read_only=True)
    foto_etiqueta = FotoEtiquetaSerializer(read_only=True)
    firmas = FirmaTrazabilidadSerializer(many=True, read_only=True)
    foto_etiquetas_url = serializers.SerializerMethodField()
    estado_display = serializers.CharField(source='get_estado_display', read_only=True)
    
    class Meta:
        model = Trazabilidad
        fields = [
            'id',
            'hoja_procesos',
            'hoja_procesos_detalle',
            'cantidad_producida',
            'juliano',
            'lote',
            'foto_etiquetas',
            'foto_etiquetas_url',
            'estado',
            'estado_display',
            'motivo_retencion',
            'observaciones',
            'fecha_creacion',
            'materias_primas_usadas',
            'reprocesos',
            'mermas',
            'foto_etiqueta',
            'firmas'
        ]

    def get_hoja_procesos_detalle(self, obj):
        """Expandir hoja_procesos con tarea completa (igual que en TrazabilidadListSerializer)"""
        if not obj.hoja_procesos:
            return None
        
        hoja = obj.hoja_procesos
        tarea = hoja.tarea
        
        return {
            'id': hoja.id,
            'tarea': {
                'id': tarea.id,
                'fecha': tarea.fecha,
                'producto': {
                    'codigo': tarea.producto.codigo,
                    'nombre': tarea.producto.nombre,
                },
                'linea': {
                    'id': tarea.linea.id,
                    'nombre': tarea.linea.nombre,
                },
                'turno': {
                    'id': tarea.turno.id,
                    'nombre': tarea.turno.nombre,
                },
            }
        }

    def get_foto_etiquetas_url(self, obj):
        """Retorna la URL completa de la foto si existe"""
        if obj.foto_etiquetas:
            request = self.context.get('request')
            if request:
                return request.build_absolute_uri(obj.foto_etiquetas.url)
            return obj.foto_etiquetas.url
        return None
    
    def to_representation(self, instance):
        """
        Personalizar la salida del serializer
        """
        data = super().to_representation(instance)
        
        # ==================== COLABORADORES ====================
        
        print(f'\n👥 Serializando colaboradores de trazabilidad {instance.id}')
        
        colaboradores_lista = []
        
        try:
            # Obtener todas las relaciones TrazabilidadColaborador
            relaciones = instance.colaboradores_reales.all()
            print(f'   📊 Relaciones encontradas: {relaciones.count()}')
            
            for relacion in relaciones:
                # Cada relación tiene un atributo 'colaborador' que es el Colaborador real
                colaborador = relacion.colaborador
                
                colaboradores_lista.append({
                    'codigo': colaborador.codigo,
                    'nombre': colaborador.nombre,
                    'apellido': colaborador.apellido,
                    'colaborador': {
                        'codigo': colaborador.codigo,
                        'nombre': colaborador.nombre,
                        'apellido': colaborador.apellido
                    }
                })
                print(f'   ✅ Serializado: {colaborador.nombre} {colaborador.apellido} (código: {colaborador.codigo})')
        
        except Exception as e:
            print(f'   ❌ Error al serializar colaboradores: {e}')
            import traceback
            print(traceback.format_exc())
        
        data['colaboradores_reales'] = colaboradores_lista
        print(f'   📦 Total colaboradores en respuesta: {len(colaboradores_lista)}')
        
        return data

class JSONStringField(serializers.Field):
    """
    Campo personalizado que acepta JSON como string o como objeto Python.
    """
    
    def to_internal_value(self, data):
        """
        Convertir datos de entrada a formato interno.
        Maneja TANTO multipart/form-data (con foto) COMO application/json (sin foto)
        """
        
        print('\n' + '='*70)
        print('🔄 TO_INTERNAL_VALUE - CONVERSIÓN DE DATOS')
        print('='*70)
        
        # Detectar si es multipart o JSON
        es_multipart = isinstance(data.get('materias_primas'), str)
        
        print(f'📦 Tipo de request: {"MULTIPART" if es_multipart else "JSON"}')
        
        # Si es multipart, parsear los strings JSON
        if es_multipart:
            print('📝 Parseando strings JSON de multipart...')
            
            # Parsear materias_primas
            if 'materias_primas' in data and data['materias_primas']:
                try:
                    data = data.copy()  # No modificar el original
                    data['materias_primas'] = json.loads(data['materias_primas'])
                    print(f'  ✅ materias_primas parseado: {len(data["materias_primas"])} elementos')
                except json.JSONDecodeError as e:
                    raise serializers.ValidationError({
                        'materias_primas': f'JSON inválido: {str(e)}'
                    })
            
            # Parsear colaboradores_codigos
            if 'colaboradores_codigos' in data and data['colaboradores_codigos']:
                try:
                    data['colaboradores_codigos'] = json.loads(data['colaboradores_codigos'])
                    print(f'  ✅ colaboradores_codigos parseado: {len(data["colaboradores_codigos"])} elementos')
                except json.JSONDecodeError as e:
                    raise serializers.ValidationError({
                        'colaboradores_codigos': f'JSON inválido: {str(e)}'
                    })
        else:
            print('✅ Request JSON - datos ya en formato correcto')
        
        print('='*70 + '\n')
        
        return super().to_internal_value(data)
    
    def to_representation(self, value):
        """Convierte objeto Python a JSON para respuesta"""
        return value
    
# ============================================================================
# SERIALIZER: TrazabilidadColaborador
# ============================================================================
class TrazabilidadColaboradorSerializer(serializers.ModelSerializer):
    colaborador_codigo = serializers.IntegerField(
        source='colaborador.codigo',
        read_only=True
    )
    colaborador_nombre_completo = serializers.SerializerMethodField()
    
    class Meta:
        model = TrazabilidadColaborador
        fields = [
            'id',
            'colaborador',
            'colaborador_codigo',
            'colaborador_nombre_completo',
            'fecha_asignacion',
        ]
        read_only_fields = ['id', 'fecha_asignacion']
    
    def get_colaborador_nombre_completo(self, obj):
        return f"{obj.colaborador.nombre} {obj.colaborador.apellido}"

# ============================================================================
# SERIALIZER: Trazabilidad (Crear/Actualizar)
# ============================================================================
class TrazabilidadCreateUpdateSerializer(serializers.ModelSerializer):
    """
    Serializer para crear y actualizar Trazabilidad.
    Usa CharField para recibir JSON como strings desde multipart/form-data.
    """
    
    # USAR CHARFIELD en lugar de JSONField para aceptar strings
    materias_primas = serializers.JSONField(write_only=True, required=False)
    reprocesos_data = serializers.CharField(required=False, allow_blank=True, allow_null=True)
    mermas_data = serializers.CharField(required=False, allow_blank=True, allow_null=True)
    foto_etiquetas = serializers.ImageField(required=False, allow_null=True)
    colaboradores_reales = TrazabilidadColaboradorSerializer(
        many=True,
        read_only=True
    )
    colaboradores_codigos = serializers.JSONField(
        write_only=True,
        required=True,
        help_text='Lista de códigos de colaboradores que trabajaron'
    )

    codigo_colaborador_lote = serializers.CharField(
        write_only=True,
        required=True,
        max_length=10,
        help_text='Código del colaborador a cargo para generar el lote. Ejemplo: 96'
    )
    
    class Meta:
        model = Trazabilidad
        fields = [
            'id',
            'hoja_procesos',
            'cantidad_producida',
            'juliano',
            'lote',
            'foto_etiquetas',
            'estado',
            'motivo_retencion',
            'observaciones',
            'materias_primas',
            'reprocesos_data',
            'mermas_data',
            'colaboradores_reales',  
            'colaboradores_codigos',
            'codigo_colaborador_lote',
        ]
        read_only_fields = ['id', 'estado', 'juliano', 'lote']

    def validate_codigo_colaborador_lote(self, value):
        """Validar que el código del colaborador sea válido"""
        if not value or not value.strip():
            raise serializers.ValidationError('El código del colaborador es obligatorio')
        
        # Validar formato (solo números/letras, sin espacios)
        if not value.replace('-', '').replace('_', '').isalnum():
            raise serializers.ValidationError(
                'El código solo puede contener letras, números, guiones y guiones bajos'
            )
        
        return value.strip()
    
    def validate(self, attrs):
        """Validación general"""
        print('\n' + '='*70)
        print('VALIDACIÓN GENERAL')
        print('='*70)
        
        for key, value in attrs.items():
            if key == 'foto_etiquetas':
                print(f'  {key}: <IMAGE>')
            elif key in ['materias_primas', 'reprocesos_data', 'mermas_data']:
                print(f'  {key}: lista con {len(value)} elementos')
            else:
                print(f'  {key}: {value}')
        
        print('='*70 + '\n')
        return attrs
    
    def validate_colaboradores_codigos(self, value):
        """Validar códigos de colaboradores"""
        
        # Si llega como string JSON, parsearlo
        if isinstance(value, str):
            try:
                value = json.loads(value)
            except json.JSONDecodeError:
                raise serializers.ValidationError(
                    "Formato JSON inválido para colaboradores_codigos"
                )
        
        # Verificar que sea una lista
        if not isinstance(value, list):
            raise serializers.ValidationError(
                "colaboradores_codigos debe ser una lista"
            )
        
        # Verificar que no esté vacía
        if len(value) == 0:
            raise serializers.ValidationError(
                "Debe haber al menos un colaborador"
            )
        
        # Convertir a enteros
        codigos_int = []
        for codigo in value:
            try:
                codigo_int = int(codigo)
                codigos_int.append(codigo_int)
            except (ValueError, TypeError):
                raise serializers.ValidationError(
                    f"Código de colaborador inválido: {codigo}"
                )
        
        # Verificar que existan en BD
        colaboradores_existentes = Colaborador.objects.filter(
            codigo__in=codigos_int
        ).count()
        
        if colaboradores_existentes != len(codigos_int):
            codigos_faltantes = set(codigos_int) - set(
                Colaborador.objects.filter(codigo__in=codigos_int).values_list('codigo', flat=True)
            )
            raise serializers.ValidationError(
                f"Colaboradores no encontrados: {codigos_faltantes}"
            )
        
        return codigos_int
    
    def create(self, validated_data):
        """Crear trazabilidad con sus relaciones"""
        
        print('='*70)
        print('CREANDO TRAZABILIDAD')
        print('='*70)
        
        # Extraer datos relacionados
        materias_primas_data = validated_data.pop('materias_primas', []) or []
        reprocesos_data = validated_data.pop('reprocesos_data', []) or []
        mermas_data = validated_data.pop('mermas_data', []) or []
        colaboradores_codigos = validated_data.pop('colaboradores_codigos')
        codigo_colaborador_lote = validated_data.pop('codigo_colaborador_lote')
        
        print(f'Hoja Procesos: {validated_data.get("hoja_procesos")}')
        print(f'Cantidad: {validated_data.get("cantidad_producida")}')
        print(f'Foto: {"Sí" if validated_data.get("foto_etiquetas") else "No"}')
        print(f'Materias primas: {len(materias_primas_data)}')
        print(f'Reprocesos: {len(reprocesos_data)}')
        print(f'Mermas: {len(mermas_data)}')
        print(f'Código colaborador lote: {codigo_colaborador_lote}')
        
        # Crear trazabilidad
        hoja_procesos = validated_data.get('hoja_procesos')
        tarea = hoja_procesos.tarea
        if tarea.fecha_inicio:
            fecha_elaboracion = tarea.fecha_inicio.date()
            print(f'📅 Usando fecha de INICIO de tarea: {fecha_elaboracion}')
        else:
            fecha_elaboracion = tarea.fecha
            print(f'⚠️  Tarea no iniciada, usando fecha planificada: {fecha_elaboracion}')
        juliano_calculado = Trazabilidad.calcular_juliano(fecha_elaboracion)
        print(f'📅 Juliano calculado: {juliano_calculado}')

        trazabilidad = Trazabilidad(**validated_data)

        trazabilidad.juliano = juliano_calculado
        
        producto_codigo = trazabilidad.hoja_procesos.tarea.producto.codigo
        trazabilidad.lote = f"{producto_codigo}-{juliano_calculado}-{codigo_colaborador_lote}"
        
        print(f'🏷️  Lote generado: {trazabilidad.lote}')
        
        # Guardar trazabilidad
        trazabilidad.save()
        print(f'✅ Trazabilidad creada: ID {trazabilidad.id}')
        
        # Crear materias primas usadas
        for i, mp_data in enumerate(materias_primas_data):
            try:
                materia_prima = MateriaPrima.objects.get(codigo=mp_data['materia_prima_id'])
                
                mp_usada = TrazabilidadMateriaPrima.objects.create(
                    trazabilidad=trazabilidad,
                    materia_prima=materia_prima,
                    lote=mp_data.get('lote'),
                    cantidad_usada=float(mp_data['cantidad_usada']),
                    unidad_medida=mp_data['unidad_medida']
                )
                print(f'  ✅ MP {i+1}: {materia_prima.nombre}')
        
                # Crear reprocesos
                if 'reprocesos' in mp_data and mp_data['reprocesos']:
                    print(f'    🔍 Procesando reprocesos para {materia_prima.nombre}...')
                    
                    for j, reproceso_data in enumerate(mp_data['reprocesos']):
                        try:
                            Reproceso.objects.create(
                                trazabilidad_materia_prima=mp_usada,
                                cantidad=float(reproceso_data['cantidad']),
                                causas=reproceso_data['causas']
                            )
                            print(f'      ✅ Reproceso {j+1}: {reproceso_data["cantidad"]} - {reproceso_data["causas"]}')
                        except Exception as e:
                            print(f'      ❌ Error al crear reproceso {j+1}: {e}')
                else:
                    print(f'    ℹ️  Sin reprocesos para {materia_prima.nombre}')
                
                # Crear mermas
                if 'mermas' in mp_data and mp_data['mermas']:
                    print(f'    🔍 Procesando mermas para {materia_prima.nombre}...')
                    
                    for j, merma_data in enumerate(mp_data['mermas']):
                        try:
                            Merma.objects.create(
                                trazabilidad_materia_prima=mp_usada,
                                cantidad=float(merma_data['cantidad']),
                                causas=merma_data['causas']
                            )
                            print(f'      ✅ Merma {j+1}: {merma_data["cantidad"]} - {merma_data["causas"]}')
                        except Exception as e:
                            print(f'      ❌ Error al crear merma {j+1}: {e}')
                else:
                    print(f'    ℹ️  Sin mermas para {materia_prima.nombre}')

            except MateriaPrima.DoesNotExist:
                print(f'  ❌ MP {i+1}: No encontrada {mp_data.get("materia_prima_id")}')
            except Exception as e:
                print(f'  ❌ MP {i+1}: Error general: {e}')
                import traceback
                traceback.print_exc()

        # Crear colaboradores
        for colaborador_codigo in colaboradores_codigos:
            colaborador = Colaborador.objects.get(codigo=colaborador_codigo)
            TrazabilidadColaborador.objects.create(
                trazabilidad=trazabilidad,
                colaborador=colaborador
            )

        # ========================================================================
        # FINALIZAR LA TAREA AUTOMÁTICAMENTE
        # ========================================================================
        try:
            tarea = trazabilidad.hoja_procesos.tarea
            
            if tarea.estado != 'finalizada':
                print(f'\n📌 Finalizando tarea ID {tarea.id}...')
                tarea.estado = 'finalizada'
                tarea.fecha_finalizacion = trazabilidad.fecha_creacion
                tarea.save()
                print(f'✅ Tarea finalizada: {tarea.producto.nombre}')
            else:
                print(f'\nℹ️  Tarea ya estaba finalizada')
                
        except Exception as e:
            print(f'\n⚠️  Error al finalizar tarea: {e}')
            # No lanzar excepción, la trazabilidad ya se creó correctamente
        
        print('='*70)
        print('✅ TRAZABILIDAD CREADA EXITOSAMENTE')
        print('='*70 + '\n')
        
        return trazabilidad
    
    def update(self, instance, validated_data):
        """Actualizar trazabilidad con sus relaciones"""
        
        print('\n' + '='*70)
        print('🔄 ACTUALIZANDO TRAZABILIDAD CON REPROCESOS/MERMAS')
        print('='*70)
        print('🚨'*35)
        print(f'Instance ID: {instance.id}')
        print(f'Validated data keys: {validated_data.keys()}')
        print('🚨'*35 + '\n')
        
        # Extraer datos relacionados
        materias_primas_data = validated_data.pop('materias_primas', None)
        colaboradores_codigos = validated_data.pop('colaboradores_codigos', None)
        codigo_colaborador_lote = validated_data.pop('codigo_colaborador_lote', None)
        
        print(f'📦 Materias primas recibidas: {len(materias_primas_data) if materias_primas_data else 0}')
        
        if 'juliano' in validated_data:
            print('⚠️  Intentando modificar juliano - IGNORADO para preservar fecha original')
            validated_data.pop('juliano')
            
        # Actualizar campos básicos de la trazabilidad
        for attr, value in validated_data.items():
            setattr(instance, attr, value)
        
        # Actualizar lote si se proporcionó código de colaborador
        if codigo_colaborador_lote:
            partes_lote = instance.lote.split('-')
            if len(partes_lote) == 3:
                nuevo_lote = f"{partes_lote[0]}-{partes_lote[1]}-{codigo_colaborador_lote}"
                instance.lote = nuevo_lote
                print(f'🏷️  Lote actualizado: {nuevo_lote}')
        
        instance.save()
        print(f'✅ Trazabilidad actualizada: ID {instance.id}')
        
        # Actualizar materias primas si se proporcionaron
        if materias_primas_data is not None:
            print(f'\n🔄 Procesando materias primas ({len(materias_primas_data)} total)...')
            
            # ELIMINAR todas las materias primas existentes
            # (esto también elimina reprocesos/mermas por CASCADE)
            instance.materias_primas_usadas.all().delete()
            print('  🗑️  Materias primas anteriores eliminadas (con reprocesos/mermas)')
            
            # CREAR nuevas materias primas con sus reprocesos/mermas
            for i, mp_data in enumerate(materias_primas_data):
                try:
                    materia_prima = MateriaPrima.objects.get(codigo=mp_data['materia_prima_id'])
                    
                    mp_usada = TrazabilidadMateriaPrima.objects.create(
                        trazabilidad=instance,
                        materia_prima=materia_prima,
                        lote=mp_data.get('lote'),
                        cantidad_usada=float(mp_data['cantidad_usada']),
                        unidad_medida=mp_data['unidad_medida']
                    )
                    print(f'  ✅ MP {i+1}: {materia_prima.nombre} - {mp_data["cantidad_usada"]} {mp_data["unidad_medida"]}')
                    
                    # ========== CREAR REPROCESOS ==========
                    if 'reprocesos' in mp_data and mp_data['reprocesos']:
                        print(f'    🔍 Procesando reprocesos para {materia_prima.nombre}...')
                        
                        for j, reproceso_data in enumerate(mp_data['reprocesos']):
                            try:
                                Reproceso.objects.create(
                                    trazabilidad_materia_prima=mp_usada,
                                    cantidad=float(reproceso_data['cantidad']),
                                    causas=reproceso_data['causas']
                                )
                                print(f'      ✅ Reproceso {j+1}: {reproceso_data["cantidad"]} - {reproceso_data["causas"]}')
                            except Exception as e:
                                print(f'      ❌ Error al crear reproceso {j+1}: {e}')
                                import traceback
                                traceback.print_exc()
                    else:
                        print(f'    ℹ️  Sin reprocesos para {materia_prima.nombre}')
                    
                    # ========== CREAR MERMAS ==========
                    if 'mermas' in mp_data and mp_data['mermas']:
                        print(f'    🔍 Procesando mermas para {materia_prima.nombre}...')
                        
                        for j, merma_data in enumerate(mp_data['mermas']):
                            try:
                                Merma.objects.create(
                                    trazabilidad_materia_prima=mp_usada,
                                    cantidad=float(merma_data['cantidad']),
                                    causas=merma_data['causas']
                                )
                                print(f'      ✅ Merma {j+1}: {merma_data["cantidad"]} - {merma_data["causas"]}')
                            except Exception as e:
                                print(f'      ❌ Error al crear merma {j+1}: {e}')
                                import traceback
                                traceback.print_exc()
                    else:
                        print(f'    ℹ️  Sin mermas para {materia_prima.nombre}')
                        
                except MateriaPrima.DoesNotExist:
                    print(f'  ❌ MP {i+1}: No encontrada {mp_data.get("materia_prima_id")}')
                except Exception as e:
                    print(f'  ❌ MP {i+1}: Error general: {e}')
                    import traceback
                    traceback.print_exc()
        
        # Actualizar colaboradores si se proporcionaron
        if colaboradores_codigos is not None:
            print(f'\n👥 Actualizando colaboradores ({len(colaboradores_codigos)} total)...')
            
            # Eliminar colaboradores anteriores
            instance.colaboradores_reales.all().delete()
            
            # Crear nuevos colaboradores
            for codigo in colaboradores_codigos:
                colaborador = Colaborador.objects.get(codigo=codigo)
                TrazabilidadColaborador.objects.create(
                    trazabilidad=instance,
                    colaborador=colaborador
                )
                print(f'  ✅ Colaborador: {colaborador.nombre} {colaborador.apellido}')
        
        print('='*70)
        print('✅ TRAZABILIDAD ACTUALIZADA EXITOSAMENTE')
        print('='*70 + '\n')
        
        return instance