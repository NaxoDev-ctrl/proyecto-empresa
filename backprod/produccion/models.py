#from django.db import models

# Create your models here.

from django.db import models
from django.contrib.auth.models import AbstractUser
from django.core.validators import MinValueValidator
from django.core.exceptions import ValidationError
from datetime import date, datetime
from .validators import validate_image_file


# ============================================================================
# MODELO: Usuario (Extendido de AbstractUser)
# ============================================================================
class Usuario(AbstractUser):
    """
    Modelo de usuario del sistema.
    Solo puede ser creado por el administrador.
    """
    
    ROLES = [
        ('supervisor', 'Supervisor'),
        ('control_calidad', 'Control de Calidad'),
    ]
    
    rol = models.CharField(
        max_length=20,
        choices=ROLES,
        help_text="Rol del usuario en el sistema"
    )
    
    activo = models.BooleanField(
        default=True,
        help_text="Indica si el usuario puede acceder al sistema"
    )
    
    fecha_creacion = models.DateTimeField(
        auto_now_add=True,
        help_text="Fecha y hora de creación del usuario"
    )
    
    fecha_modificacion = models.DateTimeField(
        auto_now=True,
        help_text="Fecha y hora de última modificación"
    )
    
    class Meta:
        db_table = 'usuarios'
        verbose_name = 'Usuario'
        verbose_name_plural = 'Usuarios'
        ordering = ['username']
    
    def __str__(self):
        return f"{self.username} - {self.get_rol_display()}"


# ============================================================================
# MODELO: Línea de Producción
# ============================================================================
class Linea(models.Model):
    """
    Representa una línea de producción en la planta.
    """
    
    nombre = models.CharField(
        max_length=50,
        unique=True,
        help_text="Nombre de la línea de producción"
    )
    
    activa = models.BooleanField(
        default=True,
        help_text="Indica si la línea está operativa"
    )
    
    descripcion = models.TextField(
        blank=True,
        null=True,
        help_text="Descripción opcional de la línea"
    )
    
    fecha_creacion = models.DateTimeField(
        auto_now_add=True
    )
    
    class Meta:
        db_table = 'lineas'
        verbose_name = 'Línea de Producción'
        verbose_name_plural = 'Líneas de Producción'
        ordering = ['nombre']
    
    def __str__(self):
        return self.nombre


# ============================================================================
# MODELO: Turno
# ============================================================================
class Turno(models.Model):
    """
    Representa los turnos de trabajo en la planta.
    """
    
    TURNOS_CHOICES = [
        ('AM', 'AM (06:15-13:35)'),
        ('Jornada', 'Jornada (08:00-17:30)'),
        ('PM', 'PM (13:25-22:05)'),
    ]
    
    nombre = models.CharField(
        max_length=20,
        choices=TURNOS_CHOICES,
        unique=True,
        help_text="Nombre del turno"
    )
    
    hora_inicio = models.TimeField(
        help_text="Hora de inicio del turno"
    )
    
    hora_fin = models.TimeField(
        help_text="Hora de fin del turno"
    )
    
    activo = models.BooleanField(
        default=True,
        help_text="Indica si el turno está activo"
    )
    
    class Meta:
        db_table = 'turnos'
        verbose_name = 'Turno'
        verbose_name_plural = 'Turnos'
        ordering = ['hora_inicio']
    
    def __str__(self):
        return f"{self.nombre} ({self.hora_inicio.strftime('%H:%M')}-{self.hora_fin.strftime('%H:%M')})"


# ============================================================================
# MODELO: Colaborador
# ============================================================================
class Colaborador(models.Model):
    """
    Representa a los colaboradores que trabajan en las líneas.
    Se cargan desde un archivo Excel por el supervisor.
    """
    
    codigo = models.IntegerField(
        unique=True,
        help_text="Código identificador del colaborador"
    )
    
    nombre = models.CharField(
        max_length=100,
        help_text="Nombre del colaborador"
    )
    
    apellido = models.CharField(
        max_length=100,
        help_text="Apellido del colaborador"
    )
    
    activo = models.BooleanField(
        default=True,
        help_text="Indica si el colaborador está activo en el sistema"
    )
    
    fecha_carga = models.DateTimeField(
        auto_now_add=True,
        help_text="Fecha y hora en que fue cargado al sistema"
    )
    
    fecha_actualizacion = models.DateTimeField(
        auto_now=True,
        help_text="Última actualización del registro"
    )
    
    class Meta:
        db_table = 'colaboradores'
        verbose_name = 'Colaborador'
        verbose_name_plural = 'Colaboradores'
        ordering = ['codigo']
        indexes = [
            models.Index(fields=['codigo']),
            models.Index(fields=['nombre', 'apellido']),
        ]
    
    def __str__(self):
        return f"{self.codigo} - {self.nombre} {self.apellido}"
    
    @property
    def nombre_completo(self):
        """Retorna el nombre completo del colaborador"""
        return f"{self.nombre} {self.apellido}"


