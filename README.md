# qwprefetch
dicom qido wado url prefetch



## Funciones

Proxy entre un pacs dicomweb y una estación de trabajo especializada dicom, que permite prefetch.

La aplicación está subdividida en dos procesos:

### primer proceso

- qido / wado que alimenta un directorio spool
- storescu que encuentra los nuevos objetos dentro del spool y los manda a la estación de trabajo.

La selección de los objetos está definida por:
- un url
- una lista de instituciones
- una fecha

- Se repiten periodicamente las invocaciones de la composición de estos filtros, 
- se comparan las listas obtenidas con los objetos ya presentes en el directorio spool 
- y se descargan por wado los objetos no encontrados en el spool

### segundo proceso

storescu igualmente análisa el spool para encontrar los objetos todavía no recibidos por la estación de trabajo y enviarlos.



## Estructura del spool

- transfer syntax

   - institución

      - día (aaaammdd)

        - euid (Study Instance UID)

          - iuid (SOP InstanceUID inicialmente con extensión ".dcm", y luego con extensión ".done" o ".bad" depediendo del éxito del envio a la estación de trabajo) 

        

## Comando qwprefetch

```
qwprefetch qidourl institucion.json spoolDir [date]
```

El cuarto argumento es opcional. Si no está presente, por defecto se selecciona el día de hoy.

El json del segundo argumento tiene el formato siguiente:

```json
{
   "asseX":"CHCCL^Nodo",
   "asseY":"*",
   ...
}
```

Los key/value del array contienen la institución realizadora de las imágenes y la institución responsable de informarlas o * si se trata de todas las imágenes seleccionadas por el url + institución realizadora de las imágenes.



## Comando storescu

https://support.dcmtk.org/docs/storescu.html


```
/usr/local/bin/storescu +sd +r +sp *.dcm +rn -R +C -xv -aet [aetSource] -aec [aetDest] IPDest portDest spoolDirPath/-xv
```

SpoolFolder está subdividido por transfer syntax. Conviene ejecutar un storescu con el parametro de transfer syntax propuesto (-xv -xs -xe -xi) correspondiente al nombre de la subdivisión.

| argumento     | descripción                                                                                                                   |
| --------------- | ----------------------------------------------------------------------------------------------- |
| +sd                | scan directory one level                                                                                                |
| +r                   | recurse                                                                                                                          |
| +sp                | scan pattern                                                                                                                   |
| "*.dcm"          | /files ending with .dcm                                                                                                  |
| +rn                 | rename with .done or .bad (ignore these files on the next execution)                           |
| -R                   | only required                                                                                                                  |
| +C                   | combine TS                                                                                                                   |
| -xv -xs -xe -xi | propose JPEG 2000 lossless jpeg lossless, explicit little endian, implicit little endian |
| -aet                 | local aet                                                                                                                         |
| qwprefetch     | value associated with qido request                                                                               |
| -aec                |  remote aet                                                                                                                    |
| xxx                  | aet de destino                                                                                                               |
| ip                    |                                                                                                                                        |
| puerto             |                                                                                                                                       |
