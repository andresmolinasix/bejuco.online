Hola estoy en una hackathon https://gofest26.uo.ar/ en grupo realizamos el proceso delimintando de la siguiente manera.



Definición de MVP. 

Vamos a crear un earthquake-communication-system-offline llamado bejuco ( contamos con dominio propio bejucp.online), básicamente en el equipo acotamos el problema de la siguiente manera basado en este estudio de Ookla.  https://www.ookla.com/articles/colombia-earthquake-resilience

El problema de un evento sísmico de este tipo tiene principalmente, dos fases criticas que aún no se están nisiqueira poniendo sobre la mesa y es la infraestructura de comunicación. Puntualmente, una región tan próxima a una falla geológica con una relativa actividad sísmica constante develo cómo la falta de infraestructura incrementa el problema porque en la fase de un evento sismico las comunicaciones tiene una mayor recurrencia a estar fuera de servicio por la saturación, y reducir su rendimiento. por uso de redes de 3 y 2 generación. En segundo lugar por la caída del promedio de mb de descarga y aumento en la latencia. 


En ese orden de ideas salvar vidas es la prioridad en el momento cero de una tragedia como estás, esos picos de comunicaciones vienen de personas intentando ubicar a sus familiares para conocer si necesitan ayuda. Así es como la comunicación descentraliza juega un rol para salvar vidas, ya que utilizando el concepto que Bluetooth Low Energy, como protocolo de comunicación para permitir desarrollar un sistema de comunicaciones y funcionalidades orientadas para salvar vidas, tecnología frente a estas situaciones. 


El sistema incialmente toma el concepto de mesh que se ha desarrollado en las redes BLE, pero en este escenario la intención es usar el poder que tiene para distribuir información para dotar de tecnología con ese caso de uso y con la esperanza de que sea base para que se instrumentalice a más. Dentro del modelo de referencia que utilizamos como referencia para la arquitectura que puntualmente queremos desarrollar tenemos a bitchat, https://github.com/permissionlesstech/bitchat
en este caso el hito que encontramos es que su usa el mesh para permitir la comunicación cifrada en la red. Aicionalemnte encontramos hitos que son relevantes al jugar un poco desactivando y activando blutooth en algunos dispositivos. 

Hallazgos. 
1. En una pequeña red en donde tengo solo dos teléfonos. la sincronización no funciona del todo y es componente clave para el desarrollo de la historia de usuario. 


Historia de usuario. 
1. Usando el protocolo mesh. 

recibir información de una api de eventos sísmicos como USGS (Servicio Geológico de EE. UU.), crear un trigger dentro de la app que permita tomar datos como latitud longitud, nombre, teléfono y nombre de contacto. 


Caso de usuario 1 - persona afectada. 
Esto con el fin de que las personas que pasen por el lugar, tengan la app descargada por medio de la red de bajo consumo energético, debe enviarse ante la presencia de la red de manera repetida el paquete, los participantes externos recibir el paquete y en zonas en donde no existe comunicaciones se pueda conocer esos paquetes emitidos por personas ( centralizando de manera inmediata los sitios para atender y encontrando a tus seres queridos), y cuando uno de los participantes externos tenga conexión a red internet transmitir a una instancia un servidor gcp para distribuir la infromación a las autoridades y tengan el mapeo en tiempo real.   


Caso de usuario 1 - persona no afectada (grupo) 
Esta persona es la que transmite la señal, considerando que el sistema va a recibir la alerta de USGS (Servicio Geológico de EE. UU.) igual que el afectado, el modelo debe reconocer que tipo de agente en el modelo sin usar internet. entoces tener el canal de abierto a escuchar y no transmitir. 


Caso de uso 2 - Centro de acopio necesita comunicarse con sitios en donde no se tiene puntualmente conexión a internet, por ende usa el camino mesh sobre una serie de dagminificados sobre los que se va a requerir la información de insumos necesarios, ya sean alimentos, materiales de construcción. que en ese caso se trata de un payload diferentes, basado en origen, destino, materiales, etc, elementos que sean de utilidad.  En este caso es posible que el centro de acopio tenga forma de moderador. 



La red es la base para crear funcionalidades d evarios tipos, elementalmente en estos escenarios no se detallan ejercicios con comunicación cifrada ya que pueden existir usos indevidos y es algo que se debe buscar blindar antes de liberar. 

Otro uso posible es la atestiguar en blockchain la llegada de material, o el uso de amplificadores del sistema con otros dispositivos de bajo consumo energético como son los esp32. pero todo en la arquitectura existente.