# ============================================================================
# MODELO: Producto
# ============================================================================
class Producto(models.Model):
    """
    Representa los productos que se fabrican.
    """
    
    codigo = models.CharField(
        max_length=20,
        primary_key=True,
        help_text="Código identificador del producto. Ejemplo: 410"
    )
    
    nombre = models.CharField(
        max_length=200,
        help_text="Nombre del producto. Ejemplo: alfajor manjar bitter"
    )
    
    descripcion = models.TextField(
        blank=True,
        null=True,
        help_text="Descripción detallada del producto"
    )
    
    activo = models.BooleanField(
        default=True,
        help_text="Indica si el producto está en producción"
    )
    
    class Meta:
        db_table = 'productos'
        verbose_name = 'Producto'
        verbose_name_plural = 'Productos'
        ordering = ['codigo']
    
    def __str__(self):
        return f"{self.codigo} - {self.nombre}"


# ============================================================================
# MODELO: Materia Prima
# ============================================================================
class MateriaPrima(models.Model):
    """
    Representa las materias primas asociadas a cada producto (receta).
    """

    UNIDADES_MEDIDA = [
        ('KG', 'KG'),
        ('UN', 'UN'),
    ]
    
    codigo = models.CharField(
        max_length=20,
        unique=True,
        help_text="Código de la materia prima. Ejemplo: LAC0001"
    )
    
    nombre = models.CharField(
        max_length=200,
        help_text="Nombre de la materia prima. Ejemplo: manjar"
    )

    unidad_medida = models.CharField(
        max_length=20,
        choices=UNIDADES_MEDIDA,
        default='KG',
        help_text='Unidad de medida por defecto de esta materia prima'
    )
    
    requiere_lote = models.BooleanField(
        default=True,
        help_text="Indica si esta materia prima requiere registro de lote"
    )
    
    activo = models.BooleanField(
        default=True,
        help_text="Indica si la materia prima está activa"
    )
    
    class Meta:
        db_table = 'materias_primas'
        verbose_name = 'Materia Prima'
        verbose_name_plural = 'Materias Primas'
        ordering = ['codigo']
    
    def __str__(self):
        return f"{self.codigo} - {self.nombre}"


# ============================================================================
# MODELO: Receta
# ============================================================================
class Receta(models.Model):
    """
    Relaciona un producto con sus materias primas necesarias.
    """
    
    producto = models.ForeignKey(
        Producto,
        on_delete=models.CASCADE,
        related_name='recetas',
        help_text="Producto al que pertenece esta materia prima"
    )
    
    materia_prima = models.ForeignKey(
        MateriaPrima,
        on_delete=models.CASCADE,
        related_name='recetas',
        help_text="Materia prima necesaria"
    )
    
    orden = models.PositiveIntegerField(
        default=0,
        help_text="Orden de visualización en la lista"
    )
    
    activo = models.BooleanField(
        default=True,
        help_text="Indica si esta materia prima está activa en la receta"
    )
    
    class Meta:
        db_table = 'recetas'
        verbose_name = 'Receta'
        verbose_name_plural = 'Recetas'
        ordering = ['producto', 'orden']
        unique_together = ['producto', 'materia_prima']
        indexes = [
            models.Index(fields=['producto']),
        ]
    
    def __str__(self):
        return f"{self.producto.codigo} - {self.materia_prima.nombre}"


