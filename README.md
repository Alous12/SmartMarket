# SmartMarket

Base Flutter organizada por funcionalidades. Por ahora solo está implementada
la vista del supermercado; los otros módulos tienen carpetas reservadas.

## Organización

```text
lib/
  main.dart                  # Arranque y ProviderScope
  app/
    smartmarket_app.dart     # MaterialApp
    router/                  # go_router; ruta /supermercado
    providers/               # Conexión de repositorios e implementaciones
  core/
    theme/                   # Tema compartido
    ui/ network/ errors/     # Reservados; sin implementaciones anticipadas
  features/
    auth/ home/ catalog/ assistant/ shopping/
      data/ domain/ presentation/  # Reservados; sin pantallas
    store_navigation/
      data/                  # Lectura del GLB y repositorio de assets
      domain/                # Datos y contrato de repositorio en Dart puro
      presentation/          # Estado Riverpod, pantalla y motor 3D
Modelos_3D/
  supermercado_natural.blend     # Supermercado Natural (editable; no va en el APK)
  supermercado_1.glb             # Exportación de supermercado_natural.blend
  SmartMarket_mapa3D_2.blend     # SmartMarket Piloto, con productos editables
  supermercado_2.glb             # Exportación de SmartMarket_mapa3D_2.blend
  texturas/                      # Atlas horneado que usa el mapa piloto
  scripts/                       # Generador de cajas, etiquetas y nodos del piloto
```

## Dos supermercados y nombres editables

Los botones **Natural / Piloto** bajo el título cambian de modelo. Ambos GLB usan
el mismo esquema de extras de Blender:

| kind | Objeto | Datos |
| --- | --- | --- |
| `product_location` | `slot_<SLOT>` (Empty) | `slot_id`, `shelf_id`, `route_node` |
| `product_group` | `producto_<ID> \| <nombre>` (Empty) | `product_id`, `display_name`, `category`, `route_node` |
| `product_box` | `caja_<ID>_<fila><col>` (Mesh) | `product_id`, `row`, `column`; frente = eje local −Y |
| `editable_label` | `etiqueta_<ID>_<fila><col>` (Texto) | `text` (solo en el .blend del piloto) |
| `route_node` | `node_*` (Empty) | `node_id`, `vecinos` (piloto) |

La app no dibuja los textos de Blender: dibuja etiquetas propias sobre la cara
frontal de cada caja (una textura compartida, 1 llamada de dibujo). Toca una caja o
abre **Productos** (icono de inventario) para buscar, enfocar y renombrar. Los
cambios se guardan en el teléfono por supermercado (`shared_preferences`) y no
modifican el GLB. **Restaurar** vuelve al nombre del .blend.

Para regenerar el piloto después de editar el plano en Blender 5.x:

```bash
blender -b Modelos_3D/SmartMarket_mapa3D_2.blend -P Modelos_3D/scripts/agregar_productos_mapa.py -- --export
```

El script es repetible: borra y vuelve a crear los 247 grupos (988 cajas), usa
`catalogo_nombres.py` para los nombres iniciales y exporta `supermercado_2.glb`.
Guarda el .blend desde Blender si quieres conservar el resultado en el archivo.

## Cámara

Perspectiva libre, como el visor de Blender: un dedo gira alrededor del punto
central, dos dedos desplazan y hacen zoom hacia el punto pellizcado (hasta 35 cm
del objetivo). El botón de la mano cambia un dedo a desplazamiento. Botones:
acercar, alejar, girar 45° a cada lado, vista superior, vista de pasillo, nodos de
ruta y centrar. Con ratón: izquierdo gira, derecho desplaza, rueda acerca.

`presentation` consume el contrato de `domain`; `data` lo implementa y `app`
conecta ambos. El WebView queda dentro de la presentación de la vista 3D.
Three.js r180 está empaquetado en `assets/store_viewer/`, con su licencia MIT.
Riverpod administra la carga; go_router administra las rutas. No hay generadores
de código ni casos de uso vacíos. Añadirlos cuando exista lógica que lo requiera.

## Ejecutar en Android

```powershell
flutter pub get
flutter emulators
flutter emulators --launch Medium_Phone_API_36.0
flutter devices
flutter run -d emulator-5554
```

Usa el ID que aparezca en `flutter devices` si es diferente. La app abre
directamente el **Supermercado Natural**; el botón **Piloto** abre el otro mapa.

## Rendimiento

Pulsa el velocímetro de la barra superior para abrir **Rendimiento 3D**. Muestra
FPS de fotogramas 3D completados, llamadas de dibujo, triángulos visibles,
tamaño del archivo, duración de preparación 3D y número de IDs/nodos. La duración
3D incluye inicialización del WebView y preparación del modelo, pero no la lectura
previa del asset. Los FPS corresponden al ciclo de dibujo WebGL; no son una
medición directa del tiempo de GPU ni de los fotogramas de Flutter.

El panel activa el dibujo continuo para poder medir. Al cerrarlo, la escena se
dibuja solo cuando cambia la cámara o el tamaño de la ventana. En segundo plano
se suspende el dibujo. Las métricas se actualizan una vez por segundo sin
reconstruir toda la vista. Se registran en consola como `SMARTMARKET_3D`.

Configuración inicial: resolución 3D limitada a 1,5 píxeles por píxel lógico, sin sombras,
sin antialiasing y sin luces nuevas. Se conserva `KHR_materials_unlit`, las mallas
de etiquetas, colores y metadatos del GLB. Las copias de una misma malla se
dibujan mediante instancias al cargar; no se modifica el GLB ni el `.blend`.
La jerarquía original con `extras` se conserva invisible para futuras consultas.
Las instancias visuales son estáticas: una futura actualización de inventario
deberá actualizar las instancias y etiquetas, además del nodo de datos.

Prueba sugerida: abrir el panel, esperar a que se estabilice, recorrer pasillos,
hacer zoom y regresar a la vista general. Comparar los valores mientras el mapa
se mueve. El emulador y el modo debug sirven para comprobar funcionamiento y
detectar problemas; para validar rendimiento móvil hace falta un teléfono físico
con `flutter run --profile` y Flutter DevTools. No hay inventario, búsqueda de
productos ni cálculo de rutas implementados todavía.

Prueba realizada en `Medium_Phone_API_36.0` (Android x86_64, modo profile):
aproximadamente 59–60 FPS estabilizados y 175 llamadas de dibujo en la vista
general con 55.112 triángulos. La primera preparación 3D tardó 12,36 s; tras
reabrir la versión final tardó 4,38 s. La nitidez está limitada a una escala de
1,5. Estos valores corresponden a este emulador y al visor WebGL, y deben volver
a medirse en un dispositivo físico. Las pruebas conservan colores, matrices,
triángulos, IDs de productos y nodos, y verifican la recuperación de errores.

```powershell
flutter analyze
flutter test
node --experimental-default-type=module --test test/store_viewer/instancing_test.mjs
```

Referencias: [arquitectura Flutter](https://docs.flutter.dev/app-architecture/guide),
[rendimiento Flutter](https://docs.flutter.dev/perf/ui-performance),
[WebView Flutter](https://pub.dev/packages/webview_flutter),
[Three.js](https://github.com/mrdoob/three.js/releases/tag/r180).

El visor y GLB se sirven desde un servidor interno limitado a `127.0.0.1`, con
puerto y ruta temporal. No necesita conexión externa. Android permite HTTP solo
para esa dirección mediante `network_security_config.xml`. La prueba de hoy es
Android; la configuración y el rendimiento de iOS todavía no están validados.
