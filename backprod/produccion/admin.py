# Register your models here.

from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from django.utils.html import format_html
from .models import (
    Usuario, Linea, Turno, Colaborador, 
    Producto, MateriaPrima, Receta, 
    Tarea, TareaColaborador, Maquina, TipoEvento,
    HojaProcesos, EventoProceso, EventoMaquina,
    Trazabilidad, TrazabilidadMateriaPrima,
    Reproceso, Merma, FirmaTrazabilidad, TrazabilidadColaborador
)


# ============================================================================
# ADMIN: Usuario
# ============================================================================
@admin.register(Usuario)
class UsuarioAdmin(BaseUserAdmin):
    """
    Configuración del admin para el modelo Usuario.
    Extiende UserAdmin de Django para agregar campos personalizados.
    """
    
    # Campos a mostrar en la lista
    list_display = ['username', 'first_name', 'last_name', 'rol', 'activo', 'fecha_creacion']
    list_filter = ['rol', 'activo', 'fecha_creacion']
    search_fields = ['username', 'first_name', 'last_name', 'email']
    
    # Campos editables en el formulario
    fieldsets = BaseUserAdmin.fieldsets + (
        ('Información Adicional', {
            'fields': ('rol', 'activo')
        }),
    )
    
    # Campos para crear nuevo usuario
    add_fieldsets = BaseUserAdmin.add_fieldsets + (
        ('Información Adicional', {
            'fields': ('first_name', 'last_name', 'email', 'rol', 'activo')
        }),
    )
    
    ordering = ['username']


# ============================================================================
# ADMIN: Línea
# ============================================================================
@admin.register(Linea)
class LineaAdmin(admin.ModelAdmin):
    """
    Configuración del admin para Líneas de Producción.
    """
    
    list_display = ['nombre', 'activa', 'fecha_creacion']
    list_filter = ['activa']
    search_fields = ['nombre', 'descripcion']
    ordering = ['nombre']
    
    fieldsets = (
        ('Información Básica', {
            'fields': ('nombre', 'activa')
        }),
        ('Descripción', {
            'fields': ('descripcion',),
            'classes': ('collapse',)
        }),
    )


# ============================================================================
# ADMIN: Turno
# ============================================================================
@admin.register(Turno)
class TurnoAdmin(admin.ModelAdmin):
    """
    Configuración del admin para Turnos.
    """
    
    list_display = ['nombre', 'hora_inicio', 'hora_fin', 'activo']
    list_filter = ['activo']
    ordering = ['hora_inicio']
    
    fieldsets = (
        ('Información del Turno', {
            'fields': ('nombre', 'hora_inicio', 'hora_fin', 'activo')
        }),
    )


# ============================================================================
# ADMIN: Colaborador
# ============================================================================
@admin.register(Colaborador)
class ColaboradorAdmin(admin.ModelAdmin):
    """
    Configuración del admin para Colaboradores.
    """
    
    list_display = ['codigo', 'nombre', 'apellido', 'activo', 'fecha_carga']
    list_filter = ['activo', 'fecha_carga']
    search_fields = ['codigo', 'nombre', 'apellido']
    ordering = ['codigo']
    
    fieldsets = (
        ('Información del Colaborador', {
            'fields': ('codigo', 'nombre', 'apellido', 'activo')
        }),
    )
    
    readonly_fields = ['fecha_carga', 'fecha_actualizacion']


# ============================================================================
# ADMIN: Producto
# ============================================================================
@admin.register(Producto)
class ProductoAdmin(admin.ModelAdmin):
    """
    Configuración del admin para Productos.
    """
    
    list_display = ['codigo', 'nombre', 'unidad_medida', 'activo']
    list_filter = ['activo']
    search_fields = ['codigo', 'nombre', 'unidad_medida', 'descripcion']
    ordering = ['codigo']
    
    fieldsets = (
        ('Información del Producto', {
            'fields': ('codigo', 'nombre', 'unidad_medida', 'activo')
        }),
        ('Descripción', {
            'fields': ('descripcion',),
            'classes': ('collapse',)
        }),
    )