# ============================================================================
# MODELO: Tarea
# ============================================================================
class Tarea(models.Model):
    """
    Representa una tarea de producción asignada a una línea específica
    en un turno determinado.
    """
    
    # Relaciones
    linea = models.ForeignKey(
        Linea,
        on_delete=models.PROTECT,
        related_name='tareas',
        help_text="Línea donde se realizará la producción"
    )
    
    producto = models.ForeignKey(
        Producto,
        on_delete=models.PROTECT,
        related_name='tareas',
        help_text="Producto a fabricar"
    )
    
    turno = models.ForeignKey(
        Turno,
        on_delete=models.PROTECT,
        related_name='tareas',
        help_text="Turno en que se realizará la producción"
    )
    
    supervisor_asignador = models.ForeignKey(
        Usuario,
        on_delete=models.PROTECT,
        related_name='tareas_asignadas',
        help_text="Supervisor que creó esta tarea"
    )
    
    # Campos de información
    fecha = models.DateField(
        default=date.today,
        help_text="Fecha de la producción",
        db_index=True
    )
    
    meta_produccion = models.PositiveIntegerField(
        validators=[MinValueValidator(1)],
        help_text="Meta de producción en unidades"
    )
    
    observaciones = models.TextField(
        blank=True,
        null=True,
        max_length=500,
        help_text="Observaciones sobre la tarea"
    )
    
    # Estados de la tarea
    ESTADOS = [
        ('pendiente', 'Pendiente'),
        ('en_curso', 'En Curso'),
        ('finalizada', 'Finalizada'),
    ]
    
    estado = models.CharField(
        max_length=20,
        choices=ESTADOS,
        default='pendiente',
        help_text="Estado actual de la tarea",
        db_index=True
    )
    
    # Auditoría
    fecha_creacion = models.DateTimeField(
        auto_now_add=True,
        help_text="Fecha y hora de creación de la tarea"
    )
    
    fecha_inicio = models.DateTimeField(
        blank=True,
        null=True,
        help_text="Fecha y hora en que se inició la producción"
    )
    
    fecha_finalizacion = models.DateTimeField(
        blank=True,
        null=True,
        help_text="Fecha y hora en que se finalizó la producción"
    )
    
    class Meta:
        db_table = 'tareas'
        verbose_name = 'Tarea'
        verbose_name_plural = 'Tareas'
        ordering = ['-fecha', 'turno', 'linea']
        indexes = [
            models.Index(fields=['fecha', 'turno', 'linea']),
            models.Index(fields=['estado']),
            models.Index(fields=['fecha']),
        ]
        unique_together = ['linea', 'turno', 'fecha', 'producto']
    
    def __str__(self):
        return f"{self.fecha} - {self.linea.nombre} - {self.turno.nombre} - {self.producto.codigo}"
    
    def clean(self):
        """Validaciones personalizadas del modelo"""
        super().clean()
        
        if self.supervisor_asignador and self.supervisor_asignador.rol != 'supervisor':
            raise ValidationError({
                'supervisor_asignador': 'El usuario asignador debe tener rol de supervisor'
            })
        
        if self.estado == 'en_curso':
            tareas_en_curso = Tarea.objects.filter(
                linea=self.linea,
                estado='en_curso'
            ).exclude(pk=self.pk)
            
            if tareas_en_curso.exists():
                raise ValidationError({
                    'estado': f'Ya existe una tarea en curso para {self.linea.nombre}'
                })
    
    def iniciar(self):
        """Marca la tarea como en curso"""
        from django.utils import timezone
        
        if self.estado != 'pendiente':
            raise ValidationError('Solo se pueden iniciar tareas pendientes')
        
        if Tarea.objects.filter(linea=self.linea, estado='en_curso').exists():
            raise ValidationError(f'Ya hay una tarea en curso en {self.linea.nombre}')
        
        self.estado = 'en_curso'
        self.fecha_inicio = timezone.now()
        self.save()
    
    def finalizar(self):
        """Marca la tarea como finalizada"""
        from django.utils import timezone
        
        if self.estado != 'en_curso':
            raise ValidationError('Solo se pueden finalizar tareas en curso')
        
        self.estado = 'finalizada'
        self.fecha_finalizacion = timezone.now()
        self.save()
    
    @property
    def esta_en_curso(self):
        """Indica si la tarea está actualmente en curso"""
        return self.estado == 'en_curso'
    
    @property
    def puede_iniciarse(self):
        """Indica si la tarea puede ser iniciada"""
        return self.estado == 'pendiente'
    
    @property
    def duracion_minutos(self):
        """Calcula la duración de la tarea en minutos"""
        if self.fecha_inicio and self.fecha_finalizacion:
            delta = self.fecha_finalizacion - self.fecha_inicio
            return int(delta.total_seconds() / 60)
        return None


