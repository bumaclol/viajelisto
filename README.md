# viajelisto

Planificador de equipaje y costos de viaje compartido.

---

## Conexión con el Servidor

La aplicación móvil se conecta al backend centralizado alojado en Render para que todo el equipo trabaje sobre la misma base de datos:

- **Servidor:** `https://viajelisto.onrender.com`
- **Comprobación de estado:** `https://viajelisto.onrender.com/salud`

> **Nota:** Al estar en el plan gratuito de Render, si el servicio ha estado inactivo puede tardar entre 40 y 60 segundos en responder a la primera petición mientras se reactiva la instancia.

---

## Cómo ejecutar la aplicación

Para abrir y poner en marcha la app conectada al servidor:

1. Instalar las dependencias de Flutter:
   ```bash
   flutter pub get