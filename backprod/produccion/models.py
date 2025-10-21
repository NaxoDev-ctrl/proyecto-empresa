#from django.db import models

# Create your models here.

from django.db import models
from django.contrib.auth.models import AbstractUser
from django.core.validators import MinValueValidator
from django.core.exceptions import ValidationError
from datetime import date


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
    
    codigo = models.CharField(
        max_length=20,
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
    
    codigo = models.CharField(
        max_length=20,
        unique=True,
        help_text="Código de la materia prima. Ejemplo: LAC0001"
    )
    
    nombre = models.CharField(
        max_length=200,
        help_text="Nombre de la materia prima. Ejemplo: manjar"
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