# ============================================================================
# MODELO: Tarea Colaborador
# ============================================================================
class TareaColaborador(models.Model):
    """
    Relaciona una tarea con los colaboradores asignados.
    """
    
    tarea = models.ForeignKey(
        Tarea,
        on_delete=models.CASCADE,
        related_name='tarea_colaboradores',
        help_text="Tarea asignada"
    )
    
    colaborador = models.ForeignKey(
        Colaborador,
        on_delete=models.PROTECT,
        related_name='tareas_asignadas',
        help_text="Colaborador asignado a la tarea"
    )
    
    fecha_asignacion = models.DateTimeField(
        auto_now_add=True,
        help_text="Fecha y hora de asignación"
    )
    
    class Meta:
        db_table = 'tareas_colaboradores'
        verbose_name = 'Asignación de Colaborador'
        verbose_name_plural = 'Asignaciones de Colaboradores'
        unique_together = ['tarea', 'colaborador']
        ordering = ['tarea', 'colaborador__codigo']
    
    def __str__(self):
        return f"{self.tarea} - {self.colaborador.nombre_completo}"
    
# ============================================================================
# MODELO: Maquina
# ============================================================================
class Maquina(models.Model):
    """
    Catálogo de máquinas disponibles en la planta.
    Las máquinas pueden moverse entre líneas.
    """
    
    nombre = models.CharField(
        max_length=100,
        help_text="Nombre de la máquina"
    )
    
    codigo = models.CharField(
        max_length=50,
        unique=True,
        help_text="Código único de la máquina"
    )
    
    activa = models.BooleanField(
        default=True,
        help_text="Indica si la máquina está operativa"
    )
    
    class Meta:
        db_table = 'maquinas'
        verbose_name = 'Máquina'
        verbose_name_plural = 'Máquinas'
        ordering = ['nombre']
    
    def __str__(self):
        return f"{self.codigo} - {self.nombre}"
 
# ============================================================================
# MODELO: TipoEvento 
# ============================================================================

class TipoEvento(models.Model):
    """
    Catálogo de tipos de eventos para la hoja de procesos.
    Los 11 tipos predefinidos de eventos.
    """
    
    nombre = models.CharField(
        max_length=50,
        unique=True,
        help_text="Nombre del tipo de evento"
    )
    
    codigo = models.CharField(
        max_length=20,
        unique=True,
        help_text="Código del tipo de evento"
    )
    
    descripcion = models.TextField(
        blank=True,
        null=True,
        help_text="Descripción del tipo de evento"
    )
    
    orden = models.PositiveIntegerField(
        default=0,
        help_text="Orden de visualización"
    )
    
    activo = models.BooleanField(
        default=True,
        help_text="Indica si el tipo de evento está activo"
    )
    
    class Meta:
        db_table = 'tipos_eventos'
        verbose_name = 'Tipo de Evento'
        verbose_name_plural = 'Tipos de Eventos'
        ordering = ['orden', 'nombre']
    
    def __str__(self):
        return self.nombre


# ============================================================================
# MODELO: HojaProcesos
# ============================================================================
class HojaProcesos(models.Model):
    """
    Hoja de procesos que registra todos los eventos de tiempo
    durante la producción de una tarea.
    """
    
    tarea = models.OneToOneField(
        Tarea,
        on_delete=models.CASCADE,
        related_name='hoja_procesos',
        help_text="Tarea asociada a esta hoja de procesos"
    )
    
    fecha_inicio = models.DateTimeField(
        auto_now_add=True,
        help_text="Fecha y hora de inicio de la hoja de procesos"
    )
    
    fecha_finalizacion = models.DateTimeField(
        blank=True,
        null=True,
        help_text="Fecha y hora de finalización de la hoja de procesos"
    )
    
    finalizada = models.BooleanField(
        default=False,
        help_text="Indica si la hoja de procesos está finalizada"
    )
    
    class Meta:
        db_table = 'hojas_procesos'
        verbose_name = 'Hoja de Procesos'
        verbose_name_plural = 'Hojas de Procesos'
        ordering = ['-fecha_inicio']
    
    def __str__(self):
        return f"Hoja Procesos - {self.tarea}"
    
    def finalizar(self):
        """Marca la hoja de procesos como finalizada"""
        from django.utils import timezone
        from django.core.exceptions import ValidationError
        
        if self.finalizada:
            raise ValidationError('Esta hoja de procesos ya está finalizada')
        
        self.finalizada = True
        self.fecha_finalizacion = timezone.now()
        self.save()