# ============================================================================
# ADMIN: Materia Prima
# ============================================================================
@admin.register(MateriaPrima)
class MateriaPrimaAdmin(admin.ModelAdmin):
    """
    Configuración del admin para Materias Primas.
    """
    
    list_display = ['codigo', 'nombre', 'unidad_medida', 'requiere_lote', 'activo']
    list_filter = ['requiere_lote', 'activo', 'unidad_medida']
    search_fields = ['codigo', 'nombre']
    ordering = ['codigo']
    
    fieldsets = (
        ('Información de Materia Prima', {
            'fields': ('codigo', 'nombre', 'unidad_medida', 'requiere_lote', 'activo')
        }),
    )


# ============================================================================
# ADMIN: Receta (Inline para Producto)
# ============================================================================
class RecetaInline(admin.TabularInline):
    """
    Permite editar las materias primas de un producto
    directamente desde la pantalla de edición del producto.
    """
    model = Receta
    extra = 1
    fields = ['materia_prima', 'orden', 'activo']
    ordering = ['orden']


# Actualizar ProductoAdmin para incluir el inline
ProductoAdmin.inlines = [RecetaInline]


# ============================================================================
# ADMIN: Receta (vista independiente)
# ============================================================================
@admin.register(Receta)
class RecetaAdmin(admin.ModelAdmin):
    """
    Configuración del admin para Recetas.
    """
    
    list_display = ['producto', 'materia_prima', 'orden', 'activo']
    list_filter = ['activo', 'producto']
    search_fields = ['producto__nombre', 'materia_prima__nombre']
    ordering = ['producto', 'orden']
    
    fieldsets = (
        ('Información de Receta', {
            'fields': ('producto', 'materia_prima', 'orden', 'activo')
        }),
    )


# ============================================================================
# ADMIN: Tarea Colaborador (Inline para Tarea)
# ============================================================================
class TareaColaboradorInline(admin.TabularInline):
    """
    Permite asignar colaboradores a una tarea
    directamente desde la pantalla de edición de la tarea.
    """
    model = TareaColaborador
    extra = 1
    fields = ['colaborador']
    autocomplete_fields = ['colaborador']


# ============================================================================
# ADMIN: Tarea
# ============================================================================
@admin.register(Tarea)
class TareaAdmin(admin.ModelAdmin):
    """
    Configuración del admin para Tareas.
    """
    
    list_display = [
        'fecha', 
        'linea', 
        'turno', 
        'producto', 
        'meta_produccion', 
        'estado_badge',
        'supervisor_asignador'
    ]
    
    list_filter = ['estado', 'fecha', 'turno', 'linea']
    search_fields = ['producto__nombre', 'producto__codigo', 'observaciones']
    ordering = ['-fecha', 'turno', 'linea']
    
    autocomplete_fields = ['producto', 'supervisor_asignador']
    
    fieldsets = (
        ('Información de la Tarea', {
            'fields': ('linea', 'producto', 'turno', 'fecha', 'meta_produccion')
        }),
        ('Asignación', {
            'fields': ('supervisor_asignador',)
        }),
        ('Detalles', {
            'fields': ('observaciones', 'estado')
        }),
        ('Auditoría', {
            'fields': ('fecha_creacion', 'fecha_inicio', 'fecha_finalizacion'),
            'classes': ('collapse',)
        }),
    )
    
    readonly_fields = ['fecha_creacion', 'fecha_inicio', 'fecha_finalizacion']
    
    inlines = [TareaColaboradorInline]
    
    def estado_badge(self, obj):
        """Muestra el estado con color"""
        colors = {
            'pendiente': '#ffc107',  # amarillo
            'en_curso': '#17a2b8',   # azul
            'finalizada': '#28a745'  # verde
        }
        color = colors.get(obj.estado, '#6c757d')
        return format_html(
            '<span style="background-color: {}; color: white; padding: 3px 10px; border-radius: 3px;">{}</span>',
            color,
            obj.get_estado_display()
        )
    
    estado_badge.short_description = 'Estado'
    
    def get_readonly_fields(self, request, obj=None):
        """
        Si la tarea ya está en curso o finalizada,
        no permitir cambiar campos críticos.
        """
        readonly = list(self.readonly_fields)
        
        if obj and obj.estado in ['en_curso', 'finalizada']:
            readonly.extend(['linea', 'producto', 'turno', 'fecha'])
        
        return readonly


