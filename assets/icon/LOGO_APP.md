# Logo de la aplicación

Esta carpeta se creó para poner el logo de SmartMarket como icono de la app.

- `app_icon.png`: logo sobre fondo blanco (1024×1024). Base de los iconos de
  Android (versiones antiguas), iOS y macOS.
- `app_icon_foreground.png`: logo con fondo transparente y margen, usado como
  primer plano del icono adaptativo de Android 8+.

Para cambiar el logo, reemplaza estas imágenes y ejecuta:

    dart run flutter_launcher_icons

La configuración está en `flutter_launcher_icons.yaml` (raíz del proyecto).
