# 🎯 Pro Warmup AI - Left 4 Dead 2 Competitive Bot
![SourcePawn](https://img.shields.io/badge/Language-SourcePawn-blue.svg) ![L4D2](https://img.shields.io/badge/Game-Left_4_Dead_2-red.svg) ![ZoneMod](https://img.shields.io/badge/Compatibility-ZoneMod-success.svg)

Un motor de Inteligencia Artificial avanzado desarrollado en C++ (SourcePawn) para servidores de entrenamiento y calentamiento competitivo (e-sports) en Left 4 Dead 2. 

A diferencia de los bots nativos del motor Source que dependen de radios de detección estáticos y "visión omnisciente", **Pro Warmup AI** utiliza trazado de rayos (*Raytracing*), cálculo de trayectorias vectoriales y predicción cinemática para reaccionar a amenazas en tiempo real con precisión milimétrica, obligando a los jugadores a mejorar su posicionamiento y toma de decisiones.

## 🚀 Arquitectura y Características Principales

* **Filtros de Visión Dinámicos (`TR_TraceRay`):** Los bots calculan la línea de visión real (LOS) frame a frame. Ignoran a los compañeros de equipo (evitando ceguera por fuego amigo) y no intentan interactuar a través de barreras sólidas, eliminando el comportamiento *wallhacker*.
* **Predicción Cinemática de Intercepción (Skeet & Deadstop):** El algoritmo extrae el vector de velocidad tridimensional (`m_vecVelocity`) de las amenazas. Si un objetivo está en el aire a alta velocidad, el bot calcula el *Time-to-Impact* y predice su posición futura para ejecutar intercepciones *frame-perfect*.
* **Toma de Decisiones Basada en Contexto:** La IA lee la memoria del servidor para saber qué arma tiene equipada y ajusta su comportamiento dinámicamente (ej. Retención de disparo esperando el *Sweet Spot* para escopetas vs. *Tracking* continuo para rifles automáticos).
* **Integración Nativa con Zone Mod:** Respeta las físicas competitivas (sin *stagger* para Hunters en el aire, priorizando el daño letal sobre el empuje).

## 🧠 La Matemática detrás de la Predicción
Para asegurar una intercepción precisa contra objetivos aéreos, el sistema omite el chequeo de distancia lineal y calcula el punto futuro de impacto utilizando cinemática vectorial básica:
`Posición_Futura = Posición_Actual + (Velocidad_Vectorial * (Tiempo_Impacto * 0.5))`

## 🚧 Estado Actual del Proyecto y Roadmap

Actualmente, el proyecto se encuentra en desarrollo activo, estructurado en fases de implementación:

- [x] **Fase 1A: Arquitectura Core:** Trazado de rayos y matemáticas vectoriales base.
- [x] **Fase 1B: IA Defensiva (Supervivientes):** Predicción de *Skeets* y *Deadstops* para intercepción de infectados especiales (Actualmente en proceso de pulido).
- [ ] **Fase 2: IA Ofensiva (Infectados Especiales):** Reescritura de la lógica de ataque de los bots infectados para ejecutar *setups*, amagues (*baits*) y ataques coordinados (Próximamente).
- [ ] **Fase 3: Módulo de Telemetría (Data Engineering):** Integración mediante Docker con una API REST (Node.js/Spring Boot) y SQL Server para registrar, analizar y visualizar los tiempos de reacción (TTK) de los jugadores humanos contra esta IA.

## ⚙️ Instalación (Para Servidores Locales / Dedicados)

1. Descarga e instala la última versión de [SourceMod](https://www.sourcemod.net/).
2. Coloca el archivo compilado `pro_warmup_ai.smx` en el directorio `addons/sourcemod/plugins/`.
3. Reinicia tu servidor o cambia de mapa.

## 🎮 Comandos Disponibles

* `!dificultad` - Abre el menú para ajustar el nivel cognitivo y el margen de error de los bots.
  * **Amateur:** Reacción de 0.5s, sin predicción avanzada.
  * **Scrim:** Reacción de 0.2s, 60% de precisión en intercepciones.
  * **Hokori:** Reacción instantánea, 95% de precisión predictiva. Obliga a los profesionales a utilizar *baiteos* reales para aprovechar el 5% de margen de error del sistema.
* `!practica` - Entorno de laboratorio: Limpia el mapa de entidades basura, bloquea al Director (cero hordas automáticas) y permite cambios infinitos de equipo para pruebas de salto ininterrumpidas.

---
*Desarrollado aplicando principios de Ingeniería de Software y Arquitectura de Sistemas para la comunidad competitiva de L4D2.*