# ============================================================================
# ADMIN: TareaColaborador (vista independiente)
# ============================================================================
@admin.register(TareaColaborador)
class TareaColaboradorAdmin(admin.ModelAdmin):
    """
    Configuración del admin para Asignaciones de Colaboradores.
    """
    
    list_display = ['tarea', 'colaborador', 'fecha_asignacion']
    list_filter = ['fecha_asignacion']
    search_fields = [
        'tarea__producto__nombre', 
        'colaborador__nombre', 
        'colaborador__apellido',
        'colaborador__codigo'
    ]
    ordering = ['-fecha_asignacion']
    
    readonly_fields = ['fecha_asignacion']


# ============================================================================
# Personalización del Admin Site
# ============================================================================
admin.site.site_header = "Chocolatería Entrelagos - Administración"
admin.site.site_title = "Admin Entrelagos"
admin.site.index_title = "Panel de Administración"

# ============================================================================
# ADMIN: Maquina
# ============================================================================
@admin.register(Maquina)
class MaquinaAdmin(admin.ModelAdmin):
    """
    Configuración del admin para Máquinas.
    """
    
    list_display = ['codigo', 'nombre', 'activa']
    list_filter = ['activa']
    search_fields = ['codigo', 'nombre']
    ordering = ['nombre']
    
    fieldsets = (
        ('Información de la Máquina', {
            'fields': ('codigo', 'nombre', 'activa')
        }),
    )


# ============================================================================
# ADMIN: TipoEvento
# ============================================================================
@admin.register(TipoEvento)
class TipoEventoAdmin(admin.ModelAdmin):
    """
    Configuración del admin para Tipos de Eventos.
    """
    
    list_display = ['orden', 'nombre', 'codigo', 'activo']
    list_filter = ['activo']
    search_fields = ['nombre', 'codigo']
    ordering = ['orden']
    
    fieldsets = (
        ('Información del Tipo de Evento', {
            'fields': ('nombre', 'codigo', 'orden', 'activo')
        }),
        ('Descripción', {
            'fields': ('descripcion',),
            'classes': ('collapse',)
        }),
    )


# ============================================================================
# ADMIN: EventoMaquina (Inline para EventoProceso)
# ============================================================================
class EventoMaquinaInline(admin.TabularInline):
    """
    Permite asignar máquinas a un evento de proceso.
    """
    model = EventoMaquina
    extra = 1
    fields = ['maquina']


# ============================================================================
# ADMIN: EventoProceso (Inline para HojaProcesos)
# ============================================================================
class EventoProcesoInline(admin.TabularInline):
    """
    Permite ver y editar eventos desde la hoja de procesos.
    """
    model = EventoProceso
    extra = 0
    fields = ['tipo_evento', 'hora_inicio', 'hora_fin', 'observaciones']
    readonly_fields = ['hora_inicio']


# ============================================================================
# ADMIN: HojaProcesos
# ============================================================================
@admin.register(HojaProcesos)
class HojaProcesosAdmin(admin.ModelAdmin):
    """
    Configuración del admin para Hojas de Procesos.
    """
    
    list_display = ['tarea', 'fecha_inicio', 'fecha_finalizacion', 'finalizada']
    list_filter = ['finalizada', 'fecha_inicio']
    search_fields = ['tarea__producto__nombre', 'tarea__linea__nombre']
    ordering = ['-fecha_inicio']
    
    fieldsets = (
        ('Información de la Hoja de Procesos', {
            'fields': ('tarea', 'finalizada')
        }),
        ('Fechas', {
            'fields': ('fecha_inicio', 'fecha_finalizacion'),
            'classes': ('collapse',)
        }),
    )
    
    readonly_fields = ['fecha_inicio', 'fecha_finalizacion']
    inlines = [EventoProcesoInline]
    
    def get_readonly_fields(self, request, obj=None):
        """Si está finalizada, no permitir editar"""
        readonly = list(self.readonly_fields)
        if obj and obj.finalizada:
            readonly.extend(['tarea', 'finalizada'])
        return readonly


