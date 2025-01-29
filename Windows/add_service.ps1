$compose_url = 'docker-compose.yml'
$compose_content = Get-Content $compose_url
$service_content = Get-Content 'temp_service.yml'

$base_indent = '  '

$indented_service = $service_content | ForEach-Object {
    if ($_ -match '\S') {
        "$base_indent$_"
    } else {
        $_
    }
}

$networks_index = ($compose_content | Select-String -Pattern "^networks:" | Select-Object -First 1).LineNumber - 1
if ($networks_index -eq -1) {
    $networks_index = $compose_content.Count
}

$compose_content[0..($networks_index-1)] + $indented_service + $compose_content[$networks_index..$compose_content.Count] |
    Set-Content $compose_url