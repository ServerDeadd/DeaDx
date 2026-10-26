param(
    [string]$Out = "DeaDx.lua",
    [switch]$Quiet
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$src = Join-Path $root "src"

$modules = @(
    "Core/Signal", "Core/State", "Core/Capabilities", "Core/Utility", "Core/Markup",
    "Core/Theme", "Core/Config", "Core/Widgets", "Core/Editable", "Core/Search",
    "Core/Hash", "Core/Integrity", "Core/Component", "Core/Section", "Core/Card", "Core/Tab", "Core/Window",
    "Themes/Default", "Themes/DeaDx", "Themes/Dark", "Themes/Darker", "Themes/Amoled",
    "Themes/Light", "Themes/Midnight", "Themes/Crimson", "Themes/Ocean", "Themes/Forest",
    "Themes/Amethyst", "Themes/Sunset",
    "Services/Cleanup", "Services/Animation", "Services/Input", "Services/Drag",
    "Services/Acrylic", "Services/Tooltip", "Services/Notification", "Services/StatusBar", "Services/Loading", "Services/KeySystem", "Services/KeyPlus", "Services/Luarmor", "Services/Palette", "Services/ThemeEditor", "Services/Tour", "Services/Console", "Services/ConfigPanel", "Services/KeybindPanel",
    "Icons/Catalog", "Icons/Svg", "Icons/Store", "Icons/Providers", "Icons/Registry", "Icons/Icon",
    "Components/Button", "Components/Toggle", "Components/Slider", "Components/Dropdown",
    "Components/MultiDropdown", "Components/Input", "Components/Keybind", "Components/Colorpicker",
    "Components/Paragraph", "Components/Label", "Components/Divider", "Components/Notification",
    "Components/Dialog", "Components/Segmented", "Components/Progress", "Components/Countdown",
    "Components/Stat", "Components/Image", "Components/Code", "Components/List",
    "Components/Player", "Components/Preview", "Components/Graph",
    "Bootstrap"
)

$version = "1.0.0"
$initPath = Join-Path $src "init.luau"
if (Test-Path $initPath) {
    $initText = Get-Content $initPath -Raw
    $match = [regex]::Match($initText, 'local VERSION = "([^"]+)"')
    if ($match.Success) { $version = $match.Groups[1].Value }
}

$builder = New-Object System.Text.StringBuilder
$null = $builder.AppendLine("-- DeaDx $version")
$null = $builder.AppendLine("-- UI library by ServerDead")
$null = $builder.AppendLine("-- Built $(Get-Date -Format 'yyyy-MM-dd HH:mm')")
$null = $builder.AppendLine("")
$null = $builder.AppendLine("local __clock = os.clock()")
$null = $builder.AppendLine("local __modules = {}")
$null = $builder.AppendLine("")

$missing = @()
foreach ($path in $modules) {
    $file = Join-Path $src ($path.Replace("/", [IO.Path]::DirectorySeparatorChar) + ".luau")
    if (-not (Test-Path $file)) {
        $missing += $path
        continue
    }
    $body = (Get-Content $file -Raw).TrimEnd()
    $null = $builder.AppendLine("__modules[`"$path`"] = (function()")
    $null = $builder.AppendLine($body)
    $null = $builder.AppendLine("end)()")
    $null = $builder.AppendLine("")
}

if ($missing.Count -gt 0) {
    throw "Missing modules: $($missing -join ', ')"
}

$loader = @'
local __defined = os.clock() - __clock
local __loaded = {}
local function import(path)
	local cached = __loaded[path]
	if cached ~= nil then
		return cached
	end
	local factory = __modules[path]
	if factory == nil then
		error("[DEADX][ERROR] Missing module: " .. tostring(path), 0)
	end
	local module = factory
	if type(factory) == "function" then
		module = factory(import)
	end
	__loaded[path] = module
	return module
end

local __boot = os.clock()
local __library = import("Bootstrap")
__library.LoadTime = {
	Define = math.floor(__defined * 10000) / 10,
	Boot = math.floor((os.clock() - __boot) * 10000) / 10,
	Modules = 0,
}
for _ in __loaded do
	__library.LoadTime.Modules += 1
end
return __library
'@

$null = $builder.AppendLine($loader)

$target = if ([IO.Path]::IsPathRooted($Out)) { $Out } else { Join-Path $root $Out }
$text = $builder.ToString() -replace "`r`n", "`n"
[IO.File]::WriteAllText($target, $text, (New-Object System.Text.UTF8Encoding $false))

if (-not $Quiet) {
    $lines = ($text -split "`n").Count
    $kb = [math]::Round((Get-Item $target).Length / 1024, 1)
    Write-Output "DeaDx $version -> $target"
    Write-Output "$($modules.Count) modules, $lines lines, $kb KB"
}







