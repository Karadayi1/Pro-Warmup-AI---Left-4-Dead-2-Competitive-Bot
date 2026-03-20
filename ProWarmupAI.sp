#include <sourcemod>
#include <sdktools>

public Plugin myinfo =
{
    name        = "Pro Warmup AI",
    author      = "Karadayi",
    description = "IA Competitiva de Calentamiento",
    version     = "2.1",
    url         = ""
};

// =====================================================================
// [1] VARIABLES GLOBALES
// =====================================================================
int   g_NivelDificultad = 2;

// Momento en que el bot detecto visualmente a su objetivo por primera vez
float g_fTiempoDeteccion[MAXPLAYERS + 1];
// Indice del jugador infectado que el bot esta rastreando actualmente
int   g_iObjetivoDetectado[MAXPLAYERS + 1];

// Coordenadas de la ultima posicion donde el bot vio al objetivo antes de perder vision
float g_fUltimaPosConocida[MAXPLAYERS + 1][3];
// Momento exacto en que el bot tuvo linea de vision por ultima vez
float g_fTiempoUltimaVision[MAXPLAYERS + 1];

// =====================================================================
// [2] CONFIGURACION POR DIFICULTAD
// =====================================================================
// Tiempo en segundos que el bot tarda en reaccionar tras detectar un objetivo
float ObtenerDelayReaccion()
{
    switch (g_NivelDificultad)
    {
        case 1: return 0.5;    // Amateur
        case 2: return 0.2;    // Scrim
        case 3: return 0.0;    // Hokori
    }
    return 0.3;
}

// Desviacion maxima en grados que se aplica al angulo de apuntado del bot
float ObtenerErrorAngular()
{
    switch (g_NivelDificultad)
    {
        case 1: return 15.0;    // Amateur: precision baja
        case 2: return 5.0;     // Scrim: precision alta
        case 3: return 0.0;     // Hokori: precision perfecta
    }
    return 10.0;
}

// Determina si el bot ejecutara el empuje defensivo en este tick del servidor
bool IntentarDeadstop()
{
    switch (g_NivelDificultad)
    {
        case 1: return false;                          // Amateur: no empuja
        case 2: return (GetRandomInt(1, 100) > 25);    // Scrim: 75% de probabilidad
        case 3: return true;                           // Hokori: empuja siempre
    }
    return false;
}

// =====================================================================
// [3] FUNCIONES DE UTILIDAD
// =====================================================================

// Lanza un rayo invisible desde los ojos del bot hasta los ojos del objetivo.
// Si el rayo llega sin chocar con geometria del mapa, hay linea de vision directa.
bool TrazarLineaDeVision(int bot, int objetivo)
{
    float ojoBot[3], posObjetivo[3];
    GetClientEyePosition(bot, ojoBot);
    GetClientEyePosition(objetivo, posObjetivo);

    // MASK_SHOT simula el comportamiento de una bala real del motor Source
    Handle trace = TR_TraceRayFilterEx(ojoBot, posObjetivo, MASK_SHOT, RayType_EndPoint, FiltroVision, bot);
    bool   loVe  = false;

    if (!TR_DidHit(trace))
    {
        // El rayo no impacto nada entre ambos puntos
        loVe = true;
    }
    else
    {
        // El rayo impacto algo: si fue el propio objetivo, hay vision
        int entidadGolpeada = TR_GetEntityIndex(trace);
        if (entidadGolpeada == objetivo)
            loVe = true;
    }

    delete trace;
    return loVe;
}

