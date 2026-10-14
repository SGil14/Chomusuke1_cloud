# Chomusuke

Aplicación web para consultar la lluvia en tiempo real en Bogotá, por localidad o por destino (barrio o dirección), con histórico propio para análisis.

**Fuente de datos:** pluviómetros del SAB / IDIGER, los mismos de https://app.sab.gov.co/sab/lluvias.htm.

## Estado

| Fase | Contenido | Estado |
|---|---|---|
| 1 | Backend base: cliente SAB, lógica de lluvia, API, PostgreSQL y recolector | ✅ |
| 2 | Geocodificación: Catastro (direcciones y esquinas) + Nominatim (lugares), barrio, caché y registro de consultas | ✅ |
| 3 | Frontend: React + Vite + MapLibre, diseño «Radar nocturno» (celular y computador, tema oscuro y claro) | ✅ |
| 4 | Análisis: estadísticas y gráficos del histórico | ⏳ |
| 5 | Extras: radar, histórico IDEAM, Docker | ⏳ |

## Estructura

```
consulta_lluvia/
├── backend/
│   ├── app/
│   │   ├── main.py              # Arranque de FastAPI
│   │   ├── config.py            # Configuración (.env)
│   │   ├── api/routes/          # Endpoints
│   │   ├── services/            # Cliente SAB, reglas de lluvia, geocodificación
│   │   ├── repositories/        # Lectura y escritura en PostgreSQL
│   │   ├── db/                  # Conexión y tablas
│   │   ├── jobs/recolector.py   # Guarda el histórico cada 5 minutos
│   │   ├── models/schemas.py    # Modelos de datos
│   │   └── core/                # Caché y zona horaria
│   ├── alembic/                 # Migraciones de la base
│   └── tests/
├── frontend/                    # React + Vite + TypeScript + MapLibre
│   └── src/{components,hooks,lib,styles}
├── Abrir Chomusuke.bat      # Un clic: compila el front si falta y abre la app
├── .env.example
└── README.md
```

## Diseño del frontend

Hay **varios diseños intercambiables**: el botón «Diseño» de la barra superior cambia entre ellos y recuerda el último.
Cada diseño es un archivo CSS autocontenido en `frontend/src/disenos/` más su paleta del mapa en `disenos/index.ts`;
para agregar uno nuevo basta con crear su `.css` y registrarlo en la lista `DISENOS`.

| Diseño | Estado | Idea |
|---|---|---|
| **Clima** (por defecto) | ✅ | App del tiempo amigable: cielo claro o noche azul, tarjetas redondeadas, sol amarillo para lo seco y azul para la lluvia. |
| Tablero | ✅ | Grafito + verde limón, tipografía condensada, bloques sólidos. |
| **Radar** | ✅ | Consola meteorológica: panel lateral delgado y denso, datos en monoespaciada, anillos de alcance centrados en el radar, estaciones como anillos huecos que se llenan con los colores del radar (verde, amarillo, naranja, rojo). |
| **Minimalista** | ✅ | Casi sin adornos: el mapa, una frase («7 de 71 estaciones con lluvia») y una barra de búsqueda en píldora; la respuesta es una sola frase y las localidades se despliegan solo con «Ver localidades». |
| **Mapa vivo** | ✅ | El mapa lo es todo: cielo que cambia según llueva o no, **lluvia animada** que cae solo sobre las zonas con eco del radar y alrededor de las estaciones que registran lluvia, y tarjetas de cristal abajo a la izquierda. |

Todos comparten la misma estructura y lógica (`components/`, `hooks/`, `lib/`): la experiencia no cambia, solo el estilo.
La primera versión (serif elegante, azul y magenta) quedó guardada en `frontend/_respaldo_diseno_v1/`.

**Radar:** el botón «Radar» muestra sobre el mapa la imagen de reflectividad del radar meteorológico del IDIGER (la misma
capa de la página del SAB). Es **lluvia en el aire**, no en el suelo, así que puede no coincidir con los pluviómetros:
- Por eso **arranca apagado** (se recuerda lo que elijas) y, al encenderlo, solo dibuja los ecos de lluvia **moderada o más
  fuerte** (amarillo, naranja, rojo); la llovizna y los ecos débiles (verde, cian, azul) se descartan.
