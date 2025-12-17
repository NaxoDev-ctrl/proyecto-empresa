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
    class Meta:
        model = Linea
        fields = ['id', 'nombre', 'activa', 'descripcion']
        read_only_fields = ['id']


# ============================================================================
# SERIALIZER: Turno
# ============================================================================
class TurnoSerializer(serializers.ModelSerializer):
    nombre_display = serializers.CharField(source='get_nombre_display', read_only=True)
    
    class Meta:
        model = Turno
        fields = ['id', 'nombre', 'nombre_display', 'hora_inicio', 'hora_fin', 'activo']
        read_only_fields = ['id']


# ============================================================================
# SERIALIZER: Colaborador
# ============================================================================
class ColaboradorSerializer(serializers.ModelSerializer):
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
    colaboradores = serializers.ListField(
        child=serializers.DictField(
            child=serializers.CharField()
        ),
        allow_empty=False
    )
    
    def validate_colaboradores(self, value):
        for colaborador in value:
            if 'codigo' not in colaborador:
                raise serializers.ValidationError("Cada colaborador debe tener un 'codigo'")
            if 'nombre' not in colaborador:
                raise serializers.ValidationError("Cada colaborador debe tener un 'nombre'")
            if 'apellido' not in colaborador:
                raise serializers.ValidationError("Cada colaborador debe tener un 'apellido'")
        
        return value
    
    def create(self, validated_data):
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
    materias_primas = serializers.SerializerMethodField()
    unidad_medida_display = serializers.CharField(
        source='get_unidad_medida_display',
        read_only=True
    )
    
    class Meta:
        model = Producto
        fields = ['codigo', 'nombre', 'unidad_medida', 'unidad_medida_display', 'descripcion', 'materias_primas']
    
    def get_materias_primas(self, obj):
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
    colaborador_detalle = ColaboradorSerializer(source='colaborador', read_only=True)
    
    class Meta:
        model = TareaColaborador
        fields = ['id', 'colaborador', 'colaborador_detalle', 'fecha_asignacion']
        read_only_fields = ['id', 'fecha_asignacion']


# ============================================================================
# SERIALIZER: Tarea (Listado)
# ============================================================================
class TareaListSerializer(serializers.ModelSerializer):
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
        return obj.fecha.timetuple().tm_yday
    
    def get_fecha_elaboracion_real(self, obj):
        if obj.fecha_inicio:
            # Retornar solo la FECHA (sin hora) en formato DD-MM-YYYY
            return obj.fecha_inicio.strftime('%d-%m-%Y')
        else:
            # Si aún no se ha iniciado, mostrar la fecha planificada
            return obj.fecha.strftime('%d-%m-%Y')
    
    def get_colaboradores(self, obj):
        return ColaboradorSerializer(
            [tc.colaborador for tc in obj.tarea_colaboradores.select_related('colaborador')],
            many=True
        ).data


# ============================================================================
# SERIALIZER: Tarea (Crear/Actualizar)
# ============================================================================
class TareaCreateUpdateSerializer(serializers.ModelSerializer):
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
        colaboradores = Colaborador.objects.filter(id__in=value, activo=True)
        
        if colaboradores.count() != len(value):
            raise serializers.ValidationError(
            )
        
        return value
    
    def validate_supervisor_asignador(self, value):
        if value.rol != 'supervisor':
            raise serializers.ValidationError(
            )
        return value
    
    def validate(self, data):
        return data
    
    def create(self, validated_data):
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
        colaboradores_ids = validated_data.pop('colaboradores_ids', None)
        
        for attr, value in validated_data.items():
            setattr(instance, attr, value)
        instance.save()
        
        if colaboradores_ids is not None:
            instance.tarea_colaboradores.all().delete()

            for colaborador_id in colaboradores_ids:
                TareaColaborador.objects.create(
                    tarea=instance,
                    colaborador_id=colaborador_id
                )
        
        return instance
    
    def to_representation(self, instance):
        return TareaDetailSerializer(instance, context=self.context).data
    

# ============================================================================
# SERIALIZER: Maquina
# ============================================================================
class MaquinaSerializer(serializers.ModelSerializer):
    class Meta:
        model = Maquina
        fields = ['id', 'codigo', 'nombre', 'activa']
        read_only_fields = ['id']


# ============================================================================
# SERIALIZER: TipoEvento
# ============================================================================
class TipoEventoSerializer(serializers.ModelSerializer):
    class Meta:
        model = TipoEvento
        fields = ['id', 'nombre', 'codigo', 'descripcion', 'orden', 'activo']
        read_only_fields = ['id']


# ============================================================================
# SERIALIZER: EventoMaquina
# ============================================================================
class EventoMaquinaSerializer(serializers.ModelSerializer):
    maquina_detalle = MaquinaSerializer(source='maquina', read_only=True)
    
    class Meta:
        model = EventoMaquina
        fields = ['id', 'maquina', 'maquina_detalle']
        read_only_fields = ['id']


# ============================================================================
# SERIALIZER: EventoProceso (Listado)
# ============================================================================
class EventoProcesoListSerializer(serializers.ModelSerializer):
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
        return MaquinaSerializer(
            [em.maquina for em in obj.evento_maquinas.select_related('maquina')],
            many=True
        ).data


