# World Labour Values Database — aviso sobre esta versión

La documentación mantenida se encuentra en [portugués](README-PT.md) y
[inglés](README.md). Para consultar los datos, acceda a
[World Labour Values](https://panel.worldlabourvalues.org/) o a
[LabCidades/UFES](http://labcidades.ufes.br/worldlabourvalues/).

El contenido conservado a continuación es histórico: no define las capacidades,
las referencias bibliográficas ni las instrucciones vigentes. Utilice los
manuales mantenidos para consultar, reproducir o ampliar el proyecto.

## Texto histórico

Open Science Project para desarrollar, implementar y mejorar las metodologías para valores (marxistas, sraffianos ...) y estimaciones de categorias basadas en información pública de  Matrices de Insumo y Producto Mundiales, Klems, Datos de Eclal IO. Extensiones adicionales para incluir exiobase, las mejores estimaciones disponibles para más países. 

Al usar los datos, rogamos citar: 

FRANKLIN, R.;BORGES, R,; SÁNCHEZ, C.; MONTIBELER, E. Skilled labour and the reduction problem: questioning the exploitation rate equalization hypoyhesis. _World Review of Political Economy_ (en prensa), 2022.

También incluye estimaciones preliminares sobre: 

- Intercambio desigual; 
- Tasas de explotación; 
- Tasas de beneficio; 
- Diferentes enfoque a los valores: precios directos, valores en tiempo de trabajo abstracto, precios sraffianos,

## Soporte de métodos y fuentes

La cobertura temporal y las operaciones disponibles se publican en la
[matriz canónica de soporte](docs/methods.md). WIOD13 y WIOD16 son las familias
recuperadas; `wiodr13` y `wiodr16` son los únicos métodos ejecutables en esta
entrega. Las definiciones alternativas se conservan para incorporarlas más
adelante, con cálculo y recálculo bloqueados incluso con habilitación experimental.
Las fuentes EXIOBASE y EORA son experimentales,
y sus métodos permanecen deshabilitados hasta completar su recuperación.
 
## Inicio seguro y función principal

Abrir el proyecto no instala paquetes, no actualiza el checkout Git, no
restaura un espacio de trabajo guardado y no inicia cálculos. Desde la raíz del
repositorio, restaure una vez las versiones exactas de los paquetes y ejecute
un método explícitamente. Puede usar el editor o terminal que prefiera;
el flujo no depende de un IDE y sus ajustes personales no se versionan:

```sh
Rscript --vanilla scripts/bootstrap.R
Rscript --vanilla scripts/run_wlv.R --method wiodr13
```

El bootstrap restaura `renv.lock`; no descarga los datos económicos de origen.
Para trabajar de forma interactiva después del bootstrap, active la biblioteca
del proyecto y cargue las funciones principales explícitamente:

```r
source("renv/activate.R")
bootstrap <- new.env(parent = baseenv())
sys.source("scripts/runtime_bootstrap.R", envir = bootstrap)
wlv <- bootstrap$wlv_load_runtime(".")
wlv$get_wlv("wiodr13")
```

Use `Rscript --vanilla scripts/run_wlv.R --help` para ver todas las opciones de
línea de comandos, o agregue `--check` para validar el entorno y el método sin
iniciar cálculos.
 
 ### Función get_wlv  
 
La función ** get_wlv **  es una función que ejecuta todos los cálculos y genera archivos con las estimaciones en la carpeta de resultados con todas las variables y matrices, sectoriales (M_IO, y m_countries) , y cuentas socioeconómicas del país y sectoriales (sea_Countries y sea_Sectors) correspondientes a las estimaciones no ortodoxas. 

Por ejemplo, para calcular el método estándar actual con WIOD13, ejecute
`wlv$get_wlv("wiodr13")` en el runtime privado devuelto por el bootstrap.
`scripts/main.R` contiene definiciones y no debe cargarse directamente.

La función acepta los siguientes argumentos: 

* methods: una cadena o un vector de caracteres como `c("wiodr13", "wiodr16")`, especificando los métodos a calcular o recalcular. Por defecto, `"wiodr13"`
* repeat_pp : Verdadero / Falso para indicar si se debe ejecutar la preparación completa de descarga y datos de origen. Por defecto, falso .
* papern, prepaper: argumentos retirados, conservados únicamente con sus valores predeterminados (`0`, `FALSE`) para compatibilidad; se eliminó la generación de papers y los intentos de activarla fallan antes del cálculo
* workers: entero positivo que controla los workers PSOCK. El valor predeterminado es `1`, que ejecuta secuencialmente sin crear un clúster
* channel: canal de publicación en minúsculas, como `stable` o `research/input-v3`
* allow_experimental: habilitación explícita de capacidades experimentales; no habilita métodos cuyo cálculo o recálculo esté bloqueado

## Estructura / organización de la carpeta del repositorio 

### 1) source_data - a descargar por separado - [Enlace aquí] (https://coletiva.imperialismedependencia.org/s/wjmfkbxdnptadxf) 

Carpeta con datos descargados de fuentes primarias de productos de entrada en subcarpetas de acuerdo con la fuente. También se formatean los datos en esta carpeta para mantener una estructura tratable de diferentes fuentes para el mismo flujo de procesamiento. 

### 2) Catálogo y configuración

`catalog/` declara fuentes, métodos, capacidades, perfiles de validación y
contratos públicos. `config/modules/` compone instancias nativas de método,
fuente y `common` mediante operaciones tipadas `add`, `replace` y `remove`.
`config/aggregations/` declara los perfiles históricos de agregación. Los CSV
contienen únicamente identificadores y argumentos tipados; no contienen rutas
ejecutables, expresiones R ni orden semántico.

### 3) methods

 El primer artículo producido, referido, muestra cómo se puede trabajar la misma fuente con diferentes métodos. En este caso, diferentes métodos para convertir el tiempo de trabajo concreto para el tiempo de trabajo abstracto. 
 
 Una de las características de la  Base de Datos de Valores Trabajo Mundiales es la facilidad de crear, aplicar y comparar diferentes métodos para la estimación de indicadores de categorías. Como tal, proporciona complemento subsidiario a las discusiones teóricas. 
 
Las subcarpetas en `methods/` contienen metadatos, parámetros y clasificaciones
sectoriales. El comportamiento científico ejecutable se registra como
funciones nativas en `scripts/modules/native/`; el orden lo determina el grafo de
dependencias compilado, nunca la posición de las filas en los CSV.
 
 

### 4) results - a descargar por separado si se desea verificar los resultados ya producidos por nuestro equipo - [enlace aquí] https://coletiva.imperialismodependecia.org/s/nmmdymxl8fwxfjq) 

Los resultados son runs inmutables en `results/runs/<método>/<run_id>/`.
Las releases de `results/releases/` fijan conjuntos coherentes y los marcadores
append-only de `results/channels/<canal>/` seleccionan la release vigente.

### 5) scripts

`scripts/` reúne el código de la aplicación y los comandos de mantenimiento.
`scripts/bootstrap.R` restaura los paquetes; `scripts/runtime_bootstrap.R`
carga el entorno privado de ejecución.

El bootstrap determinista carga definiciones de función de `scripts/lib/`,
`scripts/modules/native/`, `scripts/preparation/` y `scripts/main.R` en un único namespace
privado y bloqueado. Los módulos científicos reciben entradas, argumentos y
servicios inyectados mediante un contexto explícito; los ejecutores legacy
basados en `source()` no forman parte del runtime alcanzable.

### 6) tests y campañas locales

`tests/` contiene código de pruebas y datos de ejemplo controlados (*fixtures*)
versionados para detectar regresiones. Los resultados generados, logs y
experimentos locales pertenecen a `temp/<id>/`, ignorado por Git. Consulte
[campañas y limpieza local](docs/local-campaigns.md). La campaña preservada
`temp/054/` no debe volver a ejecutarse, modificarse ni eliminarse.
