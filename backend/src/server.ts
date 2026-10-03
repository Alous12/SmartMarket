import { app } from './app.js';
import { port } from './config/environment.js';

app.listen(port, () => {
  console.info(`SmartMarket API escuchando en el puerto ${port}`);
});
