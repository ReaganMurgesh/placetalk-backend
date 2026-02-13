# Test Pin Creation with Ehime Coordinates
$headers = @{"Content-Type" = "application/json"}

# Ehime, Japan coordinates (Ishite area)
$testPin = @{
    title = "DEBUG Test Pin"
    directions = "Testing coordinates"
    details = "Ehime test"
    lat = 33.8416  # Ishite, Ehime latitude
    lon = 132.7661 # Ishite, Ehime longitude
    type = "location"
    pinCategory = "normal"
} | ConvertTo-Json

Write-Host "Sending to backend:"
Write-Host "  lat: 33.8416"
Write-Host "  lon: 132.7661"
Write-Host ""

$response = Invoke-WebRequest `
    -Uri "https://placetalk-backend-1.onrender.com/pins" `
    -Method POST `
    -Headers $headers `
    -Body $testPin `
    -UseBasicParsing

$json = ($response.Content | ConvertFrom-Json).pin

Write-Host "Backend returned:"
Write-Host "  lat: $($json.lat)"
Write-Host "  lon: $($json.lon)"
Write-Host ""

if ($json.lat -eq 33.8416 -and $json.lon -eq 132.7661) {
    Write-Host "✅ COORDINATES CORRECT - No swap!"
} else {
    Write-Host "❌ COORDINATES SWAPPED!"
    Write-Host "   Expected: lat=33.8416, lon=132.7661"
    Write-Host "   Got:      lat=$($json.lat), lon=$($json.lon)"
}
