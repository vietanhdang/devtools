# Build devtools daemon cho Raspberry Pi 4 (linux/arm64) tren may Windows
# Cach chay:
#   .\build-devtools-pi.ps1                          # build, khong chep sang Pi
#   .\build-devtools-pi.ps1 -PiUser ubuntu -PiIp 192.168.1.50   # build + scp sang Pi
# Yeu cau truoc khi chay: Node 22+, Go 1.25+, git, Python 3. Rust/wasm-pack/trunk thieu thi script tu cai.
# Build wasm nhu scripts/build_wasm.sh: ultraviewer, iron_rdp (rdp), cimbar (prebuilt).
# dotnet_wrapper chi build khi co -WithDotnet (can .NET SDK 10).
# photocraft chi build khi co -WithPhotocraft (can trunk + clang cho feature heif).

param(
    [string]$PiUser = "pi",
    [string]$PiIp = "",
    # Tam thoi bo qua build dotnet_wrapper (can .NET SDK 10). Them -WithDotnet de build lai.
    [switch]$WithDotnet,
    # Tam thoi bo qua build photocraft (can trunk + clang). Them -WithPhotocraft de build lai.
    [switch]$WithPhotocraft
)

$ErrorActionPreference = "Stop"
# Script nam trong <repo>/scripts/ → repo la thu muc cha.
$RepoDir = Split-Path $PSScriptRoot -Parent
$OutBin = Join-Path $RepoDir "out\dev-tool-daemon-pi"

function Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Fail($msg) { Write-Host "LOI: $msg" -ForegroundColor Red; exit 1 }

# Git pull neu $dir la git repo rieng (port cua scripts/git_pull_if_repo.sh).
# That bai chi canh bao, khong dung build.
function Tm-GitPullIfRepo($dir) {
    if (-not $dir -or -not (Test-Path (Join-Path $dir ".git"))) { return }
    Write-Host "Cap nhat source: $dir"
    $branch = git -C $dir symbolic-ref --short HEAD 2>$null
    if (-not $branch) {
        git -C $dir fetch origin --quiet 2>$null
        $branch = (git -C $dir symbolic-ref --short refs/remotes/origin/HEAD 2>$null) -replace '^origin/', ''
        if (-not $branch -or $branch -eq 'HEAD') {
            git -C $dir remote set-head origin -a 2>$null
            $branch = (git -C $dir symbolic-ref --short refs/remotes/origin/HEAD 2>$null) -replace '^origin/', ''
        }
        if (-not $branch -or $branch -eq 'HEAD') {
            Write-Host "Canh bao: khong xac dinh duoc nhanh mac dinh trong $dir (bo qua pull)"
            return
        }
        git -C $dir checkout $branch 2>$null
    }
    git -C $dir pull origin $branch
    if ($LASTEXITCODE -ne 0) { Write-Host "Canh bao: git pull that bai trong $dir (tiep tuc build)" }
}

# ---------- 0. Kiem tra toolchain ----------
Step "Kiem tra toolchain"

if (-not (Get-Command node -ErrorAction SilentlyContinue)) { Fail "Thieu Node.js 22+. Tai: https://nodejs.org" }
$nodeMajor = (node --version) -replace 'v(\d+)\..*', '$1'
if ([int]$nodeMajor -lt 22) { Fail "Node qua cu ($(node --version)), can 22+" }

if (-not (Get-Command go -ErrorAction SilentlyContinue)) { Fail "Thieu Go 1.25+. Tai: https://go.dev/dl" }
$goVer = (go version) -replace '.*go(\d+)\.(\d+).*', '$1.$2'
if ([version]$goVer -lt [version]"1.25") { Fail "Go qua cu ($goVer), can 1.25+" }

if (-not (Get-Command git -ErrorAction SilentlyContinue)) { Fail "Thieu git. Tai: https://git-scm.com" }

if ($WithDotnet) {
    if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) { Fail "Thieu .NET SDK. Tai: https://dotnet.microsoft.com/download/dotnet/10.0" }
    $sdks = dotnet --list-sdks 2>$null
    if (-not ($sdks | Where-Object { $_ -match '^10\.' })) { Fail "Thieu .NET SDK 10 (can cho dotnet_wrapper). Tai: https://dotnet.microsoft.com/download/dotnet/10.0" }
}

$PyCmd = $null
foreach ($p in @("python", "python3")) {
    if (Get-Command $p -ErrorAction SilentlyContinue) { $PyCmd = $p; break }
}
if (-not $PyCmd) { Fail "Thieu Python 3 (can cho patch_wasm_dist.py + kiem tra import wasm)" }

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

