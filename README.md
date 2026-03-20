# 🎯 Pro Warmup AI - Left 4 Dead 2 Competitive Bot
![SourcePawn](https://img.shields.io/badge/Language-SourcePawn-blue.svg) ![L4D2](https://img.shields.io/badge/Game-Left_4_Dead_2-red.svg) ![ZoneMod](https://img.shields.io/badge/Compatibility-ZoneMod-success.svg)

Un motor de Inteligencia Artificial avanzado para servidores de entrenamiento y calentamiento competitivo (e-sports) en Left 4 Dead 2. 

A diferencia de los bots nativos que dependen de radios de detección estáticos, **Pro Warmup AI** utiliza trazado de rayos (Raytracing), cálculo de trayectorias vectoriales y predicción cinemática para reaccionar a amenazas en tiempo real con precisión milimétrica.

## 🚀 Arquitectura y Características Principales

* **Filtros de Visión Dinámicos (`TR_TraceRay`):** Los bots calculan la línea de visión real (LOS). Ignoran a los compañeros de equipo (evitando ceguera por fuego amigo) y no intentan disparar a través de paredes sólidas.
* **Predicción Cinemática de Intercepción (Skeet & Deadstop):** El algoritmo extrae el vector de velocidad tridimensional (`m_vecVelocity`) de los infectados especiales. Si un Hunter está en el aire, el bot calcula el *Time-to-Impact* y predice su posición futura para ejecutar un "Skeet" perfecto en el "Sweet Spot" de la escopeta.
* **Toma de Decisiones Basada en Contexto:** La IA ajusta su comportamiento dinámicamente según el arma equipada (Retención de disparo para escopetas vs. Tracking continuo para rifles automáticos).
* **Integración Nativa con Zone Mod:** Respeta las físicas competitivas (sin *stagger* para Hunters en el aire, priorizando el daño letal sobre el empuje).

## 🧠 La Matemática detrás de la Predicción
El cálculo del punto futuro de impacto utiliza la siguiente base cinemática para asegurar una intercepción *frame-perfect*:
`Posición_Futura = Posición_Actual + (Velocidad_Vectorial * (Tiempo_Impacto * 0.5))`

## ⚙️ Instalación (Para Administradores de Servidores)

1. Descarga la última versión de [SourceMod](https://www.sourcemod.net/).
2. Coloca el archivo compilado `pro_warmup_ai.smx` en el directorio `addons/sourcemod/plugins/`.
3. (Opcional) Si compilas desde el código fuente, asegúrate de tener las librerías `sdktools` incluidas.
4. Reinicia tu servidor o cambia de mapa.

## 🎮 Comandos Disponibles

* `!dificultad` - Abre el menú para ajustar el nivel cognitivo de los bots.
  * **Amateur:** Reacción de 0.5s, sin predicción avanzada.
  * **Scrim:** Reacción de 0.2s, 60% de precisión en intercepciones.
  * **Hokori:** Reacción de 0.0s, 95% de precisión predictiva. Obliga a los jugadores a utilizar *baiteos* reales.
* `!practica` - Prepara el entorno competitivo: Limpia el mapa, bloquea al Director (cero hordas) y permite cambios infinitos de equipo.

## 🛠️ Próximos Pasos (Roadmap)
- [x] Lógica Vectorial Core y Filtros de Visión.
- [x] Predicción de Skeets y Deadstops.
- [ ] Módulo de Telemetría: Integración con API REST (Node.js/Spring Boot) para exportar métricas de *Time-To-Kill* (TTK) y precisión a una base de datos SQL Server.

---
*Desarrollado aplicando principios de Ingeniería de Software para la comunidad competitiva de L4D2.*