- El 14 de octubre, con 0 de 71 estaciones con lluvia, el radar marcaba 267 puntos de eco, casi todos débiles y 251 de ellos a
  más de 3 km de cualquier estación (fuera de la zona que cubren los pluviómetros): no se pueden comprobar.
- Sirve para ver lluvia **entre** estaciones y **fuera** de la ciudad, y de dónde viene. Lo que manda para decir «llueve aquí»
  son siempre las estaciones.
- El backend lo descarga del KMZ público, lo guarda 2 minutos en caché y lo entrega en `/api/radar`. Si falla, la app sigue
  funcionando sin él.

La app no se actualiza sola: solo al abrir o al pulsar «Actualizar».

**Lluvia animada (Mapa vivo):** `frontend/src/lib/lluviaViva.ts` toma las estaciones con lluvia (y, si el radar está encendido, sus ecos moderados o fuertes), calcula la intensidad por color y dibuja gotas en un canvas sobre el mapa (más gotas y más largas cuanto más fuerte llueve). Respeta «reducir movimiento» del sistema.

## Base de datos

| Tabla | Contenido |
|---|---|
| `estaciones` | Catálogo de pluviómetros: nombre, localidad, coordenadas |
| `lecturas` | Histórico: una fila por estación y hora de lectura (sin duplicados) |
| `geocache` | Destinos ya geocodificados |
| `consultas` | Registro de cada búsqueda de destino |

## Uso rápido

Doble clic en **`Abrir Chomusuke.bat`**: compila el front la primera vez, abre el navegador y levanta todo en
http://localhost:8000 (requiere PostgreSQL encendido).

## Puesta en marcha (desarrollo)

Requisitos: Python 3.12, PostgreSQL y Node.js (para el front).

```bash
# 1. Crear la base y el usuario en PostgreSQL (una sola vez)
#    CREATE ROLE lluvia_app LOGIN PASSWORD '...';
#    CREATE DATABASE lluvia_bogota OWNER lluvia_app;

# 2. Configuración
copy .env.example .env      # y completar DATABASE_URL

# 3. Backend
cd backend
python -m venv .venv
.venv\Scripts\pip install -r requirements.txt
iniciar.bat                 # aplica migraciones y levanta la API en :8000
```

- Frontend en desarrollo (recarga en vivo): en otra terminal, `cd frontend`, `npm install`, `npm run dev` → http://localhost:5173
  (reenvía `/api` al backend en :8000).
- Frontend para producción: `npm run build` genera `frontend/dist`, que el backend sirve solo.
- Documentación interactiva de la API: http://localhost:8000/docs
- Pruebas: `.venv\Scripts\python -m pytest`

## API

| Endpoint | Descripción |
|---|---|
| `GET /api/health` | Estado de la app y de la base |
| `GET /api/estaciones` | Las estaciones con su estado actual |
| `GET /api/resumen` | Dónde llueve ahora y acumulado por localidad |
| `GET /api/cercanas?lat=&lon=` | Estaciones más cercanas a un punto |
| `GET /api/radar` | Imagen del radar del IDIGER (PNG transparente) y la zona que cubre |
| `GET /api/localidades` | Contorno de las localidades (GeoJSON) para dibujar el mapa |
| `GET /api/historial/serie?periodo=&localidad=` | Cuánto llovió en cada intervalo (por hora en 6h/24h, por día en 7d/30d), para toda Bogotá o una localidad |
| `GET /api/historial/ranking?periodo=` | Localidades ordenadas por lo que llovió en el periodo |
| `GET /api/historial/destino?lat=&lon=&periodo=` | Cuándo llovió cerca de un punto (las 3 estaciones más cercanas) |
| `GET /api/ruta?origen=&destino=&modo=` | Trayecto de un lugar a otro (auto, bus, bicicleta, a_pie) y en qué tramos llueve ahora |
| `GET /api/destino?q=` | Destino por localidad, coordenadas, barrio, lugar o dirección: ubicación, barrio y lluvia cercana |

