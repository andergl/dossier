## ALERTA, NO ESTÁ 100% PROBADO PERO POR AQUI IRÁN LOS TIROS, SOBRE TODO HAY DUDAS CON EL SERVIDOR WEB, QUE NO TENGO DONDE PROBARLO BIEN, USERS Y GPO PROBADO. EMAILS PUES NO TIENE MUCHO MISTERIO, NO SE SI TENEIS UN SMPT

$root  = 'C:\Backups'
$users = "$root\Users.csv"
$gpos  = "$root\GPOs"
$web   = "$root\Web"

$to   = 'support@nordicbackup.net'
$from = 'murcianos-por-el-mundo@skillsnet.dk'
$smtp = 'localhost'


New-Item -ItemType Directory -Force -Path $root, $gpos, $web
Import-Module ActiveDirectory
Import-Module GroupPolicy
Import-Module WebAdministration

$ok = $true
$log = @()

try {
    Get-ADUser -Filter * -Properties * | Select-Object * | Export-Csv $users
    $log += "Users AD: OK ($users)"
} catch {
    $ok = $false
    $log += "USers AD: ERROR - $_"
}

try {
    Remove-Item "$gpos\*" -Recurse -Force
    Backup-GPO -All -Path $gpos
    $log += "GPOs: OK ($gpos)"
} catch {
    $ok = $false
    $log += "GPOs: ERROR - $_"
}

try {
    $copied = 0
    Get-Website | ForEach-Object {
        $site = $_
        $bindings = Get-WebBinding -Name $site.Name
        foreach ($binding in $bindings) {
            $host = $binding.bindingInformation.Split(':')[-1]
            if (-not $host.ToLower().EndsWith('skillsnet.dk')) { continue }

            $src = [Environment]::ExpandEnvironmentVariables($site.physicalPath)
            if (-not (Test-Path $src)) { continue }

            $dst = Join-Path $web $host
            Remove-Item $dst -Recurse -Force
            New-Item -ItemType Directory -Force -Path $dst
            Copy-Item "$src\*" $dst -Recurse -Force
            $copied++
        }
    }
    $log += "IIS: $copied sites copied to $web"
} catch {
    $ok = $false
    $log += "IIS: ERROR - $_"
}

$subject = if ($ok) { '[Backup] Ok' } else { '[Backup] Failed' }
$body = $log

Send-MailMessage -From $from -To $to -Subject $subject -Body $body -SmtpServer $smtp