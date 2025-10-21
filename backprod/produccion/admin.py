# Register your models here.

from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from django.utils.html import format_html
from .models import (
    Usuario, Linea, Turno, Colaborador, 
    Producto, MateriaPrima, Receta, 
    Tarea, TareaColaborador
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
    
    list_display = ['codigo', 'nombre', 'activo']
    list_filter = ['activo']
    search_fields = ['codigo', 'nombre', 'descripcion']
    ordering = ['codigo']
    
    fieldsets = (
        ('Información del Producto', {
            'fields': ('codigo', 'nombre', 'activo')
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
    
    list_display = ['codigo', 'nombre', 'requiere_lote', 'activo']
    list_filter = ['requiere_lote', 'activo']
    search_fields = ['codigo', 'nombre']
    ordering = ['codigo']
    
    fieldsets = (
        ('Información de Materia Prima', {
            'fields': ('codigo', 'nombre', 'requiere_lote', 'activo')
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