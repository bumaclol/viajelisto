import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_controller.dart';
import '../theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

enum _AuthMode { login, create, recover }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  String? _error;
  String? _success;
  String? _verifyToken;
  String? _recoveryToken;
  _AuthMode _mode = _AuthMode.login;
  late final AnimationController _intro;
  late final AnimationController _flight;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..forward();
    _flight = AnimationController(vsync: this, duration: const Duration(milliseconds: 4600))
      ..repeat();
  }

  @override
  void dispose() {
    _intro.dispose();
    _flight.dispose();
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  bool get _creating => _mode == _AuthMode.create;
  bool get _recovering => _mode == _AuthMode.recover;

  void _go(_AuthMode mode) {
    setState(() {
      _mode = mode;
      _error = null;
      _success = null;
      _verifyToken = null;
      _recoveryToken = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cloud = context.watch<AppController>().usesCloud;
    final askCode = _recovering && cloud && _recoveryToken == null;
    return Scaffold(
      body: PageBackdrop(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  children: [
                    _FlightStrip(animation: _flight),
                    const SizedBox(height: 8),
                    FadeTransition(
                      opacity: CurvedAnimation(
                        parent: _intro,
                        curve: const Interval(0, 0.7, curve: Curves.easeOut),
                      ),
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.16),
                          end: Offset.zero,
                        ).animate(
                          CurvedAnimation(
                            parent: _intro,
                            curve: const Interval(0, 0.75, curve: Curves.easeOutCubic),
                          ),
                        ),
                        child: const _BrandMark(),
                      ),
                    ),
                    const SizedBox(height: 28),
                    FadeTransition(
                      opacity: CurvedAnimation(
                        parent: _intro,
                        curve: const Interval(0.2, 1, curve: Curves.easeOut),
                      ),
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.08),
                          end: Offset.zero,
                        ).animate(
                          CurvedAnimation(
                            parent: _intro,
                            curve: const Interval(0.15, 1, curve: Curves.easeOutCubic),
                          ),
                        ),
                        child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x14305080),
                            blurRadius: 30,
                            offset: Offset(0, 16),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            _recovering
                                ? 'Recuperar contraseña'
                                : _creating
                                    ? 'Crea tu cuenta'
                                    : 'Iniciar sesión',
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: ink,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _recovering
                                ? (cloud
                                    ? 'Pide un código de un solo uso. Cuando el correo esté conectado, ese código llegará al mail.'
                                    : 'Escribe el correo de tu cuenta y elige una contraseña nueva. Se guarda en este dispositivo.')
                                : _creating
                                    ? (cloud
                                        ? 'La cuenta, las listas y el viaje se guardan en el servidor.'
                                        : 'Guarda tus listas y el costo del viaje en este teléfono.')
                                    : (cloud
                                        ? 'Entra con la cuenta del servidor para ver tu equipaje y los gastos.'
                                        : 'Entra para organizar el equipaje y repartir los gastos.'),
                            style: const TextStyle(color: Color(0xFF667085), height: 1.35),
                          ),
                          const SizedBox(height: 22),
                          if (_creating) ...[
                            _Field(
                              controller: _name,
                              label: 'Nombre',
                              icon: Icons.person_outline_rounded,
                            ),
                            const SizedBox(height: 12),
                          ],
                          _Field(
                            controller: _email,
                            label: 'Correo',
                            icon: Icons.mail_outline_rounded,
                            keyboard: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 12),
                          if (!askCode) ...[
                          _Field(
                            controller: _password,
                            label: _recovering ? 'Nueva contraseña' : 'Contraseña',
                            icon: Icons.lock_outline_rounded,
                            obscure: _obscure,
                            suffix: IconButton(
                              onPressed: () => setState(() => _obscure = !_obscure),
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                              ),
                            ),
                          ],
                          if (_creating || (_recovering && !askCode)) ...[
                            const SizedBox(height: 12),
                            _Field(
                              controller: _confirm,
                              label: 'Confirmar contraseña',
                              icon: Icons.lock_outline_rounded,
                              obscure: _obscure,
                            ),
                          ],
                          if (_mode == _AuthMode.login)
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _busy ? null : () => _go(_AuthMode.recover),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.only(top: 8),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text('¿Olvidaste tu contraseña?'),
                              ),
                            ),
                          if (_verifyToken != null || _recoveryToken != null) ...[
                            const SizedBox(height: 12),
                            SelectableText(
                              'Código: ${_verifyToken ?? _recoveryToken}',
                              style: const TextStyle(color: ink, fontWeight: FontWeight.w700),
                            ),
                          ],
                          if (_success != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              _success!,
                              style: const TextStyle(color: good, fontWeight: FontWeight.w600),
                            ),
                          ],
                          if (_error != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              _error!,
                              style: const TextStyle(color: warn, fontWeight: FontWeight.w600),
                            ),
                          ],
                          const SizedBox(height: 18),
                          FilledButton(
                            onPressed: _busy ? null : _submit,
                            style: FilledButton.styleFrom(
                              backgroundColor: blue,
                              minimumSize: const Size.fromHeight(52),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text(
                              _busy
                                  ? 'Espera...'
                                  : _verifyToken != null
                                      ? 'Confirmar correo'
                                      : askCode
                                          ? 'Pedir enlace'
                                          : _recovering
                                              ? 'Guardar contraseña'
                                              : _creating
                                                  ? 'Crear cuenta'
                                                  : 'Iniciar sesión',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ),
                    ),
                    ),
                    const SizedBox(height: 18),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => _go(
                                _mode == _AuthMode.login ? _AuthMode.create : _AuthMode.login,
                              ),
                      child: Text(
                        _recovering
                            ? 'Volver a iniciar sesión'
                            : _creating
                                ? 'Ya tengo cuenta. Iniciar sesión'
                                : '¿No tienes cuenta? Crear cuenta',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final controller = context.read<AppController>();
    if (_verifyToken != null) {
      setState(() {
        _busy = true;
        _error = null;
        _success = null;
      });
      final error = await controller.confirmEmail(_verifyToken!);
      if (!mounted) return;
      setState(() {
        _busy = false;
        if (error == null) {
          _verifyToken = null;
          _mode = _AuthMode.login;
          _password.clear();
          _confirm.clear();
          _success = 'Correo confirmado. Ya puedes entrar.';
        } else {
          _error = error;
        }
      });
      return;
    }
    if (_recovering && controller.usesCloud && _recoveryToken == null) {
      setState(() {
        _busy = true;
        _error = null;
        _success = null;
      });
      final error = await controller.requestRecovery(_email.text);
      if (!mounted) return;
      setState(() {
        _busy = false;
        if (error == null) {
          _recoveryToken = controller.pendingToken;
          _success = 'Código listo. Elige la contraseña nueva. Ese código es de un solo uso.';
        } else {
          _error = error;
        }
      });
      return;
    }
    if (_recovering) {
      setState(() {
        _busy = true;
        _error = null;
        _success = null;
      });
      final error = controller.usesCloud
          ? await controller.completeRecovery(
              token: _recoveryToken!,
              password: _password.text,
              confirm: _confirm.text,
            )
          : await controller.resetPassword(
              email: _email.text,
              password: _password.text,
              confirm: _confirm.text,
            );
      if (!mounted) return;
      setState(() {
        _busy = false;
        if (error == null) {
          _mode = _AuthMode.login;
          _recoveryToken = null;
          _password.clear();
          _confirm.clear();
          _success = 'Contraseña actualizada. Ya puedes entrar.';
        } else {
          _error = error;
        }
      });
      return;
    }
    if (_creating && _password.text != _confirm.text) {
      setState(() => _error = 'Las contraseñas no coinciden.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _success = null;
    });
    final error = _creating
        ? await controller.signUp(
            name: _name.text,
            email: _email.text,
            password: _password.text,
          )
        : await controller.signIn(
            email: _email.text,
            password: _password.text,
          );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error;
      if (error == null && _creating && controller.pendingToken != null) {
        _verifyToken = controller.pendingToken;
        _success =
            'Cuenta creada en el servidor. Confirma el correo para poder entrar. En la nube ese código llegaría al mail.';
      }
    });
  }
}

