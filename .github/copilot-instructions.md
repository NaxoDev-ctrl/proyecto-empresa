# Chocolatería Entrelagos - Sistema de Producción

## Arquitectura del Proyecto

Este es un **sistema de gestión de producción** compuesto por dos aplicaciones separadas:

### Backend (`backprod/`)
- **Stack**: Django 4.2.7 + Django REST Framework + PostgreSQL
- **Base de datos**: PostgreSQL (`chocolateria_test` en localhost:5432)
- **Autenticación**: JWT (djangorestframework-simplejwt) con tokens de 8 horas
- **CORS**: Habilitado para desarrollo con `CORS_ALLOW_ALL_ORIGINS = True`
- **Aplicación principal**: `produccion` - Maneja toda la lógica de negocio

### Frontend (`frontprod/`)
- **Stack**: Flutter 3.8.1 (multiplataforma)
- **State Management**: Provider (AuthService, FiltroProvider)
- **API Client**: http package con ApiService singleton
- **Base URL**: `http://127.0.0.1:8000/api` (cambiar para emulador Android: `http://10.0.2.2:8000/api`)

---

## Modelo de Dominio

El sistema gestiona **tareas de producción** con estos conceptos clave:

1. **Tarea**: Asignación de fabricación de un producto en una línea específica, turno y fecha
   - Constraint único: `(linea, turno, fecha, producto)` - **NO se permiten duplicados**
   - Estados: `pendiente` → `en_curso` → `finalizada`
   - Solo puede haber **una tarea en curso por línea** simultáneamente

2. **Usuario**: Roles diferenciados (`supervisor`, `control_calidad`)
   - Model personalizado: `AUTH_USER_MODEL = 'produccion.Usuario'`
   - Solo supervisores pueden crear/editar tareas (`IsSupervisorOrReadOnly` permission)

3. **Línea**: Líneas de producción física (ej: "Línea 1", "Línea 2")

4. **Turno**: Horarios de trabajo predefinidos
   - `AM (06:15-13:35)`, `Jornada (08:00-17:30)`, `PM (13:25-22:05)`

5. **Producto**: Artículos fabricados (ej: código "410" - "alfajor manjar bitter")
   - Tienen **Recetas**: Lista de MateriaPrima necesarias

6. **Colaborador**: Trabajadores asignados a tareas
   - Cargados masivamente desde Excel por supervisores
   - Campos: `codigo`, `nombre`, `apellido`

---

## Patrones y Convenciones

### Backend (Django)

**Estructura de ViewSets**:
```python
# ViewSets con permisos rol-based
class TareaViewSet(viewsets.ModelViewSet):
    permission_classes = [IsAuthenticated, IsSupervisorOrReadOnly]
    # Supervisores: CRUD completo | Otros: Solo lectura
```

**Actions personalizados**:
- `@action(detail=True)`: Operaciones sobre instancia específica (ej: `/tareas/5/iniciar/`)
- `@action(detail=False)`: Operaciones de colección (ej: `/tareas/hoy/`)

**Validación de negocio**:
- Usar `clean()` en modelos para reglas complejas
- Usar `validate()` en serializers para verificar duplicados
- Lanzar `ValidationError` con mensajes claros

**Serializers multinivel**:
- `TareaListSerializer`: Vista resumida para listas
- `TareaDetailSerializer`: Vista completa con relaciones anidadas
- `TareaCreateUpdateSerializer`: Entrada con `colaboradores_ids` (write_only)
  - Usa `to_representation()` para devolver formato detallado después de crear

### Frontend (Flutter)

**Gestión de estado**:
```dart
// AuthService: Usuario autenticado y token JWT
Provider.of<AuthService>(context, listen: false).usuario

// FiltroProvider: Fecha seleccionada (compartida entre pantallas)
Provider.of<FiltroProvider>(context).selectedDate
```

**ApiService (Singleton)**:
- Headers automáticos: `Bearer {token}` para endpoints autenticados
- Manejo de errores centralizado en `_handleError()`
- Decodificación UTF-8: `json.decode(utf8.decode(response.bodyBytes))` para caracteres especiales

**Navegación con resultado**:
```dart
// Pasar `true` al volver para indicar que se creó/editó algo
Navigator.pop(context, true);

// En la pantalla padre, recargar datos si hay cambios
final resultado = await Navigator.push(...);
if (resultado == true) { _cargarTareas(); }
```

**Diálogos de selección múltiple**:
- Usar `Set<Colaborador>` para manejar selección sin duplicados
- Agregar/remover listener del `searchController` en `initState`/`dispose` para evitar fugas de memoria

---

## Flujos Críticos de Trabajo

### Crear Tarea (Supervisor)

