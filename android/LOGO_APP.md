# Logo de la aplicación (Android)

Para poner el logo de SmartMarket se modificaron estas carpetas de
`app/src/main/res/` (generadas con `dart run flutter_launcher_icons`):

- `mipmap-mdpi/` … `mipmap-xxxhdpi/`: `ic_launcher.png` reemplazado por el logo.
- `mipmap-anydpi-v26/`: `ic_launcher.xml` nuevo (icono adaptativo, Android 8+).
- `drawable-mdpi/` … `drawable-xxxhdpi/`: `ic_launcher_foreground.png` nuevo
  (primer plano del icono adaptativo).
- `values/`: `colors.xml` nuevo (fondo blanco del icono).

Esta nota no va dentro de `res/` porque Android no admite archivos que no sean
recursos en esas carpetas.
