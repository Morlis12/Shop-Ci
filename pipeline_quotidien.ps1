# =========================================================================
# PIPELINE QUOTIDIEN BOUTIQUE CI
# Enchaine : fraicheur des sources -> snapshots (historisation) -> build
# Journalise tout dans logs\ et rend un code de sortie exploitable.
# =========================================================================

$ErrorActionPreference = "Continue"

# Chemins ABSOLUS : une tache planifiee ne demarre PAS dans ton dossier,
# et n'a PAS ta venv activee -> on appelle dbt.exe directement dans la venv.
$racine = "C:\Users\Laptop Studio\Documents\Shop Ci"
$dbt    = Join-Path $racine ".venv\Scripts\dbt.exe"

# Un fichier journal par execution, horodate
$horodatage = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$journal    = Join-Path $racine "logs\pipeline_$horodatage.log"
Start-Transcript -Path $journal

Set-Location (Join-Path $racine "shop_ci_dbt")

# --- 1. Fraicheur des sources (informatif sur nos donnees fictives) ---
& $dbt source freshness
$code_fraicheur = $LASTEXITCODE
Write-Output ">>> Fraicheur : code $code_fraicheur"

# --- 2. Snapshots : capturer l'historique AVANT de reconstruire ---
& $dbt snapshot
$code_snapshot = $LASTEXITCODE
Write-Output ">>> Snapshot : code $code_snapshot"

# --- 3. Build : modeles + tous les tests ---
& $dbt build
$code_build = $LASTEXITCODE
Write-Output ">>> Build : code $code_build"

Stop-Transcript

# Code de sortie global : 0 = succes, 1 = echec (lu par le Planificateur)
if ($code_build -ne 0 -or $code_snapshot -ne 0) { exit 1 } else { exit 0 }