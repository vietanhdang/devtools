# Build devtools daemon cho Raspberry Pi 4 (linux/arm64) tren may Windows
# Cach chay:
#   .\build-devtools-pi.ps1                          # build, khong chep sang Pi
#   .\build-devtools-pi.ps1 -PiUser ubuntu -PiIp 192.168.1.50   # build + scp sang Pi
# Yeu cau truoc khi chay: Node 22+, Go 1.25+, git. Rust/wasm-pack thieu thi script tu cai.

param(
    [string]$PiUser = "pi",
    [string]$PiIp = ""
)

$ErrorActionPreference = "Stop"
# Script nam trong <repo>/scripts/ → repo la thu muc cha.
$RepoDir = Split-Path $PSScriptRoot -Parent
$OutBin = Join-Path $RepoDir "out\dev-tool-daemon-pi"

function Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Fail($msg) { Write-Host "LOI: $msg" -ForegroundColor Red; exit 1 }

# ---------- 0. Kiem tra toolchain ----------
Step "Kiem tra toolchain"

if (-not (Get-Command node -ErrorAction SilentlyContinue)) { Fail "Thieu Node.js 22+. Tai: https://nodejs.org" }
$nodeMajor = (node --version) -replace 'v(\d+)\..*', '$1'
if ([int]$nodeMajor -lt 22) { Fail "Node qua cu ($(node --version)), can 22+" }

if (-not (Get-Command go -ErrorAction SilentlyContinue)) { Fail "Thieu Go 1.25+. Tai: https://go.dev/dl" }
$goVer = (go version) -replace '.*go(\d+)\.(\d+).*', '$1.$2'
if ([version]$goVer -lt [version]"1.25") { Fail "Go qua cu ($goVer), can 1.25+" }

if (-not (Get-Command git -ErrorAction SilentlyContinue)) { Fail "Thieu git. Tai: https://git-scm.com" }

# ---------- 1. Rust + wasm32 target ----------
$env:Path += ";$env:USERPROFILE\.cargo\bin"

if (-not (Get-Command cargo -ErrorAction SilentlyContinue)) {
    Step "Cai Rust (rustup)"
    $rustupInit = Join-Path $env:TEMP "rustup-init.exe"
    Invoke-WebRequest -Uri "https://win.rustup.rs/x86_64" -OutFile $rustupInit
    & $rustupInit -y --default-toolchain stable --profile minimal
    if ($LASTEXITCODE -ne 0) { Fail "Cai rustup that bai" }
    Remove-Item $rustupInit -Force
}

Step "Dat default toolchain stable"
rustup default stable
if ($LASTEXITCODE -ne 0) { Fail "rustup default stable that bai" }

Step "Them target wasm32"
rustup target add wasm32-unknown-unknown
if ($LASTEXITCODE -ne 0) { Fail "rustup target add that bai" }

# ---------- 2. wasm-pack ----------
if (-not (Get-Command wasm-pack -ErrorAction SilentlyContinue)) {
    Step "Tai wasm-pack (binary san, nhanh hon cargo install)"
    $release = Invoke-RestMethod -Uri "https://api.github.com/repos/rustwasm/wasm-pack/releases/latest"
    $asset = $release.assets | Where-Object { $_.name -match 'x86_64-pc-windows-msvc\.(zip|tar\.gz)$' } | Select-Object -First 1
    if (-not $asset) { Fail "Khong tim thay asset wasm-pack windows trong release $($release.tag_name)" }
    $archPath = Join-Path $env:TEMP $asset.name
    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $archPath
    $extractDir = Join-Path $env:TEMP "wasm-pack-extract"
    if (Test-Path $extractDir) { Remove-Item $extractDir -Recurse -Force }
    New-Item -ItemType Directory -Force $extractDir | Out-Null
    if ($asset.name -like "*.zip") {
        Expand-Archive -Path $archPath -DestinationPath $extractDir
    } else {
        tar -xzf $archPath -C $extractDir
    }
    $exe = Get-ChildItem $extractDir -Recurse -Filter "wasm-pack.exe" | Select-Object -First 1
    if (-not $exe) { Fail "Khong tim thay wasm-pack.exe sau khi giai nen" }
    $cargoBin = "$env:USERPROFILE\.cargo\bin"
    New-Item -ItemType Directory -Force $cargoBin | Out-Null
    Move-Item $exe.FullName (Join-Path $cargoBin "wasm-pack.exe") -Force
    Remove-Item $archPath, $extractDir -Recurse -Force -ErrorAction SilentlyContinue
}

