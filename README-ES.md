#Resumo 

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
recuperadas; sus métodos de referencia son estables y los métodos alternativos
siguen siendo experimentales. Las fuentes EXIOBASE y EORA son experimentales,
y sus métodos permanecen deshabilitados hasta completar su recuperación.
 
## Inicio seguro y función principal

Abrir el proyecto no instala paquetes, no actualiza el checkout Git, no
restaura un espacio de trabajo guardado y no inicia cálculos. Desde la raíz del
repositorio, restaure una vez las versiones exactas de los paquetes y ejecute
un método explícitamente:

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
sys.source("R/bootstrap.R", envir = bootstrap)
wlv <- bootstrap$wlv_load_runtime(".")
wlv$get_wlv("wiodr13")
```

Use `Rscript --vanilla scripts/run_wlv.R --help` para ver todas las opciones de
línea de comandos, o agregue `--check` para validar el entorno y el método sin
iniciar cálculos.
 
 ### Función get_wlv  
 
La función ** get_wlv **  es una función que ejecuta todos los cálculos y genera archivos con las estimaciones en la carpeta de resultados con todas las variables y matrices, sectoriales (M_IO, y m_countries) , y cuentas socioeconómicas del país y sectoriales (sea_Countries y sea_Sectors) correspondientes a las estimaciones no ortodoxas. 

Por ejemplo, para calcular el método estándar actual con WIOD13, ejecute
`get_wlv("wiodr13")` después de cargar `R/main.R`.

La función acepta los siguientes argumentos: 

* methods: una cadena o un vector de caracteres como `c("wiodr13", "wiodr16")`, especificando los métodos a calcular o recalcular. Por defecto, `"wiodr13"`
* repeat_pp : Verdadero / Falso para indicar si se debe ejecutar la preparación completa de descarga y datos de origen. Por defecto, falso .
* papern : referencia al número del paper sobre el que computar  tablas y / o gráficos que comparen diferentes métodos, indicadores transversales y longitudinales, es decir, cualquier análisis personalizado que se incluye en análisis identificado por ese número. 
* prepaper: Verdadero / Falso: si se debe ejecutar, de hecho, la preparación de dicho análisis personalizado (realizando la llamada correspondiente en el script de la carpeta *papers*) 
* workers: entero positivo que controla los workers PSOCK. El valor predeterminado es `1`, que ejecuta secuencialmente sin crear un clúster

## Estructura / organización de la carpeta del repositorio 

### 1) source_data - a descargar por separado - [Enlace aquí] (https://coletiva.imperialismedependencia.org/s/wjmfkbxdnptadxf) 

Carpeta con datos descargados de fuentes primarias de productos de entrada en subcarpetas de acuerdo con la fuente. También se formatean los datos en esta carpeta para mantener una estructura tratable de diferentes fuentes para el mismo flujo de procesamiento. 

### 2) parameters

Algunos pocos parámetros en archivos CSV para una fácil edición, organizados en subcarpetas, una para parámetros globales, o comunes a todas fuentes (subcarpeta *common_ground* ) y parámetros generales para cada fuente principal de IO, por ejemplo, "WIOD13".  En general, Los siguientes archivos: 

* _source_assumptions.csv - indica cómo tratar la estimación de información importante (y ausente de la fuente), actualmente respecto al trabajo en el resto del mundo y China 
* _source_matrices.csv - indica cómo tratar principalmente a matrices de capital y depreciación 
* _source_solutions.csv: indica como calcular las variables, llamando a los scripts correspondientes (o , de ser muy sencilla, directamente la operación aritmética) , utilizados uno a uno por defecto en caso de no indicarse distintamente en método específico

### 3) methods

 El primer artículo producido, referido, muestra cómo se puede trabajar la misma fuente con diferentes métodos. En este caso, diferentes métodos para convertir el tiempo de trabajo concreto para el tiempo de trabajo abstracto. 
 
 Una de las características de la  Base de Datos de Valores Trabajo Mundiales es la facilidad de crear, aplicar y comparar diferentes métodos para la estimación de indicadores de categorías. Como tal, proporciona complemento subsidiario a las discusiones teóricas. 
 
 Las subcarpetas en los métodos se refieren a un método específico. 
 
 Su estructura es similar a la de parámetros:
* _methods_assumptions.csv - indica cómo tratar la estimación de información importante (y ausente de la fuente), actualmente respecto al trabajo en el resto del mundo y China . Si se especifica, tiene preferencia respecto a lo definido en parameters.
* _methods_matrices.csv - indica cómo tratar principalmente a matrices de capital y depreciación . Si se especifica, tiene preferencia respecto a lo definido en parameters.
* _methods_solutions.csv: indica como calcular las variables, llamando a los scripts correspondientes (o , de ser muy sencilla, directamente la operación aritmética) . Si se especifica, tiene preferencia respecto a lo definido en parameters.
 
 

### 4) results - a descargar por separado si se desea verificar los resultados ya producidos por nuestro equipo - [enlace aquí] https://coletiva.imperialismodependecia.org/s/nmmdymxl8fwxfjq) 

Los resultados de la Los cálculos se guardan como archivos en subcarpetas nombrados por el método que los generó. Las variables se guardan en: M_IO (en valores, por ejemplo, por) por sector o nacional (m_countries), Cuentas socioeconómicas sectoriales (SEA_SECTORS) y nacionales (SEA_COUNTRIES) .

### 5) papers 

1 archivo (principal, al menos) de script para cada análisis, o artículo, identificado por un número. 

Para casi la totalidad de los análisis  generalmente se requiere un nuevo procesamiento de los resultados, dado su volumen:  indicadores, regiones y o sectores y métdoso, nuevos cálculos se pueden filtrar, ver, por ejemplo, el ensayo referido. 

### 6) scripts

Carpeta de scripts con scripts en R, organizado en:

- lib
- modules
  - assumptions
  - matrices
  - reduced_matrices
  - variables
-utils

 Cada subcarpeta está estructurada en scripts y por fuente o método.
