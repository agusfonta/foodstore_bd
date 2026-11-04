# =========================================================
# backup_foodstore.ps1
# TP Unidad 6 - Parte 2: Respaldo automatizable
# =========================================================
# Genera un respaldo custom (formato -Fc) de la base foodstore
# usando pg_dump, con fecha y hora en el nombre del archivo.
# Registra el resultado en logs/backup_foodstore.log.
# Termina con exit 1 si pg_dump falla.
#
# USO:
#   .\postgres\mantenimiento\backup_foodstore.ps1
#
# No contiene contrasenas. PGPASSWORD se toma del entorno o, si no
# esta definida, de la linea PGPASSWORD=... del archivo .env (ignorado
# por git).
# =========================================================

# --- Configuracion ---
$Host_    = "localhost"
$Port     = 5432
$User     = "postgres"
$Database = "foodstore_desarrollo"

# --- Rutas (relativas a la raiz del proyecto) ---
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$BackupDir   = Join-Path $ProjectRoot "backups"
$LogDir      = Join-Path $ProjectRoot "logs"
$LogFile     = Join-Path $LogDir "backup_foodstore.log"

# --- Crear carpetas si no existen ---
if (-not (Test-Path $BackupDir)) {
    New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
}
if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

# --- Timestamp para el nombre del archivo ---
$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$BackupFile = Join-Path $BackupDir "foodstore_$Timestamp.dump"

# --- Funcion de log ---
function Write-LogEntry {
    param([string]$Message)
    $LogTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $Entry = "[$LogTime] $Message"
    Add-Content -Path $LogFile -Value $Entry
    Write-Host $Entry
}

# --- Cargar PGPASSWORD desde .env (no versionado) si no esta en el entorno ---
$EnvFile = Join-Path $ProjectRoot ".env"
if (-not $env:PGPASSWORD -and (Test-Path $EnvFile)) {
    foreach ($Line in Get-Content $EnvFile) {
        if ($Line -match '^\s*PGPASSWORD\s*=\s*(.*)$') {
            $env:PGPASSWORD = $Matches[1].Trim().Trim('"')
        }
    }
}

# --- Verificar que PGPASSWORD este definida ---
if (-not $env:PGPASSWORD) {
    Write-LogEntry "ERROR: PGPASSWORD no esta definida en el entorno. Definirla antes de ejecutar el script."
    exit 1
}

# --- Ejecutar pg_dump ---
Write-LogEntry "Inicio de respaldo: $BackupFile"

$DumpOutput = & pg_dump -h $Host_ -p $Port -U $User -d $Database -Fc -f $BackupFile 2>&1
$DumpExit = $LASTEXITCODE

if ($DumpExit -ne 0) {
    Write-LogEntry "ERROR: pg_dump fallo con codigo $DumpExit. Respaldo NO completado."
    foreach ($Msg in $DumpOutput) { Write-LogEntry "pg_dump: $Msg" }
    # No dejar un archivo parcial que parezca un respaldo valido
    if (Test-Path $BackupFile) { Remove-Item $BackupFile -Force }
    exit 1
}

# --- Verificar que el archivo exista y no este vacio ---
if (-not (Test-Path $BackupFile) -or (Get-Item $BackupFile).Length -eq 0) {
    Write-LogEntry "ERROR: El archivo $BackupFile no se creo o esta vacio. Respaldo NO completado."
    if (Test-Path $BackupFile) { Remove-Item $BackupFile -Force }
    exit 1
}

# --- Calcular tamano del archivo ---
$FileSize = (Get-Item $BackupFile).Length
$FileSizeKB = [math]::Round($FileSize / 1KB, 2)

Write-LogEntry "OK: Respaldo completado. Archivo: $BackupFile ($FileSizeKB KB)."
exit 0