# ---------- 2b. trunk (build photocraft) — chi can khi co -WithPhotocraft ----------
if ($WithPhotocraft -and -not (Get-Command trunk -ErrorAction SilentlyContinue)) {
    Step "Cai trunk (cargo install, mat vai phut)"
    cargo install trunk --locked
    if ($LASTEXITCODE -ne 0) { Fail "cargo install trunk that bai" }
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
Remove-Item (Join-Path $RepoDir "src_wasm\pkg\ultraviewer\.gitignore"), `
            (Join-Path $RepoDir "src_wasm\pkg\ultraviewer\package.json"), `
            (Join-Path $RepoDir "src_wasm\pkg\ultraviewer\README.md") -Force -ErrorAction SilentlyContinue

# ---------- 5b. Build wasm iron_rdp (RDP) ----------
Step "Build wasm iron_rdp (RDP)"
$rdpDir = Join-Path $RepoDir "src_wasm\iron_rdp"
$rdpExt = Join-Path $rdpDir "external_repo"
if (-not (Test-Path $rdpExt)) {
    git clone https://github.com/tonguyenducmanh/IronRDP.git $rdpExt
    if ($LASTEXITCODE -ne 0) { Fail "git clone IronRDP that bai" }
}
Tm-GitPullIfRepo $rdpExt
Push-Location $rdpDir
wasm-pack build --target web --out-dir "..\pkg\rdp" --release
$wasmExit = $LASTEXITCODE
Pop-Location
if ($wasmExit -ne 0) { Fail "wasm-pack build iron_rdp that bai" }
Remove-Item (Join-Path $RepoDir "src_wasm\pkg\rdp\.gitignore"), `
            (Join-Path $RepoDir "src_wasm\pkg\rdp\package.json"), `
            (Join-Path $RepoDir "src_wasm\pkg\rdp\README.md") -Force -ErrorAction SilentlyContinue

# ---------- 5c. Build wasm dotnet_wrapper (.NET 10) — bo qua tru khi co -WithDotnet ----------
if ($WithDotnet) {
    Step "Build wasm dotnet_wrapper (.NET 10)"
    $dotnetDir = Join-Path $RepoDir "src_wasm\dotnet_wrapper"
    Push-Location $dotnetDir
    if (Test-Path bin) { Remove-Item bin -Recurse -Force }
    if (Test-Path obj) { Remove-Item obj -Recurse -Force }
    dotnet publish Tools.NetWrapper.csproj -c Release
    $dnExit = $LASTEXITCODE
    Pop-Location
    if ($dnExit -ne 0) { Fail "dotnet publish that bai" }
    $fwDir = Join-Path $dotnetDir "bin\Release\net10.0\browser-wasm\AppBundle\_framework"
    if (-not (Test-Path $fwDir)) { Fail "Khong thay AppBundle/_framework: $fwDir" }
    $pkgDotnet = Join-Path $RepoDir "src_wasm\pkg\dotnet"
    if (Test-Path $pkgDotnet) { Remove-Item $pkgDotnet -Recurse -Force }
    New-Item -ItemType Directory -Force $pkgDotnet | Out-Null
    Copy-Item (Join-Path $fwDir "*") $pkgDotnet -Recurse -Force
} else {
    Write-Host "Bo qua build dotnet_wrapper (them -WithDotnet de build)"
}

# ---------- 5d. Tai wasm cimbar (prebuilt tu release libcimbar) ----------
Step "Tai wasm cimbar (prebuilt v0.6.8)"
$CimbarVersion = "0.6.8"
$pkgCimbar = Join-Path $RepoDir "src_wasm\pkg\cimbar"
$cimbarTar = Join-Path $env:TEMP "cimbar.wasm.tar.gz"
Invoke-WebRequest -Uri "https://github.com/sz3/libcimbar/releases/download/v$CimbarVersion/cimbar.wasm.tar.gz" -OutFile $cimbarTar
$tarSha = (Get-FileHash $cimbarTar -Algorithm SHA256).Hash.ToLower()
if ($tarSha -ne "0a14b63decd9404e7a319b4b0f5cd873eb6aa325f90df4e965305f523567c4a5") { Fail "SHA256 tarball cimbar khong khop" }
$tarMd5 = (Get-FileHash $cimbarTar -Algorithm MD5).Hash.ToLower()
if ($tarMd5 -ne "9c62f5dbffd3ac495b7a1cd7da9781ad") { Fail "MD5 tarball cimbar khong khop" }
$cimbarExtract = Join-Path $env:TEMP "cimbar-extract"
if (Test-Path $cimbarExtract) { Remove-Item $cimbarExtract -Recurse -Force }
New-Item -ItemType Directory -Force $cimbarExtract | Out-Null
tar -xzf $cimbarTar -C $cimbarExtract
$cimbarGlue = Get-ChildItem $cimbarExtract -Recurse -Filter "cimbar_js.*.js" | Select-Object -First 1
$cimbarWasm = Get-ChildItem $cimbarExtract -Recurse -Filter "cimbar_js.*.wasm" | Select-Object -First 1
if (-not $cimbarGlue -or -not $cimbarWasm) { Fail "Khong thay cimbar_js.*.js/.wasm trong release" }
New-Item -ItemType Directory -Force $pkgCimbar | Out-Null
Copy-Item $cimbarGlue.FullName (Join-Path $pkgCimbar "cimbar_js.js") -Force
Copy-Item $cimbarWasm.FullName (Join-Path $pkgCimbar "cimbar_js.wasm") -Force
Remove-Item $cimbarTar, $cimbarExtract -Recurse -Force -ErrorAction SilentlyContinue

# ---------- 5e. Build wasm photocraft (trunk) — bo qua tru khi co -WithPhotocraft ----------
if ($WithPhotocraft) {
    Step "Build wasm photocraft (trunk)"
    $craftDir = Join-Path $RepoDir "src_wasm\photocraft"
    $craftExt = Join-Path $craftDir "external_repo"
    if (-not (Test-Path (Join-Path $craftExt "apps\photocraft-web"))) {
        git clone https://github.com/tonguyenducmanh/photocraft.git $craftExt
        if ($LASTEXITCODE -ne 0) { Fail "git clone photocraft that bai" }
    }
    Tm-GitPullIfRepo $craftExt
    Push-Location (Join-Path $craftExt "apps\photocraft-web")
    trunk build --release
    $trunkExit = $LASTEXITCODE
    Pop-Location
    if ($trunkExit -ne 0) { Fail "trunk build photocraft that bai" }
    $pkgCraft = Join-Path $RepoDir "src_wasm\pkg\photocraft"
    if (Test-Path $pkgCraft) { Remove-Item $pkgCraft -Recurse -Force }
    New-Item -ItemType Directory -Force $pkgCraft | Out-Null
    Copy-Item (Join-Path $craftExt "dist\web\*") $pkgCraft -Recurse -Force

    # Nen wasm thanh .wasm.gz + patch index.html (browser tu giai nen DecompressionStream)
    # = port cua scripts/wasm_dist_common.sh (gioi han 25 MiB/file cua Cloudflare).
    $craftWasm = Get-ChildItem $pkgCraft -Filter "*_bg.wasm" | Select-Object -First 1
    if ($craftWasm) {
        $gzPath = "$($craftWasm.FullName).gz"
        $inFs = [IO.File]::OpenRead($craftWasm.FullName)
        $outFs = [IO.File]::Create($gzPath)
        $gzStream = New-Object IO.Compression.GzipStream($outFs, [IO.Compression.CompressionLevel]::Optimal)
        $inFs.CopyTo($gzStream)
        $gzStream.Dispose(); $outFs.Dispose(); $inFs.Dispose()
        Remove-Item $craftWasm.FullName -Force
        & $PyCmd (Join-Path $RepoDir "scripts\patch_wasm_dist.py") (Join-Path $pkgCraft "index.html") "$($craftWasm.Name).gz" --app PhotoCraft
        if ($LASTEXITCODE -ne 0) { Fail "patch index.html photocraft that bai" }
    } else {
        Write-Host "Canh bao: khong thay *_bg.wasm trong pkg\photocraft (bo qua buoc nen)"
    }
    Remove-Item (Join-Path $pkgCraft "_headers"), (Join-Path $pkgCraft ".htaccess"), (Join-Path $pkgCraft "HOSTING.md") -Force -ErrorAction SilentlyContinue
    $craftGlue = Get-ChildItem $pkgCraft -Filter "*.js" | Where-Object { $_.Name -notlike "*.map" } | Select-Object -First 1
    $craftWasmFinal = Get-ChildItem $pkgCraft | Where-Object { $_.Name -like "*_bg.wasm*" } | Select-Object -First 1
    if ($craftGlue -and $craftWasmFinal) {
        $manifest = "{`n  `"glue`": `"$($craftGlue.Name)`",`n  `"wasm`": `"$($craftWasmFinal.Name)`"`n}"
        [IO.File]::WriteAllText((Join-Path $pkgCraft "manifest.json"), $manifest, (New-Object Text.UTF8Encoding($false)))
    }
    $oversize = Get-ChildItem $pkgCraft -Recurse -File | Where-Object { $_.Length -gt 25MB }
    if ($oversize) { Fail "File vuot 25 MiB trong pkg\photocraft: $($oversize.Name -join ', ')" }
} else {
    Write-Host "Bo qua build photocraft (them -WithPhotocraft de build)"
}

# ---------- 5f. Kiem tra import section wasm (Luat 15: khong duoc co module "env") ----------
Step "Kiem tra import section wasm (Luat 15)"
$checkPy = Join-Path $env:TEMP "tm_check_wasm_env.py"
$checkSrc = @'
import sys

def read_uleb(data, pos):
    result = 0
    shift = 0
    while True:
        b = data[pos]
        pos += 1
        result |= (b & 0x7F) << shift
        if not (b & 0x80):
            return result, pos
        shift += 7

data = open(sys.argv[1], "rb").read()
if data[:4] != b"\x00asm":
    raise SystemExit("LOI: khong phai file wasm hop le: " + sys.argv[1])
pos = 8
modules = set()
while pos < len(data):
    section_id = data[pos]
    pos += 1
    size, pos = read_uleb(data, pos)
    end = pos + size
    if section_id == 2:
        count, p = read_uleb(data, pos)
        for _ in range(count):
            n, p = read_uleb(data, p)
            modules.add(data[p:p + n].decode("utf-8", "replace"))
            p += n
            n, p = read_uleb(data, p)
            p += n
            kind = data[p]
            p += 1
            if kind == 0:
                _, p = read_uleb(data, p)
            elif kind == 1:
                p += 1
                flags, p = read_uleb(data, p)
                _, p = read_uleb(data, p)
                if flags & 1:
                    _, p = read_uleb(data, p)
            elif kind == 2:
                flags, p = read_uleb(data, p)
                _, p = read_uleb(data, p)
                if flags & 1:
                    _, p = read_uleb(data, p)
            elif kind == 3:
                p += 2
            else:
                raise SystemExit("LOI: khong doc duoc import kind %d" % kind)
    pos = end

if "env" in modules:
    raise SystemExit("LOI: " + sys.argv[1] + " import tu module 'env' — module se khong load trong trinh duyet")
print("    OK:", sys.argv[1], "->", ", ".join(sorted(modules)) or "(khong co import)")
'@
[IO.File]::WriteAllText($checkPy, $checkSrc, (New-Object Text.UTF8Encoding($false)))
# Chi kiem wasm Rust (wasm-pack/cimbar); dotnet (Blazor) co glue JS cung cap import "env" nen bo qua.
$envCheckFiles = @(
    (Join-Path $RepoDir "src_wasm\pkg\ultraviewer\ultraviewer_client_bg.wasm"),
    (Join-Path $RepoDir "src_wasm\pkg\rdp\rdp_client_bg.wasm"),
    (Join-Path $pkgCimbar "cimbar_js.wasm")
)
foreach ($f in $envCheckFiles) {
    if (-not (Test-Path $f)) { Fail "Khong thay file wasm de kiem tra: $f" }
    & $PyCmd $checkPy $f
    if ($LASTEXITCODE -ne 0) { Fail "Kiem tra import section that bai: $f" }
}
Remove-Item $checkPy -Force -ErrorAction SilentlyContinue

# ---------- 6. Build frontend ----------
Step "Build frontend (vite)"
npm run build
if ($LASTEXITCODE -ne 0) { Fail "npm run build that bai" }

# ---------- 10. Nhung frontend vao daemon (go:embed) ----------
Step "Copy dist vao backend"
$webDist = Join-Path $RepoDir "src_backend\tm_core_service\internal\web\dist"
if (Test-Path $webDist) { Remove-Item $webDist -Recurse -Force }
New-Item -ItemType Directory -Force $webDist | Out-Null
Copy-Item (Join-Path $RepoDir "dist\*") $webDist -Recurse -Force

# ---------- 8. Keo x/crypto cho bcrypt (pin ban tuong thich Go 1.25) ----------
Step "go get x/crypto (tm_core_service)"
Push-Location (Join-Path $RepoDir "src_backend\tm_core_service")
# x/crypto@latest yeu cau Go >= 1.26 — reset go directive + pin ban cu hon
# de khong phai nang Go toolchain (repo dang chay Go 1.25).
go mod edit -go=1.25.6
go get golang.org/x/crypto@v0.36.0
$depExit = $LASTEXITCODE
if ($depExit -eq 0) {
    go mod tidy
    $depExit = $LASTEXITCODE
}
Pop-Location
if ($depExit -ne 0) { Fail "go get/tidy x/crypto that bai (kiem tra mang / GOPROXY)" }

# tm_app dung tm_core_service qua replace → go.sum cua tm_app cung can entry x/crypto
Step "go mod tidy (tm_app)"
Push-Location (Join-Path $RepoDir "src_backend\tm_app")
go mod tidy
$tidyAppExit = $LASTEXITCODE
Pop-Location
if ($tidyAppExit -ne 0) { Fail "go mod tidy tm_app that bai (kiem tra mang / GOPROXY)" }

# ---------- 11. Cross-compile linux/arm64 ----------
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

# ---------- 12. Chep sang Pi ----------
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
