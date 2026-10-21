# =========================================================
# restore_test.ps1
# TP Unidad 6 - Parte 4: Simulacro de restauracion contra reloj
# =========================================================
# Restaura el ultimo respaldo de backups/ en foodstore_restore_test (base
# descartable), valida conteos y restricciones logicas y mide el RTO.
# NUNCA toca foodstore ni foodstore_desarrollo (solo las lee para registrar
# los conteos de referencia).
#
# USO:  .\sql\restore_test.ps1
# PGPASSWORD se toma del entorno o del .env (ignorado por git).
# Sale con exit 1 si algo falla o alguna validacion no coincide.
# =========================================================

$Host_      = "localhost"
$Port       = 5432
$User       = "postgres"
$SourceDb   = "foodstore_desarrollo"
$RestoreDb  = "foodstore_restore_test"
$Tables     = @("categorias", "clientes", "productos", "pedidos", "detalle_pedido")

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$BackupDir   = Join-Path $ProjectRoot "backups"
$LogDir      = Join-Path $ProjectRoot "logs"
$LogFile     = Join-Path $LogDir "restore_test.log"
if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }

function Write-LogEntry {
    param([string]$Message)
    $Entry = "[{0}] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Message
    Add-Content -Path $LogFile -Value $Entry
    Write-Host $Entry
}
function Fail {
    param([string]$Message)
    Write-LogEntry "ERROR: $Message"
    exit 1
}

# --- PGPASSWORD desde entorno o .env ---
$EnvFile = Join-Path $ProjectRoot ".env"
if (-not $env:PGPASSWORD -and (Test-Path $EnvFile)) {
    foreach ($Line in Get-Content $EnvFile) {
        if ($Line -match '^\s*PGPASSWORD\s*=\s*(.*)$') { $env:PGPASSWORD = $Matches[1].Trim().Trim('"') }
    }
}
if (-not $env:PGPASSWORD) { Fail "PGPASSWORD no esta definida (ni en el entorno ni en .env)." }

$Conn = @("-h", $Host_, "-p", $Port, "-U", $User)

# --- Ultimo respaldo ---
$Backup = Get-ChildItem $BackupDir -Filter "foodstore_*.dump" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $Backup -or $Backup.Length -eq 0) { Fail "No hay respaldo .dump valido en $BackupDir." }

# --- Conteos de referencia (base de trabajo), antes de iniciar el cronometro ---
$SqlCounts = (($Tables | ForEach-Object { "SELECT '$_', COUNT(*) FROM $_" }) -join " UNION ALL ")
$RefCounts = @{}
foreach ($Row in (& psql @Conn -d $SourceDb -At -F "|" -c $SqlCounts)) {
    $P = $Row -split "\|"; $RefCounts[$P[0]] = [int64]$P[1]
}
if ($RefCounts.Count -ne $Tables.Count) { Fail "No se pudieron leer los conteos de $SourceDb." }

# La base de restauracion es descartable: se recrea en cada ensayo
& dropdb @Conn --if-exists $RestoreDb 2>&1 | Out-Null

$BackupAgeMin = [math]::Round(((Get-Date) - $Backup.LastWriteTime).TotalMinutes, 1)
Write-LogEntry "Respaldo usado: $($Backup.Name) (creado $($Backup.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')), antiguedad $BackupAgeMin min, $([math]::Round($Backup.Length/1KB,2)) KB)"
Write-LogEntry "INICIO cronometro (restauracion en $RestoreDb)"

# ================= CRONOMETRO =================
$Sw = [System.Diagnostics.Stopwatch]::StartNew()

$Out = & createdb @Conn $RestoreDb 2>&1
if ($LASTEXITCODE -ne 0) { Fail "createdb fallo: $Out" }

$Out = & pg_restore @Conn -d $RestoreDb --no-owner --no-privileges $Backup.FullName 2>&1
if ($LASTEXITCODE -ne 0) { Fail "pg_restore fallo: $Out" }
$TRestore = $Sw.Elapsed.TotalSeconds

# --- Validaciones ---
$Ok = $true
$Restored = @{}
foreach ($Row in (& psql @Conn -d $RestoreDb -At -F "|" -c $SqlCounts)) {
    $P = $Row -split "\|"; $Restored[$P[0]] = [int64]$P[1]
}
foreach ($T in $Tables) {
    $Match = ($Restored[$T] -eq $RefCounts[$T])
    if (-not $Match) { $Ok = $false }
    Write-LogEntry ("Conteo {0}: referencia={1} restaurado={2} {3}" -f $T, $RefCounts[$T], $Restored[$T], $(if ($Match) {"OK"} else {"DIFERENTE"}))
}
$BadProd = [int64](& psql @Conn -d $RestoreDb -At -c "SELECT COUNT(*) FROM productos WHERE precio < 0 OR stock < 0")
$BadDet  = [int64](& psql @Conn -d $RestoreDb -At -c "SELECT COUNT(*) FROM detalle_pedido WHERE cantidad <= 0 OR precio_unitario < 0")
Write-LogEntry "productos_invalidos=$BadProd detalles_invalidos=$BadDet"
if ($BadProd -ne 0 -or $BadDet -ne 0) { $Ok = $false }

$Sw.Stop()
# ================= FIN CRONOMETRO =================

Write-LogEntry ("Tiempo createdb+pg_restore: {0:N1} s" -f $TRestore)
Write-LogEntry ("RTO observado (createdb + restore + validaciones): {0:N1} s" -f $Sw.Elapsed.TotalSeconds)
if (-not $Ok) { Fail "Alguna validacion no coincide. Restauracion NO validada." }
Write-LogEntry "OK: restauracion validada en $RestoreDb."
exit 0