// Proyecta la velocidad del zombie sobre el eje que lo une con el bot.
// Valor positivo = el zombie se acerca. Valor negativo = se aleja.
float CalcularVelocidadAcercamiento(float posBot[3], float posZombie[3], float velZombie[3])
{
    // Vector unitario desde el zombie hacia el bot
    float dirHaciaBot[3];
    dirHaciaBot[0] = posBot[0] - posZombie[0];
    dirHaciaBot[1] = posBot[1] - posZombie[1];
    dirHaciaBot[2] = posBot[2] - posZombie[2];

    float magnitud = GetVectorLength(dirHaciaBot);
    if (magnitud < 1.0) return 999.0;    // Distancia despreciable, se considera encima

    dirHaciaBot[0] /= magnitud;
    dirHaciaBot[1] /= magnitud;
    dirHaciaBot[2] /= magnitud;

    // Producto punto entre velocidad del zombie y la direccion hacia el bot
    return (velZombie[0] * dirHaciaBot[0]) + (velZombie[1] * dirHaciaBot[1]) + (velZombie[2] * dirHaciaBot[2]);
}

// Suma una desviacion aleatoria a los angulos de apuntado segun el nivel de dificultad
void AplicarErrorAngular(float angulos[3])
{
    float error = ObtenerErrorAngular();
    if (error > 0.0)
    {
        angulos[0] += GetRandomFloat(-error, error);
        angulos[1] += GetRandomFloat(-error, error);
    }
}

// Lee la clase de Special Infected del jugador (3=Hunter, 5=Jockey, 6=Charger, 8=Tank, etc.)
int ObtenerClaseZombie(int cliente)
{
    return GetEntProp(cliente, Prop_Send, "m_zombieClass");
}

// Calcula el punto medio entre los pies y los ojos del jugador (centro de masa del modelo)
void ObtenerCentroCuerpo(int cliente, float resultado[3])
{
    float pies[3], ojos[3];
    GetClientAbsOrigin(cliente, pies);
    GetClientEyePosition(cliente, ojos);
    resultado[0] = pies[0];
    resultado[1] = pies[1];
    resultado[2] = (pies[2] + ojos[2]) * 0.5;
}

// =====================================================================
// [4] MENU DE DIFICULTAD
// =====================================================================
public void OnPluginStart()
{
    RegConsoleCmd("sm_dificultad", Cmd_AbrirMenuDificultad, "Abre el menu de dificultad");
}

public Action Cmd_AbrirMenuDificultad(int client, int args)
{
    if (client == 0 || !IsClientInGame(client) || IsFakeClient(client)) return Plugin_Handled;
    Menu menu = new Menu(Handler_MenuDificultad);
    menu.SetTitle("🎯 Nivel de IA (Actual: %d)", g_NivelDificultad);
    menu.AddItem("1", "Amateur (Reaccion 0.5s, Sin deadstop)");
    menu.AddItem("2", "Scrim (Reaccion 0.2s, 75%% deadstop)");
    menu.AddItem("3", "Nivel Hokori (Reaccion 0.0s, Perfecto)");
    menu.Display(client, 30);
    return Plugin_Handled;
}

public int Handler_MenuDificultad(Menu menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_Select)
    {
        char info[32];
        menu.GetItem(param2, info, sizeof(info));
        g_NivelDificultad = StringToInt(info);
        PrintToChatAll("\x04[ProWarmup] \x01Dificultad ajustada al nivel \x04%d", g_NivelDificultad);
    }
    else if (action == MenuAction_End) delete menu;
    return 0;
}

// =====================================================================
// [4.5] CLASIFICACION DE ARMA
// =====================================================================
// Identifica el tipo de arma equipada: 1 = Skeet (disparo unico/burst), 2 = Tracking (automatica), 0 = otra
int ObtenerTipoArma(int client)
{
    int arma = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
    if (arma == -1) return 0;

    char clase[64];
    GetEntityClassname(arma, clase, sizeof(clase));

    // Escopetas y francotiradores: alto dano por disparo, ideales para skeet
    if (StrEqual(clase, "weapon_pumpshotgun") || StrEqual(clase, "weapon_shotgun_chrome") || StrEqual(clase, "weapon_autoshotgun") || StrEqual(clase, "weapon_shotgun_spas") || StrEqual(clase, "weapon_hunting_rifle") || StrEqual(clase, "weapon_sniper_military"))
    {
        return 1;
    }

    // SMGs y rifles de asalto: bajo dano por bala, requieren fuego sostenido
    if (StrEqual(clase, "weapon_smg") || StrEqual(clase, "weapon_smg_silenced") || StrEqual(clase, "weapon_smg_mp5") || StrEqual(clase, "weapon_rifle") || StrEqual(clase, "weapon_rifle_ak47") || StrEqual(clase, "weapon_rifle_desert") || StrEqual(clase, "weapon_rifle_sg552"))
    {
        return 2;
    }

    return 0;
}