# ============================================================================
# MODELO: EventoProceso
# ============================================================================
class EventoProceso(models.Model):
    """
    Registra cada evento individual en la hoja de procesos
    (setup inicial, templado, producción, etc.)
    """
    
    hoja_procesos = models.ForeignKey(
        HojaProcesos,
        on_delete=models.CASCADE,
        related_name='eventos',
        help_text="Hoja de procesos a la que pertenece este evento"
    )
    
    tipo_evento = models.ForeignKey(
        TipoEvento,
        on_delete=models.PROTECT,
        related_name='eventos',
        help_text="Tipo de evento"
    )
    
    hora_inicio = models.DateTimeField(
        help_text="Hora de inicio del evento"
    )
    
    hora_fin = models.DateTimeField(
        blank=True,
        null=True,
        help_text="Hora de fin del evento"
    )
    
    observaciones = models.TextField(
        blank=True,
        null=True,
        max_length=500,
        help_text="Observaciones sobre este evento"
    )
    
    class Meta:
        db_table = 'eventos_procesos'
        verbose_name = 'Evento de Proceso'
        verbose_name_plural = 'Eventos de Procesos'
        ordering = ['hora_inicio']
    
    def __str__(self):
        return f"{self.tipo_evento.nombre} - {self.hora_inicio.strftime('%H:%M')}"
    
    @property
    def duracion_minutos(self):
        """Calcula la duración del evento en minutos"""
        if self.hora_inicio and self.hora_fin:
            delta = self.hora_fin - self.hora_inicio
            return int(delta.total_seconds() / 60)
        return None


# ============================================================================
# MODELO: EventoMaquina
# ============================================================================
class EventoMaquina(models.Model):
    """
    Relación many-to-many entre EventoProceso y Maquina.
    Registra qué máquinas se usaron en cada evento.
    """
    
    evento = models.ForeignKey(
        EventoProceso,
        on_delete=models.CASCADE,
        related_name='evento_maquinas',
        help_text="Evento de proceso"
    )
    
    maquina = models.ForeignKey(
        Maquina,
        on_delete=models.PROTECT,
        related_name='eventos',
        help_text="Máquina utilizada"
    )
    
    class Meta:
        db_table = 'eventos_maquinas'
        verbose_name = 'Máquina en Evento'
        verbose_name_plural = 'Máquinas en Eventos'
        unique_together = ['evento', 'maquina']
    
    def __str__(self):
        return f"{self.evento} - {self.maquina.nombre}"


