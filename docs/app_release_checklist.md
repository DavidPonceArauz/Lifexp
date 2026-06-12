# LifeXP app release checklist

## 1. Bloqueantes de publicacion

- [x] Definir paquete real Android y reemplazar `com.example.lifexp` en app, deep links, widgets y config relacionada.
- [x] Revisar deep links, widget channel y referencias duras al package viejo.
- [x] Reemplazar textos legales placeholder por contenido real minimo.
- [x] Tener una politica de privacidad publica real.
- [x] Revisar permisos de alarmas exactas y fallback de notificaciones.
- [x] Declarar `url_launcher`.
- [x] Revisar `.env` y config sensible.

## 2. Calidad y bugs recientes

- [x] Aplicar SQL de frecuencia de habitos en Supabase.
- [x] Crear y cargar habitos semanales.
- [x] Estabilizar boton `MARCAR` para evitar doble tap/reversion.
- [x] Actualizar de forma optimista el estado y la tabla de racha al completar un habito.
- [x] Validar manualmente en Android real la respuesta inmediata del estado y la racha.
- [x] Confirmar que el estado del habito y la racha permanecen correctos al recargar.
- [x] Agregar fallback de notificaciones del calendario.
- [x] Guardar checklist maestro de la app.
- [x] Corregir uso de freeze para que no descuente dos veces el mismo dia/habito.
- [x] Corregir uso de freeze para que quite la penalizacion XP del miss si ya se habia aplicado.
- [x] Otorgar freezes al cruzar milestones de racha diaria cada 7 dias.
- [x] Corregir la lectura obsoleta que podia ocultar el popup de freezes.
- [x] Eliminar la modificacion de `userIdProvider` durante el ciclo de construccion.
- [x] Declarar las dependencias scoped de usuario en Habitos, Metas y Tareas.
- [x] Validar manualmente que la app abre y admite reinicio completo sin error de Riverpod.
- [x] Validar manualmente en Android real: freeze ganado al completar racha.
- [x] Validar manualmente en Android real: el mismo milestone no entrega freezes duplicados.
- [x] Validar manualmente en Android real: popup de freezes con saldo y habitos pendientes.
- [x] Validar manualmente en Android real: usar freeze sobre un habito perdido.
- [x] Validar manualmente en Android real: notificacion de calendario 2-3 minutos adelante.
- [x] Eliminar el campo redundante `Hora` del formulario de eventos; el horario vive en `Recordatorio`.
- [x] Validar manualmente el formulario de eventos sin el campo redundante `Hora`.
- [x] Validar manualmente en Android real: evento recurrente lunes/viernes con notificacion.
- [x] Validar manualmente en Android real: boton `MARCAR` con taps rapidos.
- [x] Correr analyzer de archivos tocados tras el fix de freeze y la actualizacion optimista.
- [x] Confirmar que la app compila y ejecuta en debug despues del fix de freeze.
- [x] Pasar `test/habit_objective_eval_test.dart` (5 tests).
- [x] Pasar `test/domain_models_test.dart` (4 tests).
- [x] Pasar `test/state_objects_test.dart` (5 tests).
- [x] Pasar `test/filter_notifiers_test.dart` (4 tests).
- [x] Correr tests relevantes por partes (18 tests aprobados).
- [x] Analizar `lib/main_shell.dart` tras los ajustes de Riverpod.
- [x] Analizar `lib/features/habits/presentation/providers/habits_provider.dart`.
- [x] Analizar `lib/features/goals/presentation/providers/goals_provider.dart`.
- [x] Analizar `lib/features/todos/presentation/providers/todos_provider.dart`.
- [x] Analizar `lib/features/home/presentation/home_screen.dart` tras los ajustes de calendario.
- [x] Completar el analyzer de todos los archivos modificados en los ajustes finales.
- [x] Confirmar `flutter build appbundle --release` despues de cerrar bugs recientes (AAB de 50.4 MB).
- [x] Guardar un checkpoint Git limpio de los cambios actuales.

## 3. Preparacion Play Console

- [ ] Nombre final de la app.
- [ ] Icono final.
- [ ] Splash y branding consistentes.
- [ ] Screenshots reales.
- [ ] Descripcion corta y larga.
- [ ] Categoria y tags.
- [ ] Email de soporte real.
- [x] Privacy Policy URL.
- [ ] Data Safety form: email, username, habitos/metas/tareas, analytics, crash reporting.
- [ ] Explicar borrado de cuenta si Play lo pide.

## 4. Lanzamiento controlado

- [ ] Subir primero a `internal testing`.
- [ ] Invitar 5-10 testers.
- [ ] Recoger: crashes, problemas de notificaciones, errores de auth, UX confusa en habitos anclados.
- [ ] Pasar a `closed testing`.
- [ ] Finalmente produccion.
