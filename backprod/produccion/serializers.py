from rest_framework import serializers
from .models import (
    Usuario, Linea, Turno, Colaborador,
    Producto, MateriaPrima, Receta,
    Tarea, TareaColaborador
)


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
    
    class Meta:
        model = Producto
        fields = ['codigo', 'nombre', 'descripcion', 'activo']
        read_only_fields = ['codigo']


# ============================================================================
# SERIALIZER: Materia Prima
# ============================================================================
class MateriaPrimaSerializer(serializers.ModelSerializer):
    """
    Serializer para el modelo MateriaPrima.
    """
    
    class Meta:
        model = MateriaPrima
        fields = ['id', 'codigo', 'nombre', 'requiere_lote', 'activo']
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
    
    class Meta:
        model = Producto
        fields = ['codigo', 'nombre', 'descripcion', 'materias_primas']
    
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
    
    class Meta:
        model = Tarea
        fields = [
            'id',
            'fecha',
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
        """Validaciones adicionales"""
        # Validar que no exista una tarea igual
        tarea_existente = Tarea.objects.filter(
            linea=data['linea'],
            turno=data['turno'],
            fecha=data['fecha'],
            producto=data['producto']
        )
        
        # Si estamos actualizando, excluir la tarea actual
        if self.instance:
            tarea_existente = tarea_existente.exclude(pk=self.instance.pk)
        
        if tarea_existente.exists():
            raise serializers.ValidationError(
                "Ya existe una tarea con esa línea, turno, fecha y producto"
            )
        
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