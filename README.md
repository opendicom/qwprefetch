# qwprefetch
dicom qido wado url prefetch



## Funciones

Proxy between un pacs dicomweb y una estación de trabajo especializada dicom, que permite prefetch.

La aplicación está subdividida en dos procesos:

- qido / wado que alimenta un directorio spool
- storescu que encuentra los nuevos objetos dentro del spool y los manda a la estación de trabajo.

La selección de los objetos está definida por una lista de una o más urls qido de nivel instancia.

Se repiten periodicamente las invocaciones de estas urls, se comparan las listas obtenidas con los objetos ya presentes en el spool y se descargan por wado los objetos no encontrados en el spool.

storescu igualmente análisa el spool para encontrar los objetos todavía no recibidos por la estación de trabajo y enviarlos.



## Estructura del spool

- aetSource

  - día (aaaammdd)

    - euid (Study Instance UID)

      - iuid (SOP InstanceUID inicialmente sin extensión, y luego con extensión ".done" o ".bad" depediendo del éxito del envio a la estación de trabajo) 

        

## Comando qwprefetch

```
qwprefetch qidosJsonPath spoolDirPath [aaaammdd]
```

El tercer argumento es opcional. Si no está presente, por defecto se selecciona el día de hoy.

El json del primer argumento tiene el formato siguiente:

```json
{
   "https://serviciosridi.asse.uy/dcm4chee-arc/qido/DCM4CHEE/instances?Modality=MG&00080080=asseX&00081060=asseX&StudyDate=":"aetSource",

   ...

}
```

Los key/value del array contienen el aetSource y el url correspondiente.



## Comando storescu

https://support.dcmtk.org/docs/storescu.html

Para cada aetSource

```
/usr/local/bin/storescu +sd +sp *.dcm +rn -xv -aet [aetSource] -aec [aetDest] IPDest portDest spoolDirPath/aetSource
```

| argumento   | descripción                                                  |
| ----------- | ------------------------------------------------------------ |
| +sd         | scan directory one level                                     |
| +r          | recurse                                                      |
| +sp         | scan pattern                                                 |
| "*.dcm"     | /files ending with .dcm                                      |
| +rn         | rename with .done or .bad (ignore these files on the next execution) |
| -R          | only required                                                |
| -xv         | propose JPEG 2000 lossless TS and all uncompressed transfer syntaxes |
| -aet        | local aet                                                    |
| [aetSource] | value associated with qido request                           |
|             |                                                              |
|             |                                                              |
|             |                                                              |
|             |                                                              |
|             |                                                              |



  aet,   //=first segment of path

  @"-aec", //aet of called pacs

  aec,   //=second segment of path

  args[3], //=host of pacs

  args[4], //=port of pacs

  dirPath  //directory to scan

  */