# ============================================================================
# ADMIN: EventoProceso
# ============================================================================
@admin.register(EventoProceso)
class EventoProcesoAdmin(admin.ModelAdmin):
    """
    Configuración del admin para Eventos de Procesos.
    """
    
    list_display = ['hoja_procesos', 'tipo_evento', 'hora_inicio', 'hora_fin', 'duracion_minutos']
    list_filter = ['tipo_evento', 'hora_inicio']
    search_fields = ['hoja_procesos__tarea__producto__nombre']
    ordering = ['-hora_inicio']
    
    fieldsets = (
        ('Información del Evento', {
            'fields': ('hoja_procesos', 'tipo_evento', 'hora_inicio', 'hora_fin')
        }),
        ('Observaciones', {
            'fields': ('observaciones',),
            'classes': ('collapse',)
        }),
    )
    
    readonly_fields = ['duracion_minutos']
    inlines = [EventoMaquinaInline]
    
    def duracion_minutos(self, obj):
        """Muestra la duración del evento"""
        return obj.duracion_minutos
    
    duracion_minutos.short_description = 'Duración (minutos)'


# ============================================================================
# ADMIN: Reproceso (Inline para Trazabilidad)
# ============================================================================
class ReprocesoInline(admin.TabularInline):
    model = Reproceso
    extra = 1
    fields = ['cantidad', 'causas']

# ============================================================================
# ADMIN: Merma (Inline para Trazabilidad)
# ============================================================================
class MermaInline(admin.TabularInline):
    model = Merma
    extra = 1
    fields = ['cantidad', 'causas']
    


# ============================================================================
# ADMIN: FirmaTrazabilidad (Inline para Trazabilidad)
# ============================================================================
class FirmaTrazabilidadInline(admin.TabularInline):
    """
    Permite ver las firmas desde la trazabilidad.
    """
    model = FirmaTrazabilidad
    extra = 0
    fields = ['tipo_firma', 'usuario', 'fecha_firma']
    readonly_fields = ['fecha_firma']


# ============================================================================
# Inline para mostrar colaboradores dentro de Trazabilidad
# ============================================================================
class TrazabilidadColaboradorInline(admin.TabularInline):
    """
    Muestra los colaboradores dentro del formulario de Trazabilidad
    """
    model = TrazabilidadColaborador
    extra = 1  # Líneas vacías para agregar nuevos
    autocomplete_fields = ['colaborador']  # Búsqueda inteligente
    fields = ['colaborador', 'fecha_asignacion']
    readonly_fields = ['fecha_asignacion']

    verbose_name = 'Colaborador que trabajó'
    verbose_name_plural = '👥 Colaboradores que REALMENTE trabajaron'

    def get_queryset(self, request):
        """Optimizar query"""
        qs = super().get_queryset(request)
        return qs.select_related('colaborador')


# ============================================================================
# ADMIN: FirmaTrazabilidad
# ============================================================================
@admin.register(FirmaTrazabilidad)
class FirmaTrazabilidadAdmin(admin.ModelAdmin):
    """
    Configuración del admin para Firmas de Trazabilidad.
    """
    
    list_display = ['trazabilidad', 'tipo_firma', 'usuario', 'fecha_firma']
    list_filter = ['tipo_firma', 'fecha_firma']
    search_fields = [
        'trazabilidad__hoja_procesos__tarea__producto__nombre',
        'usuario__username'
    ]
    ordering = ['-fecha_firma']
    
    readonly_fields = ['fecha_firma']


