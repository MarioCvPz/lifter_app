# LiFTeR+ 🏋️

![Flutter](https://img.shields.io/badge/Flutter-3.47-02569B?logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.11-0175C2?logo=dart&logoColor=white)
![Firebase](https://img.shields.io/badge/Firebase-Auth%20%7C%20Firestore-FFCA28?logo=firebase&logoColor=black)
![Android](https://img.shields.io/badge/Android-disponible-3DDC84?logo=android&logoColor=white)
![Web](https://img.shields.io/badge/Web-disponible-4285F4?logo=googlechrome&logoColor=white)


LiFTeR+ es una app para registrar entrenamientos, seguir rutinas y controlar la nutrición. Hay tres roles: **usuarios**, **entrenadores** (asignan rutinas a sus usuarios) y **administradores** (gestionan los roles). Está hecha con Flutter, usa Firebase como backend y la interfaz va en español con tema oscuro.

## Funcionalidades

- **Inicio:** resumen de la semana, racha de días entrenando, reto semanal y contador de agua.
- **Entrenamientos:** registro de ejercicios con series, repeticiones y peso, más el historial con el volumen total de cada sesión.
- **Rutinas:** plantillas predefinidas (Full body, Torso/Pierna, Push/Pull/Legs), rutinas propias, rutinas asignadas por un entrenador y una rutina recomendada según los días por semana del perfil.
- **Nutrición:** registro de comidas por gramos, con calorías y macros del día frente a un objetivo calculado a partir del peso y la meta del usuario.
- **Perfil:** datos físicos, estadísticas, gráfica semanal y logros desbloqueables.
- **Entrenador:** asigna rutinas a otros usuarios.
- **Admin:** cambia el rol de los usuarios.
- **Login:** con correo y contraseña o con Google, y recuperación de contraseña.

## Tecnologías

| Tecnología | Uso |
|---|---|
| Flutter / Dart | Aplicación multiplataforma |
| `firebase_auth` + `google_sign_in` | Autenticación (correo y Google) |
| `cloud_firestore` | Base de datos en tiempo real |
| Plus Jakarta Sans | Tipografía (en `assets/fonts`) |

El estado se gestiona con `ChangeNotifier` + `InheritedNotifier` de Flutter, sin paquetes externos.

## Estructura del código

```
lib/
├── main.dart              # Inicializa Firebase y lanza la app
├── app.dart               # MaterialApp: tema, idioma y elección entre login y app
├── firebase_options.dart  # Configuración de Firebase para web
├── models/
│   └── models.dart        # Modelos (Workout, Routine, UserProfile…) con toMap/fromMap
├── data/
│   ├── app_store.dart     # Estado global + lectura/escritura en Firestore
│   ├── auth_service.dart  # Login, registro, Google y logout
│   ├── catalog.dart       # Catálogo fijo: ejercicios, alimentos y plantillas
│   ├── stats.dart         # Cálculos: rachas, volumen, macros, agua…
│   └── achievements.dart  # Logros a partir de las estadísticas
├── screens/
│   ├── auth/              # Login y registro
│   ├── shell/             # Barra de navegación inferior
│   ├── home/              # Inicio
│   ├── workouts/          # Historial y registro de entrenos
│   ├── routines/          # Rutinas y plantillas
│   ├── nutrition/         # Comidas y macros
│   ├── profile/           # Perfil y edición
│   ├── trainer/           # Panel del entrenador
│   └── admin/             # Panel de administración
├── theme/
│   └── app_theme.dart     # Tema oscuro
└── widgets/               # Componentes reutilizables (marca, ayuda contextual)
```

**Flujo de datos:** las pantallas nunca acceden a Firebase directamente. Leen el estado con `SessionScope.of(context)` y llaman a sus métodos, por ejemplo `addWorkout`. `AppStore` escucha Firestore en tiempo real (`snapshots()`) y llama a `notifyListeners()`, lo que hace que la interfaz se redibuje sola.

## Base de datos (Cloud Firestore)

```
users/{uid}                      # Perfil del usuario
│   name, username, email, sex, heightCm, weightKg,
│   experience, goal, daysPerWeek, equipment,
│   role                         # "user" | "trainer" | "admin" (solo lo cambia un admin)
│
├── workouts/{id}                # Entrenamientos
│     name, date, durationMin, routineId?,
│     exercises: [{ exercise, sets: [{ reps, weightKg }] }]
│
├── routines/{id}                # Rutinas propias
│     name, description, templateName, createdAt, exercises: [...]
│
├── nutrition/{id}               # Comidas registradas
│     food: { name, kcal y macros por 100 g }, grams, date
│
└── water/{aaaa-mm-dd}           # Agua bebida ese día
      ml, date

assignedRoutines/{id}            # Rutinas que un entrenador asigna a un usuario
    (campos de la rutina), trainerId, trainerName,
    userId, userName, createdAt
```

Los ejercicios, los alimentos y las plantillas **no se guardan en la base de datos**: están en [`lib/data/catalog.dart`](lib/data/catalog.dart). (Más adelante se gestionarán desde firebase)


## Próximos pasos

- [ ] Editar entrenamientos, rutinas y comidas ya guardados (ahora mismo solo se pueden crear y borrar).
- [ ] Avisar al usuario cuando falla una escritura en Firestore.
- [ ] Tests unitarios de las estadísticas (`stats.dart`).
- [ ] Configurar Firebase para iOS.