1. Usuario selecciona fecha (sincronizada con `FiltroProvider`)
2. Selecciona línea, turno, producto (dropdowns)
3. Selecciona colaboradores (diálogo con búsqueda en tiempo real)
4. Backend valida constraint único: `(linea, turno, fecha, producto)`
5. Si duplicado → Error 400 con mensaje claro: "Ya existe una tarea..."

### Iniciar/Finalizar Tarea

Backend aplica **reglas de negocio estrictas**:
```python
# Solo una tarea en curso por línea
if Tarea.objects.filter(linea=linea, estado='en_curso').exists():
    raise ValidationError('Ya hay una tarea en curso en esta línea')
```

Flutter llama a:
- `POST /api/tareas/{id}/iniciar/`
- `POST /api/tareas/{id}/finalizar/`
- `GET /api/tareas/{id}/verificar_bloqueo/` (antes de permitir inicio)

### Cargar Colaboradores desde Excel

Supervisores pueden cargar listas de colaboradores:
- Endpoint: `POST /api/colaboradores/cargar_excel/` (JSON) o `/cargar_excel_archivo/` (Multipart)
- Usa `update_or_create()` por `codigo`: Actualiza si existe, crea si no
- Retorna contadores: `{creados: 5, actualizados: 3}`

---

## Comandos de Desarrollo

### Backend
```powershell
cd backprod
# Instalar dependencias
pip install -r requirements.txt

# Migraciones
python manage.py makemigrations
python manage.py migrate

# Crear superusuario (admin)
python manage.py createsuperuser

# Ejecutar servidor
python manage.py runserver
# API en: http://127.0.0.1:8000/api/
# Admin en: http://127.0.0.1:8000/admin/
```

### Frontend
```powershell
cd frontprod
# Instalar dependencias
flutter pub get

# Ejecutar en modo debug (Windows)
flutter run -d windows

# Ejecutar en emulador Android/iOS
flutter run

# Build para producción
flutter build windows
flutter build apk
```

**IMPORTANTE**: Si cambias el host del backend, actualiza `ApiService.baseUrl` en `lib/services/api_service.dart`.

---

## Endpoints Clave del API

**Autenticación**:
- `POST /api/auth/login/` → `{username, password}` → `{access, refresh}`
- `GET /api/usuarios/me/` → Datos del usuario autenticado

**Recursos**:
- `GET /api/lineas/` - Líneas activas
- `GET /api/turnos/` - Turnos activos
- `GET /api/productos/` - Productos (con `?search=`)
- `GET /api/productos/{codigo}/` - Producto con receta (materias primas)
- `GET /api/colaboradores/` - Colaboradores (con `?search=`)

**Tareas**:
- `GET /api/tareas/` - Todas (filtros: `?fecha=`, `?linea=`, `?turno=`, `?estado=`)
- `GET /api/tareas/hoy/` - Solo tareas de hoy
- `GET /api/tareas/{id}/` - Detalle completo con colaboradores y receta
- `POST /api/tareas/` - Crear (requiere `supervisor_asignador`, `colaboradores_ids`)
- `PUT /api/tareas/{id}/` - Actualizar (solo si `pendiente`)
- `DELETE /api/tareas/{id}/` - Eliminar (solo si `pendiente`)
- `POST /api/tareas/{id}/iniciar/` - Cambiar a `en_curso`
- `POST /api/tareas/{id}/finalizar/` - Cambiar a `finalizada`

---

## Configuración Importante

**Django Settings (`backprod/backprod/settings.py`)**:
- Database: PostgreSQL en `localhost:5432`
- JWT lifetime: 8 horas (turno completo de trabajo)
- Timezone: `America/Santiago`
- Locale: `es-cl`
- Media uploads: Fotos de etiquetas (max 10MB), Excel (max 5MB)

**Flutter Pubspec (`frontprod/pubspec.yaml`)**:
- Provider: State management
- http: Requests HTTP
- shared_preferences: Token storage local
- intl: Formateo de fechas en español
- file_picker + excel: Carga de colaboradores desde Excel

---

## Consejos para Extender el Sistema

1. **Agregar un campo a Tarea**: 
   - Backend: Añadir a `models.py`, hacer migration, actualizar serializers
   - Frontend: Actualizar modelo Dart, ajustar formularios/pantallas

2. **Nuevo ViewSet**:
   - Registrar en `router` en `produccion/urls.py`
   - Aplicar permisos apropiados (`IsSupervisor`, `IsSupervisorOrReadOnly`)

3. **Nuevo screen Flutter**:
   - Seguir patrón: StatefulWidget con `_isLoading` para feedback visual
   - Usar `Provider.of<AuthService>` para acceder a usuario/rol
   - Llamar a `ApiService()` singleton para HTTP requests

4. **Validaciones de negocio**:
   - Backend: Centralizar en `model.clean()` o `serializer.validate()`
   - Frontend: Validar en formulario ANTES de enviar request (UX)