# ---------- 3. Clone repo ----------
Step "Clone repo devtools"
if (-not (Test-Path $RepoDir)) {
    git clone https://github.com/vietanhdang/devtools.git $RepoDir
    if ($LASTEXITCODE -ne 0) { Fail "git clone that bai" }
} else {
    Write-Host "Da co $RepoDir, bo qua clone"
}

Push-Location $RepoDir

# ---------- 4. npm install ----------
Step "npm install"
npm install
if ($LASTEXITCODE -ne 0) { Fail "npm install that bai" }

# ---------- 5. Build wasm ultraviewer ----------
Step "Build wasm ultraviewer"
Push-Location (Join-Path $RepoDir "src_wasm\ultraviewer")
wasm-pack build --target web --out-dir "..\pkg\ultraviewer" --release
$wasmExit = $LASTEXITCODE
Pop-Location
if ($wasmExit -ne 0) { Fail "wasm-pack build that bai" }

# ---------- 6. Build frontend ----------
Step "Build frontend (vite)"
npm run build
if ($LASTEXITCODE -ne 0) { Fail "npm run build that bai" }

# ---------- 7. Nhung frontend vao daemon (go:embed) ----------
Step "Copy dist vao backend"
$webDist = Join-Path $RepoDir "src_backend\tm_core_service\internal\web\dist"
if (Test-Path $webDist) { Remove-Item $webDist -Recurse -Force }
New-Item -ItemType Directory -Force $webDist | Out-Null
Copy-Item (Join-Path $RepoDir "dist\*") $webDist -Recurse -Force

# ---------- 8. Cross-compile linux/arm64 ----------
Step "Cross-compile Go daemon cho arm64 (pure Go, khong CGO)"
$oldGoos, $oldGoarch, $oldCgo = $env:GOOS, $env:GOARCH, $env:CGO_ENABLED
$env:GOOS = "linux"; $env:GOARCH = "arm64"; $env:CGO_ENABLED = "0"
try {
    New-Item -ItemType Directory -Force (Join-Path $RepoDir "out") | Out-Null
    Push-Location (Join-Path $RepoDir "src_backend\tm_app\cmd\daemon_app")
    go build -o $OutBin .
    $goExit = $LASTEXITCODE
    Pop-Location
} finally {
    $env:GOOS, $env:GOARCH, $env:CGO_ENABLED = $oldGoos, $oldGoarch, $oldCgo
}
if ($goExit -ne 0) { Fail "go build that bai" }

if (-not (Test-Path $OutBin)) { Fail "Khong thay binary output: $OutBin" }
Write-Host "`nBuild OK: $OutBin ($((Get-Item $OutBin).Length / 1MB -as [int]) MB)" -ForegroundColor Green

# ---------- 9. Chep sang Pi ----------
if ($PiIp) {
    Step "scp sang $PiUser@$PiIp"
    scp $OutBin "${PiUser}@${PiIp}:~/dev-tool-daemon"
    if ($LASTEXITCODE -ne 0) { Fail "scp that bai" }
    ssh "${PiUser}@${PiIp}" "chmod +x ~/dev-tool-daemon"
    Write-Host "`nXong. Tren Pi chay: ~/dev-tool-daemon" -ForegroundColor Green
    Write-Host "Web UI: http://${PiIp}:1403  |  API: http://${PiIp}:7777"
} else {
    Write-Host @"
Chua truyen PiIp nen bo qua buoc chep. Chay tay:
  scp "$OutBin" <user>@<pi-ip>:~/dev-tool-daemon
  ssh <user>@<pi-ip> "chmod +x ~/dev-tool-daemon && ~/dev-tool-daemon"
Web UI: http://<pi-ip>:1403  |  API: http://<pi-ip>:7777
"@ -ForegroundColor Yellow
}

Pop-Location