# ============================================================================
# SERIALIZER: EventoProceso (Crear/Actualizar)
# ============================================================================
class EventoProcesoCreateUpdateSerializer(serializers.ModelSerializer):
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
        if value:
            maquinas = Maquina.objects.filter(id__in=value, activa=True)
            if maquinas.count() != len(value):
                raise serializers.ValidationError(
                )
        return value
    
    def create(self, validated_data):
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
        maquinas_ids = validated_data.pop('maquinas_ids', None)
        
        for attr, value in validated_data.items():
            setattr(instance, attr, value)
        instance.save()
        
        if maquinas_ids is not None:
            instance.evento_maquinas.all().delete()
            
            for maquina_id in maquinas_ids:
                EventoMaquina.objects.create(
                    evento=instance,
                    maquina_id=maquina_id
                )
        
        return instance
    
    def to_representation(self, instance):
        return EventoProcesoListSerializer(instance, context=self.context).data


# ============================================================================
# SERIALIZER: HojaProcesos (Listado)
# ============================================================================
class HojaProcesosListSerializer(serializers.ModelSerializer):
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
        return hasattr(obj, 'trazabilidad') and obj.trazabilidad is not None


# ============================================================================
# SERIALIZER: Reproceso
# ============================================================================
class ReprocesoSerializer(serializers.ModelSerializer):
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
    class Meta:
        model = FotoEtiqueta
        fields = ['id', 'foto', 'fecha_subida']
        read_only_fields = ['id', 'fecha_subida']


# ============================================================================
# SERIALIZER: FirmaTrazabilidad
# ============================================================================
class FirmaTrazabilidadSerializer(serializers.ModelSerializer):
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
        if obj.usuario:
            if hasattr(obj.usuario, 'get_full_name'):
                nombre = obj.usuario.get_full_name()
                if nombre and nombre.strip():
                    return nombre
            
            first = obj.usuario.first_name or ''
            last = obj.usuario.last_name or ''
            nombre_completo = f"{first} {last}".strip()
            
            if nombre_completo:
                return nombre_completo
            
            return obj.usuario.username
        
        return None


# ============================================================================
# SERIALIZER: Trazabilidad (Listado)
# ============================================================================
class TrazabilidadListSerializer(serializers.ModelSerializer):
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
        if obj.foto_etiquetas:
            request = self.context.get('request')
            if request:
                return request.build_absolute_uri(obj.foto_etiquetas.url)
            return obj.foto_etiquetas.url
        return None
    
    def to_representation(self, instance):
        data = super().to_representation(instance)
        colaboradores_lista = []
        
        try:
            relaciones = instance.colaboradores_reales.all()
            
            for relacion in relaciones:
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

        except Exception as e:
            print(f'   Error al serializar colaboradores: {e}')
            import traceback
            print(traceback.format_exc())
        
        data['colaboradores_reales'] = colaboradores_lista
        return data