Con `?actualizar=true`, `/estaciones` y `/resumen` ignoran la caché y consultan el SAB en ese momento.

## Reglas de clasificación

**Intensidad actual** (mm en 5 min × 12 = mm/h): ligera < 2.5, moderada < 7.6, fuerte < 50, muy fuerte ≥ 50.

**Acumulado del día** (escala del SAB): bajo ≤ 10 mm, moderado ≤ 30, alto ≤ 50, muy alto > 50.

Una lectura con más de 30 minutos de antigüedad se marca como desactualizada y no cuenta como lluvia activa.

## Historial de lluvia

Botón **«Historial»** de la barra (y el enlace «Ver cuándo ha llovido aquí» de cada respuesta): gráfico de barras de la lluvia por
hora (6 h y 24 h) o por día (7 d y 30 d), para toda Bogotá, una localidad o las estaciones cercanas a un destino, con el
ranking de localidades.

- **Por hora** se calcula con la diferencia entre lecturas del acumulado del día (no importa si llegan cada 2 o 5 minutos);
  **por día**, con el máximo acumulado de cada estación. Para una localidad se promedian sus estaciones.
- Si la app estuvo apagada, el intervalo aparece como **«sin datos»**: no se inventa lluvia ni se asume que no llovió.
- El histórico solo se llena mientras la app está encendida (recolector); la pantalla muestra cuántos datos hay (`% disponibles`
  y desde cuándo hay registros).

## Ruta de un lugar a otro

Debajo del buscador: «¿Vas de un lugar a otro? Revisa la ruta». Calcula el trayecto con **Valhalla** (gratuito, de
OpenStreetMap; carro/moto, bus, bici o a pie), lo parte en puntos cada 400 m y mira en cada uno la estación de lluvia más
cercana: **lluvia**, **seco** o **sin datos** (si queda a más de 4 km de toda estación o su lectura es vieja). El mapa pinta
cada tramo de su color y el panel resume dónde puede mojarte. Muestra la lluvia **de ahora**, no la que habrá cuando llegues.

## Búsqueda de destinos

`/api/destino?q=...` resuelve el texto en este orden:

1. **Localidad** ("Chapinero"): usa las estaciones de esa localidad, sin salir a internet.
2. **Coordenadas** ("4.6486, -74.0628").
3. **Barrio, lugar, dirección o esquina**, con este orden de proveedores:
   1. Caché en PostgreSQL (`geocache`).
   2. **IDECA**: solo si hay `IDECA_API_KEY` (opcional, ver abajo).
   3. **Catastro (placas domiciliarias)**: gratis y sin clave. Entiende la nomenclatura bogotana:
      `Carrera 7 # 55-25`, `Calle 63 Sur # 80-15`, `Carrera 90 bis # 130-44` y esquinas como
      `Calle 72 con Carrera 10` o `Av Boyacá con Calle 80` (reconoce Boyacá, Caracas, NQS, Autopista Norte,
      Séptima, Ciudad de Cali y El Dorado). Si el número exacto no existe, usa la placa más cercana de la
      misma cuadra y marca el resultado como **aproximado**.
   4. **Nominatim** (OpenStreetMap): lugares, parques, centros comerciales y barrios ("Portal 80", "Galerías").

El barrio y la localidad salen de las capas públicas de Catastro (sector catastral y localidad), sin clave.
Cada búsqueda queda en `consultas` y cada destino resuelto en `geocache`.
Si un proveedor falla (red), la API responde 503 para reintentar en vez de decir que el destino no existe.

**IDECA (opcional):** el geocodificador oficial exige una API key gratuita que entrega IDECA
(https://mapas.bogota.gov.co/api/). Usa los mismos datos de placas que el proveedor de Catastro, así que hoy no
es necesaria; si se consigue, se pone en `IDECA_API_KEY` del `.env` y se activa sola, sin tocar código.