# ============================================================================
# ADMIN: TrazabilidadMateriaPrima
# ============================================================================
@admin.register(TrazabilidadMateriaPrima)
class TrazabilidadMateriaPrimaAdmin(admin.ModelAdmin):
    list_display = [
        'id',
        'trazabilidad',
        'materia_prima',
        'lote',
        'cantidad_usada',
        'unidad_medida',
        'get_reprocesos_info',
        'get_mermas_info',
    ]
    list_filter = ['trazabilidad', 'materia_prima']
    search_fields = ['materia_prima__nombre', 'lote']
    inlines = [ReprocesoInline, MermaInline]
    
    def get_reprocesos_info(self, obj):
        count = obj.reprocesos.count()
        if count > 0:
            total = sum(r.cantidad for r in obj.reprocesos.all())
            return format_html(
                '<span style="color: orange; font-weight: bold;">♻️ {} reprocesos ({} {})</span>',
                count,
                total,
                obj.unidad_medida
            )
        return '-'
    get_reprocesos_info.short_description = 'Reprocesos'
    
    def get_mermas_info(self, obj):
        count = obj.mermas.count()
        if count > 0:
            total = sum(m.cantidad for m in obj.mermas.all())
            return format_html(
                '<span style="color: red; font-weight: bold;">🗑️ {} mermas ({} {})</span>',
                count,
                total,
                obj.unidad_medida
            )
        return '-'
    get_mermas_info.short_description = 'Mermas'

# ============================================================================
# ADMIN: Reproceso
# ============================================================================
@admin.register(Reproceso)
class ReprocesoAdmin(admin.ModelAdmin):
    list_display = [
        'id',
        'get_trazabilidad',
        'get_materia_prima',
        'cantidad',
        'get_causas_legible',
    ]
    list_filter = [
        'trazabilidad_materia_prima__trazabilidad',
        'causas',
    ]
    search_fields = [
        'trazabilidad_materia_prima__materia_prima__nombre',
    ]
    fields = ['trazabilidad_materia_prima', 'cantidad', 'causas']
    
    def get_trazabilidad(self, obj):
        return f"Trazabilidad #{obj.trazabilidad_materia_prima.trazabilidad.id}"
    get_trazabilidad.short_description = 'Trazabilidad'
    
    def get_materia_prima(self, obj):
        return obj.trazabilidad_materia_prima.materia_prima.nombre
    get_materia_prima.short_description = 'Materia Prima'
    
    def get_causas_legible(self, obj):
        if obj.causas:
            if obj.causas.startswith('otro:'):
                return f"Otro: {obj.causas.split(':', 1)[1]}"
            return obj.get_causas_display()
        return '-'
    get_causas_legible.short_description = 'Causa'


# ============================================================================
# ADMIN: Merma (VISTA INDEPENDIENTE - MODIFICADO)
# ============================================================================
@admin.register(Merma)
class MermaAdmin(admin.ModelAdmin):
    list_display = [
        'id',
        'get_trazabilidad',
        'get_materia_prima',
        'cantidad',
        'get_causas_legible',
    ]
    list_filter = [
        'trazabilidad_materia_prima__trazabilidad',
        'causas',
    ]
    search_fields = [
        'trazabilidad_materia_prima__materia_prima__nombre',
    ]
    fields = ['trazabilidad_materia_prima', 'cantidad', 'causas']
    
    def get_trazabilidad(self, obj):
        return f"Trazabilidad #{obj.trazabilidad_materia_prima.trazabilidad.id}"
    get_trazabilidad.short_description = 'Trazabilidad'
    
    def get_materia_prima(self, obj):
        return obj.trazabilidad_materia_prima.materia_prima.nombre
    get_materia_prima.short_description = 'Materia Prima'
    
    def get_causas_legible(self, obj):
        if obj.causas:
            if obj.causas.startswith('otro:'):
                return f"Otro: {obj.causas.split(':', 1)[1]}"
            return obj.get_causas_display()
        return '-'
    get_causas_legible.short_description = 'Causa'

# ============================================================================
# ADMIN: TrazabilidadMateriaPrima (Inline para Trazabilidad)
# ============================================================================
class TrazabilidadMateriaPrimaInline(admin.TabularInline):
    model = TrazabilidadMateriaPrima
    extra = 1
    fields = [
        'materia_prima', 
        'lote', 
        'cantidad_usada', 
        'unidad_medida'
    ]
    inlines = [ReprocesoInline, MermaInline]
    