# ============================================================================
# MODELO: Trazabilidad
# ============================================================================
class Trazabilidad(models.Model):
    """
    Trazabilidad de producción. Se crea después de finalizar
    la hoja de procesos.
    """
    
    ESTADOS = [
        ('en_revision', 'En Revisión'),
        ('liberado', 'Liberado'),
        ('retenido', 'Retenido'),
    ]
    
    hoja_procesos = models.OneToOneField(
        HojaProcesos,
        on_delete=models.CASCADE,
        related_name='trazabilidad',
        help_text="Hoja de procesos asociada"
    )
    
    cantidad_producida = models.PositiveIntegerField(
        help_text="Cantidad producida en unidades"
    )

    foto_etiquetas = models.ImageField(
        upload_to='trazabilidad/etiquetas/%Y/%m/%d/',
        verbose_name='Foto de Etiquetas',
        null=True,
        blank=True,
        validators=[validate_image_file],
        help_text='Foto de las etiquetas utilizadas en la producción'
    )
    juliano = models.PositiveIntegerField(
        verbose_name='Día Juliano',
        help_text='Día juliano del año (1-366). Se calcula automáticamente desde fecha_creacion',
        editable=False,
    )
    lote = models.CharField(
        max_length=50,
        verbose_name='Lote',
        help_text='Lote de producción en formato: CÓDIGO_PRODUCTO-JULIANO-CÓDIGO_COLABORADOR. Ejemplo: 410-342-96',
    )
    
    estado = models.CharField(
        max_length=20,
        choices=ESTADOS,
        default='en_revision',
        help_text="Estado de la trazabilidad"
    )
    
    motivo_retencion = models.TextField(
        blank=True,
        null=True,
        max_length=500,
        help_text="Motivo de retención (obligatorio si estado es 'retenido')"
    )
    
    observaciones = models.TextField(
        blank=True,
        null=True,
        max_length=500,
        help_text="Observaciones generales"
    )
    
    fecha_creacion = models.DateTimeField(
        auto_now_add=True,
        help_text="Fecha y hora de creación de la trazabilidad"
    )
    
    class Meta:
        db_table = 'trazabilidades'
        verbose_name = 'Trazabilidad'
        verbose_name_plural = 'Trazabilidades'
        ordering = ['-fecha_creacion']
    
    def __str__(self):
        return f"Trazabilidad {self.lote} - {self.hoja_procesos.tarea}"
    
    def clean(self):
        """Validaciones personalizadas"""
        super().clean()

        if not self.lote:
            raise ValidationError({
                'lote': 'El lote es obligatorio'
            })

        partes = self.lote.split('-') 
        if len(partes) != 3:
            raise ValidationError({
                'lote': 'El lote debe tener formato: CÓDIGO_PRODUCTO-JULIANO-CÓDIGO_COLABORADOR (ej: 410-342-96)'
            })
        
        if self.estado == 'retenido' and not self.motivo_retencion:
            raise ValidationError({
                'motivo_retencion': 'El motivo de retención es obligatorio cuando el estado es "Retenido"'
            })
        
    # Calcular el día juliano
    @staticmethod
    def calcular_juliano(fecha):
        """
        Calcula el día juliano del año para una fecha dada.
        
        Args:
            fecha: objeto datetime o date
            
        Returns:
            int: Día juliano (1-366)
            
        Ejemplo:
            >>> Trazabilidad.calcular_juliano(datetime(8, 12, 2025))
            342
        """
        return fecha.timetuple().tm_yday
    
    def generar_lote(self, codigo_colaborador):
        """
        Genera el código de lote en formato: CÓDIGO_PRODUCTO-JULIANO-CÓDIGO_COLABORADOR
        
        Args:
            codigo_colaborador: código del colaborador a cargo (str o int)
            
        Returns:
            str: Lote generado. Ejemplo: "410-342-96"
        """
        producto_codigo = self.hoja_procesos.tarea.producto.codigo
        juliano = self.juliano
        return f"{producto_codigo}-{juliano}-{codigo_colaborador}"
    
    @property
    def producto_nombre(self):
        """Nombre del producto producido"""
        return self.hoja_procesos.tarea.producto.nombre
    
    @property
    def linea_nombre(self):
        """Nombre de la línea donde se produjo"""
        return self.hoja_procesos.tarea.linea.nombre
    
    @property
    def tiene_firmas_completas(self):
        """Verifica si tiene ambas firmas requeridas"""
        return (
            self.firmas.filter(tipo_firma='supervisor').exists() and
            self.firmas.filter(tipo_firma='control_calidad').exists()
        )

