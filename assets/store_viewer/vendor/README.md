Three.js r180 (0.180.0), MIT.

Archivos originales de https://github.com/mrdoob/three.js/tree/r180:

- `build/three.module.min.js` y `build/three.core.min.js`
- `examples/jsm/loaders/GLTFLoader.js`
- `examples/jsm/controls/OrbitControls.js`
- `examples/jsm/utils/BufferGeometryUtils.js`
- `LICENSE`

Se conservan sin modificaciones. El servidor local sirve BufferGeometryUtils
bajo `/utils/` para respetar la importación relativa del cargador.
No se usan CDN ni peticiones externas al ejecutar la app.