# ============================================================================
# ADMIN: Trazabilidad
# ============================================================================
@admin.register(Trazabilidad)
class TrazabilidadAdmin(admin.ModelAdmin):
    """
    Configuración del admin para Trazabilidades.
    """
    
    list_display = [
        'id',
        'hoja_procesos',
        'lote',
        'cantidad_producida', 
        'get_colaboradores_reales',
        'estado_badge', 
        'tiene_foto_etiquetas',
        'fecha_creacion',
        'tiene_firmas'
    ]
    list_filter = ['estado', 'fecha_creacion']
    search_fields = [
        'lote',
        'hoja_procesos__tarea__producto__nombre',
        'hoja_procesos__tarea__linea__nombre'
    ]
    ordering = ['-fecha_creacion']
    
    fieldsets = (
        ('Información de la Trazabilidad', {
            'fields': ('hoja_procesos', 'cantidad_producida', 'lote', 'juliano', 'estado')
        }),
        ('Retención', {
            'fields': ('motivo_retencion',),
            'classes': ('collapse',)
        }),
        ('Foto de Etiquetas', {
            'fields': ('foto_etiquetas', 'preview_foto_etiquetas')
        }),
        ('Observaciones', {
            'fields': ('observaciones',),
            'classes': ('collapse',)
        }),
    )
    
    readonly_fields = ['fecha_creacion', 'preview_foto_etiquetas', 'juliano', 'lote']
    inlines = [
        TrazabilidadMateriaPrimaInline,
        TrazabilidadColaboradorInline,
        FirmaTrazabilidadInline
    ]
    

    def get_colaboradores_reales(self, obj):
        """Mostrar colaboradores que trabajaron"""
        count = obj.colaboradores_reales.count()
        
        if count == 0:
            return "Ninguno"
        
        colaboradores = obj.colaboradores_reales.select_related('colaborador')[:3]
        nombres = [str(tc.colaborador.codigo) for tc in colaboradores]
        result = ", ".join(nombres)
        
        if count > 3:
            result += f" (+{count - 3} más)"
        
        return f"✓ {count} → {result}"
    
    get_colaboradores_reales.short_description = 'Colaboradores'

    def estado_badge(self, obj):
        """Muestra el estado con color"""
        colors = {
            'en_revision': '#ffc107',
            'liberado': '#28a745',
            'retenido': '#dc3545'
        }
        color = colors.get(obj.estado, '#6c757d')
        return format_html(
            '<span style="background-color: {}; color: white; padding: 3px 10px; border-radius: 3px;">{}</span>',
            color,
            obj.get_estado_display()
        )
    
    estado_badge.short_description = 'Estado'
    
    def tiene_firmas(self, obj):
        """Muestra si tiene firmas"""
        firmas = obj.firmas.all()
        tiene_supervisor = firmas.filter(tipo_firma='supervisor').exists()
        tiene_control_calidad = firmas.filter(tipo_firma='control_calidad').exists()
        
        icons = []
        if tiene_supervisor:
            icons.append('✓ Supervisor')
        if tiene_control_calidad:
            icons.append('✓ Control Calidad')
        
        return ', '.join(icons) if icons else 'Sin firmas'
    
    tiene_firmas.short_description = 'Firmas'

    # Método para mostrar cantidad de colaboradores
    def get_colaboradores_count(self, obj):
        count = obj.colaboradores_reales.count()
        return f"{count} colaborador{'es' if count != 1 else ''}"
    
    get_colaboradores_count.short_description = 'Colaboradores'

    def tiene_foto_etiquetas(self, obj):
        """Muestra ícono si tiene foto"""
        if obj.foto_etiquetas:
            return format_html('<span style="color: green;">✓ Sí</span>')
        return format_html('<span style="color: red;">✗ No</span>')
    tiene_foto_etiquetas.short_description = 'Foto'
    
    def preview_foto_etiquetas(self, obj):
        """Muestra preview de la foto en el admin"""
        if obj.foto_etiquetas:
            return format_html(
                '<a href="{url}" target="_blank">'
                '<img src="{url}" style="max-width: 300px; max-height: 300px; border: 1px solid #ddd; border-radius: 4px;"/>'
                '</a>',
                url=obj.foto_etiquetas.url
            )
        return "Sin foto"
    preview_foto_etiquetas.short_description = 'Vista Previa de Foto'