class JSONStringField(serializers.Field):
    def to_internal_value(self, data):
        es_multipart = isinstance(data.get('materias_primas'), str)

        if es_multipart:
            if 'materias_primas' in data and data['materias_primas']:
                try:
                    data = data.copy()
                    data['materias_primas'] = json.loads(data['materias_primas'])
                    print(f'  ✅ materias_primas parseado: {len(data["materias_primas"])} elementos')
                except json.JSONDecodeError as e:
                    raise serializers.ValidationError({
                        'materias_primas': f'JSON inválido: {str(e)}'
                    })
            if 'colaboradores_codigos' in data and data['colaboradores_codigos']:
                try:
                    data['colaboradores_codigos'] = json.loads(data['colaboradores_codigos'])
                except json.JSONDecodeError as e:
                    raise serializers.ValidationError({
                        'colaboradores_codigos': f'JSON inválido: {str(e)}'
                    })
        else:
            print(' Request JSON - datos ya en formato correcto')
        
        
        return super().to_internal_value(data)
    
    def to_representation(self, value):
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

        if not value.replace('-', '').replace('_', '').isalnum():
            raise serializers.ValidationError(
                'El código solo puede contener letras, números, guiones y guiones bajos'
            )
        
        return value.strip()
    
    def validate(self, attrs):
        for key, value in attrs.items():
            if key == 'foto_etiquetas':
                print(f'  {key}: <IMAGE>')
            elif key in ['materias_primas', 'reprocesos_data', 'mermas_data']:
                print(f'  {key}: lista con {len(value)} elementos')
            else:
                print(f'  {key}: {value}')
        
        return attrs
    
    def validate_colaboradores_codigos(self, value):
        if isinstance(value, str):
            try:
                value = json.loads(value)
            except json.JSONDecodeError:
                raise serializers.ValidationError(
                    "Formato JSON inválido para colaboradores_codigos"
                )
        
        if not isinstance(value, list):
            raise serializers.ValidationError(
                "colaboradores_codigos debe ser una lista"
            )
        
        if len(value) == 0:
            raise serializers.ValidationError(
                "Debe haber al menos un colaborador"
            )
        
        codigos_int = []
        for codigo in value:
            try:
                codigo_int = int(codigo)
                codigos_int.append(codigo_int)
            except (ValueError, TypeError):
                raise serializers.ValidationError(
                    f"Código de colaborador inválido: {codigo}"
                )

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
        
        hoja_procesos = validated_data.get('hoja_procesos')
        tarea = hoja_procesos.tarea
        if tarea.fecha_inicio:
            fecha_elaboracion = tarea.fecha_inicio.date()
            print(f'Usando fecha de INICIO de tarea: {fecha_elaboracion}')
        else:
            fecha_elaboracion = tarea.fecha
            print(f'Tarea no iniciada, usando fecha planificada: {fecha_elaboracion}')
        juliano_calculado = Trazabilidad.calcular_juliano(fecha_elaboracion)
        print(f'Juliano calculado: {juliano_calculado}')

        trazabilidad = Trazabilidad(**validated_data)

        trazabilidad.juliano = juliano_calculado
        
        producto_codigo = trazabilidad.hoja_procesos.tarea.producto.codigo
        trazabilidad.lote = f"{producto_codigo}-{juliano_calculado}-{codigo_colaborador_lote}"

        
        # Guardar trazabilidad
        trazabilidad.save()
        
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
                            print(f'Error al crear reproceso {j+1}: {e}')
                else:
                    print(f'Sin reprocesos para {materia_prima.nombre}')
                
                # Crear mermas
                if 'mermas' in mp_data and mp_data['mermas']:
                    for j, merma_data in enumerate(mp_data['mermas']):
                        try:
                            Merma.objects.create(
                                trazabilidad_materia_prima=mp_usada,
                                cantidad=float(merma_data['cantidad']),
                                causas=merma_data['causas']
                            )
                            print(f'Merma {j+1}: {merma_data["cantidad"]} - {merma_data["causas"]}')
                        except Exception as e:
                            print(f'Error al crear merma {j+1}: {e}')
                else:
                    print(f'Sin mermas para {materia_prima.nombre}')

            except MateriaPrima.DoesNotExist:
                print(f' MP {i+1}: No encontrada {mp_data.get("materia_prima_id")}')
            except Exception as e:
                print(f'MP {i+1}: Error general: {e}')
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
                tarea.estado = 'finalizada'
                tarea.fecha_finalizacion = trazabilidad.fecha_creacion
                tarea.save()
            else:
                print(f'\n Tarea ya estaba finalizada')
                
        except Exception as e:
            print(f'\n Error al finalizar tarea: {e}')
        
        return trazabilidad
    
    def update(self, instance, validated_data):
        # Extraer datos relacionados
        materias_primas_data = validated_data.pop('materias_primas', None)
        colaboradores_codigos = validated_data.pop('colaboradores_codigos', None)
        codigo_colaborador_lote = validated_data.pop('codigo_colaborador_lote', None)

        if 'juliano' in validated_data:
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
        
        instance.save()
        
        # Actualizar materias primas si se proporcionaron
        if materias_primas_data is not None:
            instance.materias_primas_usadas.all().delete()
            
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
                        for j, reproceso_data in enumerate(mp_data['reprocesos']):
                            try:
                                Reproceso.objects.create(
                                    trazabilidad_materia_prima=mp_usada,
                                    cantidad=float(reproceso_data['cantidad']),
                                    causas=reproceso_data['causas']
                                )
                                print(f'Reproceso {j+1}: {reproceso_data["cantidad"]} - {reproceso_data["causas"]}')
                            except Exception as e:
                                print(f'Error al crear reproceso {j+1}: {e}')
                                import traceback
                                traceback.print_exc()
                    else:
                        print(f'Sin reprocesos para {materia_prima.nombre}')
                    
                    # ========== CREAR MERMAS ==========
                    if 'mermas' in mp_data and mp_data['mermas']:
                        for j, merma_data in enumerate(mp_data['mermas']):
                            try:
                                Merma.objects.create(
                                    trazabilidad_materia_prima=mp_usada,
                                    cantidad=float(merma_data['cantidad']),
                                    causas=merma_data['causas']
                                )
                                print(f'Merma {j+1}: {merma_data["cantidad"]} - {merma_data["causas"]}')
                            except Exception as e:
                                print(f'Error al crear merma {j+1}: {e}')
                                import traceback
                                traceback.print_exc()
                    else:
                        print(f'Sin mermas para {materia_prima.nombre}')
                        
                except MateriaPrima.DoesNotExist:
                    print(f'MP {i+1}: No encontrada {mp_data.get("materia_prima_id")}')
                except Exception as e:
                    print(f'MP {i+1}: Error general: {e}')
                    import traceback
                    traceback.print_exc()
        
        # Actualizar colaboradores si se proporcionaron
        if colaboradores_codigos is not None:
            instance.colaboradores_reales.all().delete()
            
            # Crear nuevos colaboradores
            for codigo in colaboradores_codigos:
                colaborador = Colaborador.objects.get(codigo=codigo)
                TrazabilidadColaborador.objects.create(
                    trazabilidad=instance,
                    colaborador=colaborador
                )
        return instance