# ============================================================================
# MODELO: TrazabilidadMateriaPrima
# ============================================================================
class TrazabilidadMateriaPrima(models.Model):
    """
    Registra los lotes y cantidades de materias primas usadas
    en la producción.
    """
    
    UNIDADES_MEDIDA = [
        ('kg', 'Kilogramos'),
        ('unidades', 'Unidades'),
    ]
    
    trazabilidad = models.ForeignKey(
        Trazabilidad,
        on_delete=models.CASCADE,
        related_name='materias_primas_usadas',
        help_text="Trazabilidad a la que pertenece"
    )
    
    materia_prima = models.ForeignKey(
        MateriaPrima,
        on_delete=models.PROTECT,
        related_name='trazabilidades',
        help_text="Materia prima utilizada"
    )
    
    lote = models.CharField(
        max_length=100,
        blank=True,
        null=True,
        help_text="Lote de la materia prima (puede ser null si no requiere lote)"
    )
    
    cantidad_usada = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        help_text="Cantidad de materia prima usada"
    )
    
    unidad_medida = models.CharField(
        max_length=20,
        choices=UNIDADES_MEDIDA,
        blank=True,
        help_text="Unidad de medida de la cantidad"
    )
    
    class Meta:
        db_table = 'trazabilidad_materias_primas'
        verbose_name = 'Materia Prima Usada'
        verbose_name_plural = 'Materias Primas Usadas'
        unique_together = ['trazabilidad', 'materia_prima']
        ordering = ['materia_prima__codigo']
    
    def __str__(self):
        return f"{self.materia_prima.nombre} - {self.cantidad_usada} {self.get_unidad_medida_display()}"
    
    def get_unidad_display(self, udm):
        """Helper para mostrar unidad correcta"""
        return dict(self.UNIDADES_MEDIDA).get(udm, udm)
    
    def save(self, *args, **kwargs):
        """
        Al guardar, si no se especificó unidad_medida, 
        tomar la unidad_medida de la materia prima
        """
        if not self.unidad_medida:
            self.unidad_medida = self.materia_prima.unidad_medida
        
        super().save(*args, **kwargs)
    
    def clean(self):
        """Validaciones personalizadas"""
        super().clean()
        
        # Si la materia prima requiere lote, el lote es obligatorio
        if self.materia_prima.requiere_lote and not self.lote:
            raise ValidationError({
                'lote': f'La materia prima "{self.materia_prima.nombre}" requiere lote'
            })


# ============================================================================
# MODELO: Reproceso
# ============================================================================
class Reproceso(models.Model):
    CAUSAS_CHOICES = [
        ('escasez_de_banado', 'Escasez de Bañado'),
        ('poca_vida_util', 'Poca Vida Útil'),
        ('deformacion', 'Deformación'),
        ('peso_erroneo', 'Peso Erróneo'),
        ('mal_templado', 'Mal Templado'),
        ('otro', 'Otro (especificar)'),
    ]
    
    trazabilidad_materia_prima = models.ForeignKey(
        'TrazabilidadMateriaPrima', 
        on_delete=models.CASCADE,
        related_name='reprocesos',
        help_text="Materia prima específica que tuvo reproceso"
    )
    
    cantidad = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        help_text="Cantidad de de reproceso"
    )

    causas = models.CharField(
        max_length=200, 
        choices=CAUSAS_CHOICES, 
        null=True)
    
    class Meta:
        db_table = 'reprocesos'
        verbose_name = 'Reproceso'
        verbose_name_plural = 'Reprocesos'
        ordering = ['id']
    
    def __str__(self):
        mp_nombre = self.trazabilidad_materia_prima.materia_prima.nombre
        udm = self.trazabilidad_materia_prima.unidad_medida
        causa_display = self.get_causas_display()
        return f"Reproceso - {mp_nombre}: {self.cantidad} {udm} - {causa_display}"


# ============================================================================
# MODELO: Merma
# ============================================================================
class Merma(models.Model):
    """
    Registra las mermas ocurridas durante la producción.
    """
    CAUSAS_CHOICES = [
        ('cayo_al_suelo', 'Cayó al Suelo'),
        ('por_hongos', 'Por Hongos'),
        ('caducidad', 'Caducidad'),
        ('grasa_maquina', 'Grasa Máquina'),
        ('exposicion', 'Exposición'),
        ('otro', 'Otro (especificar)'),
    ]
    
    trazabilidad_materia_prima = models.ForeignKey(
        'TrazabilidadMateriaPrima',
        on_delete=models.CASCADE,
        related_name='mermas',
        help_text="Materia prima específica que tuvo merma"
    )
    
    cantidad = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        help_text="Cantidad de merma"
    )
    
    causas = models.CharField(
        max_length=200, 
        choices=CAUSAS_CHOICES, 
        null=True)
    
    class Meta:
        db_table = 'mermas'
        verbose_name = 'Merma'
        verbose_name_plural = 'Mermas'
        ordering = ['id']
    
    def __str__(self):
        mp_nombre = self.trazabilidad_materia_prima.materia_prima.nombre
        udm = self.trazabilidad_materia_prima.unidad_medida
        causa_display = self.get_causas_display()
        return f"Merma - {mp_nombre}: {self.cantidad} {udm} - {causa_display}"

    # ============================================================================