class _FlightStrip extends StatelessWidget {
  const _FlightStrip({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      width: double.infinity,
      child: ClipRect(
        child: AnimatedBuilder(
          animation: animation,
          builder: (context, _) {
            return LayoutBuilder(
              builder: (context, constraints) {
                final t = animation.value;
                final width = constraints.maxWidth;
                return Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    _Cloud(left: _drift(width, t, 0.08, 150), top: 8, scale: 1),
                    _Cloud(left: _drift(width, t, 0.58, 150), top: 52, scale: 0.75),
                    _WindStreak(left: _drift(width, t, 0.15, 90), top: 22, width: 72),
                    _WindStreak(left: _drift(width, t, 0.42, 110), top: 38, width: 48),
                    _WindStreak(left: _drift(width, t, 0.7, 80), top: 64, width: 64),
                    _WindStreak(left: _drift(width, t, 0.9, 100), top: 18, width: 36),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  double _drift(double width, double t, double shift, double span) {
    final travel = (t + shift) % 1;
    return -span + (width + span * 2) * travel;
  }
}

class _Cloud extends StatelessWidget {
  const _Cloud({required this.left, required this.top, required this.scale});

  final double left;
  final double top;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      top: top,
      child: Opacity(
        opacity: 0.9,
        child: Transform.scale(
          scale: scale,
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 54,
            height: 22,
            child: Stack(
              children: const [
                Positioned(left: 8, child: _Puff(size: 16)),
                Positioned(left: 18, top: 2, child: _Puff(size: 20)),
                Positioned(left: 32, top: 4, child: _Puff(size: 14)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Puff extends StatelessWidget {
  const _Puff({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _WindStreak extends StatelessWidget {
  const _WindStreak({required this.left, required this.top, required this.width});

  final double left;
  final double top;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      top: top,
      child: Container(
        width: width,
        height: 3,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          gradient: const LinearGradient(
            colors: [Color(0x002F6BFF), Color(0x66FFFFFF), Color(0x002F6BFF)],
          ),
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 74,
          height: 74,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF5B8CFF), Color(0xFF2F6BFF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(color: Color(0x332F6BFF), blurRadius: 18, offset: Offset(0, 8)),
            ],
          ),
          child: const Icon(Icons.flight_takeoff_rounded, color: Colors.white, size: 36),
        ),
        const SizedBox(height: 14),
        const Text(
          'TravelEquality',
          style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: ink),
        ),
        const SizedBox(height: 4),
        const Text(
          'Organiza tu próxima aventura',
          style: TextStyle(color: Color(0xFF667085), fontSize: 15),
        ),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    required this.icon,
    this.obscure = false,
    this.keyboard,
    this.suffix,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscure;
  final TextInputType? keyboard;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboard,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: suffix,
        fillColor: const Color(0xFFF7F8FB),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE6EAF0)),
        ),
      ),
    );
  }

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<StatefulWidget> {
  final TextEditingController _correoController = TextEditingController();
  final TextEditingController _codigoController = TextEditingController();
  
  bool _codigoEnviado = false; // Controla si se muestra el input del código
  bool _isLoading = false;

  // URL base de tu servidor Python (ajusta IP según tu entorno)
  final String baseUrl = "http://10.0.2.2:5000/api";

  // Paso 1: Solicitar código al servidor
  Future<void> _solicitarCodigo() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/solicitar-codigo'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"correo": _correoController.text.trim()}),
      );

      if (response.statusCode == 200) {
        setState(() {
          _codigoEnviado = true; // Muestra el campo para digitar el código
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Código enviado a tu correo electrónico.")),
        );
      } else {
        final data = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['error'] ?? "Error al enviar código")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error de conexión con el servidor")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Paso 2: Verificar el código ingresado para entrar
  Future<void> _verificarYEntrar() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/verificar-ingreso'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "correo": _correoController.text.trim(),
          "codigo": _codigoController.text.trim(),
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        // Acceso concedido: Navegar a la pantalla principal de ViajeListo
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("¡Ingreso exitoso!")),
        );
        // Navigator.pushReplacementNamed(context, '/home');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['error'] ?? "Código inválido")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error al validar el código")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Acceso / Recuperación - ViajeListo")),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _correoController,
              decoration: InputDecoration(labelText: "Correo Electrónico"),
              keyboardType: TextInputType.emailAddress,
              enabled: !_codigoEnviado, // Bloquear correo una vez enviado el código
            ),
            SizedBox(height: 16),

            // Mostrar campo de código sólo si ya fue solicitado
            if (_codigoEnviado) ...[
              TextField(
                controller: _codigoController,
                decoration: InputDecoration(
                  labelText: "Código de verificación (6 dígitos)",
                  counterText: "De un solo uso",
                ),
                keyboardType: TextInputType.number,
                maxLength: 6,
              ),
              SizedBox(height: 16),
            ],

            _isLoading
                ? CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _codigoEnviado ? _verificarYEntrar : _solicitarCodigo,
                    child: Text(_codigoEnviado ? "Verificar y Entrar" : "Enviar Código de Verificación"),
                  ),
          ],
        ),
      ),
    );
  }
}
}
