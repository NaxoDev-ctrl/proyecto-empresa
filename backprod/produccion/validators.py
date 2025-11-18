from django.core.exceptions import ValidationError
from django.utils.translation import gettext_lazy as _
import os


def validate_image_file(value):
    """
    Validador que acepta múltiples formatos de imagen.
    Formatos permitidos: JPG, JPEG, PNG, GIF, WEBP, BMP, TIFF, SVG
    """
    
    # Extensiones permitidas
    valid_extensions = [
        '.jpg', '.jpeg', '.png', '.gif', '.webp', 
        '.bmp', '.tiff', '.tif', '.svg'
    ]
    
    # Content types permitidos
    valid_content_types = [
        'image/jpeg',
        'image/jpg', 
        'image/png',
        'image/gif',
        'image/webp',
        'image/bmp',
        'image/tiff',
        'image/svg+xml',
    ]
    
    # Obtener extensión del archivo
    ext = os.path.splitext(value.name)[1].lower()
    
    # Validar extensión
    if ext not in valid_extensions:
        raise ValidationError(
            _('Formato de archivo no soportado. Formatos permitidos: JPG, PNG, GIF, WEBP, BMP, TIFF, SVG'),
            code='invalid_extension'
        )
    
    # Validar content type si está disponible
    if hasattr(value, 'content_type') and value.content_type:
        if value.content_type not in valid_content_types:
            raise ValidationError(
                _('Tipo de contenido no válido: %(content_type)s'),
                code='invalid_content_type',
                params={'content_type': value.content_type}
            )
    
    # Validar tamaño máximo (10 MB)
    max_size = 10 * 1024 * 1024  # 10 MB en bytes
    if value.size > max_size:
        raise ValidationError(
            _('El archivo es demasiado grande. Tamaño máximo: 10 MB'),
            code='file_too_large'
        )
    
    return value