# MODELO: FotoEtiqueta
# ============================================================================
class FotoEtiqueta(models.Model):
    """
    Almacena la foto de las etiquetas usadas en la producción.
    """
    
    trazabilidad = models.OneToOneField(
        Trazabilidad,
        on_delete=models.CASCADE,
        related_name='foto_etiqueta',
        help_text="Trazabilidad a la que pertenece"
    )
    
    foto = models.ImageField(
        upload_to='etiquetas/%Y/%m/%d/',
        help_text="Foto de las etiquetas"
    )
    
    fecha_subida = models.DateTimeField(
        auto_now_add=True,
        help_text="Fecha y hora de subida de la foto"
    )
    
    class Meta:
        db_table = 'fotos_etiquetas'
        verbose_name = 'Foto de Etiqueta'
        verbose_name_plural = 'Fotos de Etiquetas'
    
    def __str__(self):
        return f"Foto Etiqueta - {self.trazabilidad}"


# ============================================================================
# MODELO: FirmaTrazabilidad
# ============================================================================
class FirmaTrazabilidad(models.Model):
    """
    Registra las firmas digitales de supervisor y control de calidad.
    """
    
    TIPOS_FIRMA = [
        ('supervisor', 'Supervisor'),
        ('control_calidad', 'Control de Calidad'),
    ]
    
    trazabilidad = models.ForeignKey(
        Trazabilidad,
        on_delete=models.CASCADE,
        related_name='firmas',
        help_text="Trazabilidad a la que pertenece"
    )
    
    tipo_firma = models.CharField(
        max_length=20,
        choices=TIPOS_FIRMA,
        help_text="Tipo de firma"
    )
    
    usuario = models.ForeignKey(
        Usuario,
        on_delete=models.PROTECT,
        related_name='firmas_trazabilidad',
        help_text="Usuario que firmó"
    )
    
    fecha_firma = models.DateTimeField(
        auto_now_add=True,
        help_text="Fecha y hora de la firma"
    )
    
    class Meta:
        db_table = 'firmas_trazabilidad'
        verbose_name = 'Firma de Trazabilidad'
        verbose_name_plural = 'Firmas de Trazabilidad'
        unique_together = ['trazabilidad', 'tipo_firma']
        ordering = ['fecha_firma']
    
    def __str__(self):
        return f"{self.get_tipo_firma_display()} - {self.usuario.username}"
    
    def clean(self):
        """Validaciones personalizadas"""
        super().clean()
        
        # Validar que el usuario tenga el rol correcto
        if self.tipo_firma == 'supervisor' and self.usuario.rol != 'supervisor':
            raise ValidationError({
                'usuario': 'El usuario debe tener rol de supervisor para firmar como supervisor'
            })
        
        if self.tipo_firma == 'control_calidad' and self.usuario.rol != 'control_calidad':
            raise ValidationError({
                'usuario': 'El usuario debe tener rol de control de calidad para firmar como control de calidad'
            })
        
# ============================================================================
# MODELO: TrazabilidadColaborador
# ============================================================================

class TrazabilidadColaborador(models.Model):
    """
    Registra los colaboradores que REALMENTE trabajaron en la producción.
    
    Puede diferir de los colaboradores asignados originalmente en la Tarea,
    ya que operativamente pueden cambiar (ausencias, reemplazos, etc.)
    """
    trazabilidad = models.ForeignKey(
        'Trazabilidad',
        on_delete=models.CASCADE,
        related_name='colaboradores_reales',
        help_text='Trazabilidad a la que pertenece'
    )
    
    colaborador = models.ForeignKey(
        'Colaborador',
        on_delete=models.PROTECT,  # No permitir eliminar colaborador si está en trazabilidad
        help_text='Colaborador que trabajó en la producción'
    )
    
    fecha_asignacion = models.DateTimeField(
        auto_now_add=True,
        help_text='Cuándo se registró este colaborador en la trazabilidad'
    )
    
    class Meta:
        db_table = 'trazabilidad_colaborador'
        verbose_name = 'Colaborador en Trazabilidad'
        verbose_name_plural = 'Colaboradores en Trazabilidad'
        unique_together = ['trazabilidad', 'colaborador']  # No duplicar colaborador en misma trazabilidad
        ordering = ['fecha_asignacion']
    
    def __str__(self):
        return f"{self.colaborador.nombre} - Trazabilidad #{self.trazabilidad.id}"