# qwprefetch
dicom qido wado url prefetch



## Funciones

Proxy entre un pacs dicomweb y un repositorio aammdd/Euidb64/Suidb64/Iuidb64

La aplicación está subdividida en 4 loops:

- date ( creación folder uidb64 correspondiente )
- qido Euid ( creación folder uidb64 correspondiente )
- qido Suid ( creación folder uidb64 correspondiente )
- wado Iuid (extracción SOPinstanceUID, escritura archivo correspondiente, )
