# TravelEquality

App para armar listas de equipaje y repartir el costo de un viaje.

La cuenta, las listas y el viaje se guardan en el servidor:

`https://viajelisto.onrender.com`

Al volver a iniciar sesión con el mismo correo y contraseña, se recuperan las listas y el viaje guardados en esa cuenta.

## Cómo abrirla

1. Instala Flutter.
2. En esta carpeta ejecuta `flutter pub get`.
3. Ejecuta `flutter run`. En el computador sirve `flutter run -d chrome`.

La dirección del servidor está en `lib/main.dart`. No hace falta levantar un servidor en tu PC.

La primera visita puede demorar cerca de un minuto si el servicio gratis de Render estaba dormido.

## Qué hace cada parte

- Equipaje: listas Playa, Camping y Bosque, y listas propias.
- Viaje: calcula combustible, peajes y otros gastos, y arma un texto para compartir con el equipaje marcado.
- Perfil: nombre, teléfono y foto de la cuenta.

Para comprobar que el servidor responde, abre `https://viajelisto.onrender.com/salud`. Tiene que decir `"ok": true`.

## Despliegue del servidor en Render

Render debe desplegar la rama `servidor/render` con `servidor` como directorio raíz. Esa carpeta contiene `.python-version` para usar Python 3.14 y `requirements.txt` con las dependencias del servidor. Configura `SUPABASE_DB_URL` en el servicio para guardar cuentas y datos en Supabase; sin esa variable el servidor usa SQLite local.
