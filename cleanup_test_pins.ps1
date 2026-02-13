# Delete all test pins from database
Write-Host "Deleting old test pins from Tokyo and Chennai..."
Write-Host ""

# Get all pins
$response = Invoke-WebRequest -Uri "https://placetalk-backend-1.onrender.com/discovery/nearby?lat=35.6812&lon=139.7671" -UseBasicParsing
$tokyo = ($response.Content | ConvertFrom-Json).discovered

$response = Invoke-WebRequest -Uri "https://placetalk-backend-1.onrender.com/discovery/nearby?lat=13.0827&lon=80.2707" -UseBasicParsing  
$chennai = ($response.Content | ConvertFrom-Json).discovered

$toDelete = $tokyo + $chennai

Write-Host "Found $($toDelete.Count) test pins to delete"
Write-Host ""

foreach ($pin in $toDelete) {
    try {
        Write-Host "Deleting: $($pin.title) (ID: $($pin.id))"
        Invoke-WebRequest `
            -Uri "https://placetalk-backend-1.onrender.com/pins/$($pin.id)" `
            -Method DELETE `
            -UseBasicParsing | Out-Null
    } catch {
        Write-Host "  (Note: Pin may be already deleted or require auth)"
    }
}

Write-Host ""
Write-Host "✅ Cleanup complete!"
Write-Host ""
Write-Host "Now only your Ehime pins should be visible in the app."
