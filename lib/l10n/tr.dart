import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../state/app_controller.dart';

/// Devuelve el texto en español, o en inglés si la persona lo eligió.
/// Las pruebas buscan el español, que es el idioma por defecto.
String tr(BuildContext context, String spanish) {
  final code = context.watch<AppController>().languageCode;
  if (code != 'en') return spanish;
  return _english[spanish] ?? spanish;
}

const _english = <String, String>{
  'Inicio': 'Home',
  'Equipaje': 'Luggage',
  'Viaje': 'Trip',
  'Cuenta': 'Account',
  'Hola': 'Hello',
  'Todo listo para salir': 'Ready to go',
  'Un plan compartido. Cero errores.': 'One shared plan. No mix-ups.',
  'Que no se te quede nada': 'Leave nothing behind',
  'Seguir preparando el viaje': 'Keep packing the trip',
  'Ver gastos del viaje': 'See trip costs',
  'Crear viaje': 'Create trip',
  'Editar viaje': 'Edit trip',
  'Las cuentas, claras.': 'The costs, clear.',
  'Nuestro próximo viaje': 'Our next trip',
  'Cada uno paga lo justo.': 'Everyone pays a fair share.',
  'MI VIAJE EN EQUIPO': 'MY GROUP TRIP',
  'Todo listo para salir.': 'Ready to go.',
  'Menos olvidos. Más aventuras.': 'Fewer forgotten items. More adventure.',
  'En tu teléfono': 'On your phone',
  'TravelEquality ya está en tu pantalla de inicio.': 'TravelEquality is already on your home screen.',
  'Puedes dejar TravelEquality en la pantalla de inicio del teléfono. Se abre como una app, desde el ícono, y sigue siendo esta misma web. No está en Play Store ni en App Store.':
      'You can keep TravelEquality on your phone home screen. It opens from the icon and it is still this website. It is not on the Play Store or the App Store.',
  'Instalar': 'Install',
  'En Android, abre el menú del navegador y elige Instalar app o Agregar a la pantalla de inicio.':
      'On Android, open the browser menu and choose Install app or Add to home screen.',
  'En iPhone, toca Compartir y luego Agregar a inicio.': 'On iPhone, tap Share and then Add to Home Screen.',
  'Listo. TravelEquality quedó en tu pantalla de inicio.': 'Done. TravelEquality is on your home screen.',
  'Puedes instalarla cuando quieras desde el menú del navegador.': 'You can install it later from the browser menu.',
  'Idioma': 'Language',
  'La aplicación está en español.': 'The app is in Spanish.',
  'Notificaciones': 'Notifications',
  'Avisos de la app': 'App alerts',
  'Avisa cuando una lista queda completa y cuando el viaje se pasa del presupuesto.':
      'Alerts you when a list is fully packed and when the trip goes over budget.',
  'El navegador bloqueó los avisos. Actívalos en los permisos del sitio.':
      'The browser blocked alerts. Turn them on in the site permissions.',
  'Dónde está guardado': 'Where it is saved',
  'CONFIGURACIÓN': 'SETTINGS',
  'AYUDA Y NOTIFICACIONES': 'HELP AND NOTIFICATIONS',
  'Privacidad': 'Privacy',
  'Seguridad': 'Security',
  'Ayuda': 'Help',
  'Cerrar sesión': 'Log out',
  'WhatsApp': 'WhatsApp',
  'Correo': 'Email',
  'Español': 'Spanish',
};
