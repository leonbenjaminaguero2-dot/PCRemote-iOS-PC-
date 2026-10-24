# PCRemote
Proyecto base para controlar un PC Windows desde una app SwiftUI en iPhone por la red local.

Incluye:
- Código SwiftUI con secciones Control, Screen y Apps.
- Servidor Windows ASP.NET Core .NET 8 con PIN.
- Workflow GitHub Actions para compilar el servidor Windows.

## Servidor Windows
Instala .NET 8 SDK, abre PowerShell en `WindowsServer` y ejecuta:
`dotnet run`
Permite acceso en el Firewall para redes privadas. Cambia el PIN de `appsettings.json`.

## iOS
Necesitas Xcode en macOS para compilar y firmar la app. Crea un proyecto iOS App SwiftUI llamado PCRemote y añade los archivos de `iOS/PCRemote/`.
Este ZIP contiene código fuente, no una IPA firmada.