// =====================================================================
// [5] LOGICA PRINCIPAL – OnPlayerRunCmd
// =====================================================================
public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
    // Filtrar: solo ejecutar en bots del equipo superviviente que esten vivos
    if (client <= 0 || client > MaxClients) return Plugin_Continue;
    if (!IsClientInGame(client) || !IsFakeClient(client)) return Plugin_Continue;
    if (GetClientTeam(client) != 2 || !IsPlayerAlive(client)) return Plugin_Continue;

    // ──────────────────────────────────────────────────────────────
    // PASO 1: Buscar al infectado mas cercano que no este en modo fantasma
    // ──────────────────────────────────────────────────────────────
    int   objetivoMasCercano = -1;
    float distanciaMinima    = 99999.0;
    float posBot[3];
    GetClientAbsOrigin(client, posBot);

    for (int i = 1; i <= MaxClients; i++)
    {
        if (!IsClientInGame(i) || GetClientTeam(i) != 3 || !IsPlayerAlive(i)) continue;
        if (GetEntProp(i, Prop_Send, "m_isGhost") == 1) continue;

        float posZombie[3];
        GetClientAbsOrigin(i, posZombie);
        float dist = GetVectorDistance(posBot, posZombie);

        if (dist < distanciaMinima)
        {
            distanciaMinima    = dist;
            objetivoMasCercano = i;
        }
    }

    // Sin infectados activos en el mapa
    if (objetivoMasCercano == -1)
    {
        g_iObjetivoDetectado[client] = -1;
        return Plugin_Continue;
    }

    // ──────────────────────────────────────────────────────────────
    // PASO 2: Verificar linea de vision con TR_TraceRay.
    // Si no hay LOS, el bot mira hacia la ultima posicion conocida
    // durante 2 segundos antes de olvidar al objetivo.
    // ──────────────────────────────────────────────────────────────
    float ahora       = GetGameTime();
    bool  tieneVision = TrazarLineaDeVision(client, objetivoMasCercano);

    if (tieneVision)
    {
        // Guardar posicion actual del objetivo como referencia de memoria
        float posActualZombie[3];
        GetClientAbsOrigin(objetivoMasCercano, posActualZombie);
        g_fUltimaPosConocida[client][0] = posActualZombie[0];
        g_fUltimaPosConocida[client][1] = posActualZombie[1];
        g_fUltimaPosConocida[client][2] = posActualZombie[2];
        g_fTiempoUltimaVision[client]   = ahora;
    }
    else
    {
        // Sin vision directa: calcular cuanto tiempo lleva sin verlo
        float tiempoSinVer = ahora - g_fTiempoUltimaVision[client];

        if (tiempoSinVer < 2.0 && g_iObjetivoDetectado[client] != -1)
        {
            // Dentro de la ventana de memoria: mantener la mira en la ultima posicion
            float ojoBot[3], vectorMirada[3], angulosMirada[3];
            GetClientEyePosition(client, ojoBot);

            float posMem[3];
            posMem[0] = g_fUltimaPosConocida[client][0];
            posMem[1] = g_fUltimaPosConocida[client][1];
            posMem[2] = g_fUltimaPosConocida[client][2] + 40.0;

            MakeVectorFromPoints(ojoBot, posMem, vectorMirada);
            GetVectorAngles(vectorMirada, angulosMirada);

            angles[0] = angulosMirada[0];
            angles[1] = angulosMirada[1];
            return Plugin_Changed;
        }
        else
        {
            // Fuera de la ventana de memoria: descartar objetivo
            g_iObjetivoDetectado[client] = -1;
            return Plugin_Continue;
        }
    }

    // ──────────────────────────────────────────────────────────────
    // PASO 3: Aplicar delay de reaccion segun dificultad.
    // Si el objetivo fue rastreado recientemente (salio de cobertura),
    // el bot omite el delay y reacciona al instante.
    // ──────────────────────────────────────────────────────────────
    bool objetivoReAdquirido = false;

    if (g_iObjetivoDetectado[client] != objetivoMasCercano)
    {
        // Verificar si este objetivo estaba en memoria reciente (menos de 3 segundos)
        float tiempoDesdeUltimaVez = ahora - g_fTiempoUltimaVision[client];
        if (tiempoDesdeUltimaVez < 3.0)
        {
            // Objetivo re-adquirido desde memoria: omitir delay
            objetivoReAdquirido = true;
        }

        g_iObjetivoDetectado[client] = objetivoMasCercano;
        g_fTiempoDeteccion[client]   = ahora;
    }

    float tiempoReaccion = ahora - g_fTiempoDeteccion[client];
    float delayRequerido = ObtenerDelayReaccion();

    // Durante el delay, el bot solo gira hacia el objetivo sin actuar
    if (!objetivoReAdquirido && tiempoReaccion < delayRequerido)
    {
        float ojoBot[3], posZTemp[3], vecTemp[3], angTemp[3];
        GetClientEyePosition(client, ojoBot);
        GetClientAbsOrigin(objetivoMasCercano, posZTemp);
        posZTemp[2] += 40.0;
        MakeVectorFromPoints(ojoBot, posZTemp, vecTemp);
        GetVectorAngles(vecTemp, angTemp);
        angles[0] = angTemp[0];
        angles[1] = angTemp[1];
        return Plugin_Changed;
    }

    // ──────────────────────────────────────────────────────────────
    // PASO 4: Leer el estado fisico y la clase del infectado para
    // determinar si representa una amenaza aerea o un rush rapido.
    // ──────────────────────────────────────────────────────────────
    float posZombie[3], ojoBot[3];
    GetClientAbsOrigin(objetivoMasCercano, posZombie);
    GetClientEyePosition(client, ojoBot);

    // Vector de velocidad actual del infectado
    float velZombie[3];
    GetEntPropVector(objetivoMasCercano, Prop_Data, "m_vecVelocity", velZombie);

    // Banderas de estado fisico del infectado
    int  banderasZombie       = GetEntityFlags(objetivoMasCercano);
    bool estaEnSuelo          = (banderasZombie & FL_ONGROUND) != 0;
    bool estaIntentandoPounce = false;

    // Clase de Special Infected (3 = Hunter, 5 = Jockey)
    int  claseZombie          = ObtenerClaseZombie(objetivoMasCercano);

    // Propiedad de red exclusiva del Hunter: indica pounce activo
    if (claseZombie == 3)
    {
        estaIntentandoPounce = (GetEntProp(objetivoMasCercano, Prop_Send, "m_isAttemptingToPounce") == 1);
    }

    // Velocidad vertical negativa indica que el infectado esta cayendo
    bool  estaCayendo    = (velZombie[2] < -50.0);

    // Magnitud total del vector de velocidad del infectado
    float velTotal       = GetVectorLength(velZombie);

    // Evaluar si el infectado es una amenaza aerea
    bool  esAmenazaAerea = false;

    // Hunter ejecutando pounce o en el aire con velocidad alta (pounce horizontal)
    if (estaIntentandoPounce)
        esAmenazaAerea = true;
    else if (claseZombie == 3 && !estaEnSuelo && velTotal > 200.0)
        esAmenazaAerea = true;

    // Jockey en el aire con velocidad > 150 u/s indica un leap activo
    if (claseZombie == 5 && !estaEnSuelo && velTotal > 150.0)
        esAmenazaAerea = true;

    // Cualquier infectado en el aire con velocidad Z negativa esta en caida
    if (!estaEnSuelo && estaCayendo)
        esAmenazaAerea = true;

    // Un infectado acercandose a mas de 300 u/s a menos de 200 unidades es un rush
    float velAcercamiento = CalcularVelocidadAcercamiento(posBot, posZombie, velZombie);
    bool  esRushRapido    = (velAcercamiento > 300.0 && distanciaMinima < 200.0);
    float tiempoImpacto   = 99.0;

    // Tiempo estimado en segundos hasta que el infectado alcance al bot
    if (velAcercamiento > 1.0)
    {
        tiempoImpacto = distanciaMinima / velAcercamiento;
    }

    // ──────────────────────────────────────────────────────────────
    // PASO 5: Calcular los angulos de apuntado con prediccion de
    // movimiento para objetivos aereos y offset de altura.
    // ──────────────────────────────────────────────────────────────
    float vectorApuntado[3], anguloPerfecto[3];

    // Punto de mira base: posicion del infectado con offset vertical
    float posMira[3];
    posMira[0] = posZombie[0];
    posMira[1] = posZombie[1];

    if (esAmenazaAerea)
    {
        // Amenaza aerea: apuntar al centro de masa (offset bajo)
        posMira[2] = posZombie[2] + 20.0;

        // Anticipar la posicion futura del infectado segun su velocidad
        if (tiempoImpacto < 1.0 && tiempoImpacto > 0.0)
        {
            float tPrediccion = tiempoImpacto * 0.5;
            posMira[0] += velZombie[0] * tPrediccion;
            posMira[1] += velZombie[1] * tPrediccion;
            posMira[2] += velZombie[2] * tPrediccion;
        }
    }
    else
    {
        // Objetivo en suelo: apuntar al torso (offset alto)
        posMira[2] = posZombie[2] + 40.0;
    }

    MakeVectorFromPoints(ojoBot, posMira, vectorApuntado);
    GetVectorAngles(vectorApuntado, anguloPerfecto);
    AplicarErrorAngular(anguloPerfecto);

    // ──────────────────────────────────────────────────────────────
    // PASO 6: Decidir la accion del bot segun la situacion.
    // Se evaluan las prioridades de mayor a menor urgencia.
    // ──────────────────────────────────────────────────────────────

    // Angulo directo al centro real del cuerpo del infectado (sin prediccion)
    // Se usa exclusivamente para el empuje, cuyo cono requiere precision exacta
    float centroZombie[3], vecEmpuje[3], anguloEmpuje[3];
    ObtenerCentroCuerpo(objetivoMasCercano, centroZombie);
    MakeVectorFromPoints(ojoBot, centroZombie, vecEmpuje);
    GetVectorAngles(vecEmpuje, anguloEmpuje);

    // ── PRIORIDAD 1: Empuje defensivo contra amenaza inminente ──
    // Excluye al Hunter (clase 3) porque en ZoneMod no se permite empujarlo
    if ((esAmenazaAerea || esRushRapido) && claseZombie != 3)
    {
        bool empujarAhora = false;

        // El infectado impactara al bot en menos de 0.3 segundos
        if (tiempoImpacto < 0.3)
            empujarAhora = true;

        // El infectado esta a menos de 90 unidades del bot
        if (distanciaMinima < 90.0)
            empujarAhora = true;

        // Rush a alta velocidad con el infectado a menos de 150 unidades
        if (esRushRapido && distanciaMinima < 150.0)
            empujarAhora = true;

        if (empujarAhora && IntentarDeadstop())
        {
            // Apuntar al centro real del cuerpo para conectar el cono del empuje
            angles[0] = anguloEmpuje[0];
            angles[1] = anguloEmpuje[1];
            buttons |= IN_ATTACK2;
            return Plugin_Changed;
        }
    }

    // ── PRIORIDAD 2: Empuje de emergencia a quemarropa ──
    // Cualquier infectado (excepto Hunter) a menos de 75 unidades
    if (distanciaMinima < 75.0 && claseZombie != 3)
    {
        if (g_NivelDificultad >= 2 || (g_NivelDificultad == 1 && distanciaMinima < 50.0))
        {
            angles[0] = anguloEmpuje[0];
            angles[1] = anguloEmpuje[1];
            buttons |= IN_ATTACK2;
            return Plugin_Changed;
        }
    }

    // ── PRIORIDAD 3: Combate contra Hunter aereo segun tipo de arma ──
    // Escopetas/snipers disparan en el sweet spot, automaticas mantienen fuego continuo
    if (claseZombie == 3 && esAmenazaAerea)
    {
        int tipoArma = ObtenerTipoArma(client);

        angles[0]    = anguloPerfecto[0];
        angles[1]    = anguloPerfecto[1];

        if (tipoArma == 1)
        {
            // Arma de burst: retener el disparo hasta el rango optimo (70-180 unidades)
            buttons &= ~IN_ATTACK;

            if (distanciaMinima >= 70.0 && distanciaMinima <= 180.0 && velAcercamiento <= 250.0)
            {
                // Hunter dentro del sweet spot a velocidad moderada: disparar
                buttons |= IN_ATTACK;
            }
            else if (distanciaMinima >= 70.0 && distanciaMinima <= 180.0 && velAcercamiento > 250.0)
            {
                // Hunter a alta velocidad: esperar al ultimo instante para maximizar dano
                if (tiempoImpacto < 0.15)
                    buttons |= IN_ATTACK;
            }
        }
        else if (tipoArma == 2)
        {
            // Arma automatica: fuego sostenido para acumular dano en el aire
            if (distanciaMinima < 1000.0)
                buttons |= IN_ATTACK;
        }
        else
        {
            // Pistola u otra arma: disparo continuo a rango medio
            if (distanciaMinima < 800.0)
                buttons |= IN_ATTACK;
        }

        return Plugin_Changed;
    }

    // ── PRIORIDAD 4: Apuntar y disparar a cualquier infectado a rango medio ──
    if (distanciaMinima < 800.0)
    {
        angles[0] = anguloPerfecto[0];
        angles[1] = anguloPerfecto[1];

        // Solo disparar si no esta en rango de empuje (evitar conflicto de acciones)
        if (distanciaMinima > 75.0)
        {
            // Dificultad Amateur: cadencia reducida (1 de cada 3 ticks)
            if (g_NivelDificultad == 1)
            {
                if (GetRandomInt(1, 3) == 1) buttons |= IN_ATTACK;
            }
            else
            {
                buttons |= IN_ATTACK;
            }
        }

        return Plugin_Changed;
    }

    // ── PRIORIDAD 5: Rastrear y disparar a amenazas aereas lejanas ──
    if (esAmenazaAerea && distanciaMinima < 1500.0)
    {
        angles[0] = anguloPerfecto[0];
        angles[1] = anguloPerfecto[1];

        if (g_NivelDificultad >= 2) buttons |= IN_ATTACK;

        return Plugin_Changed;
    }

    return Plugin_Continue;
}

// =====================================================================
// [6] FILTRO DE ENTIDADES PARA EL TRAZADO DE RAYO
// =====================================================================
// Determina que entidades debe ignorar el rayo al evaluar linea de vision
public bool FiltroVision(int entity, int contentsMask, any data)
{
    // El rayo atraviesa al propio bot que lo lanza
    if (entity == data) return false;

    // El rayo atraviesa a los compañeros supervivientes del bot
    if (entity > 0 && entity <= MaxClients)
    {
        if (IsClientInGame(entity) && GetClientTeam(entity) == 2)
        {
            return false;
        }
    }

    // El rayo colisiona con todo lo demas: paredes, props, vehiculos, infectados
    return true;
}

// =====================================================================
// [7] IA INFECTADOS (Reservado para la Fase 2)
// =====================================================================