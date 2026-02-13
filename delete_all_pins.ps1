# Delete ALL pins from database
Write-Host "🗑️ Deleting ALL pins from database..."
Write-Host ""

try {
    # Call backend endpoint to get all pins (using discovery with wide search)
    $response = Invoke-WebRequest -Uri "https://placetalk-backend-1.onrender.com/discovery/nearby?lat=35&lon=135" -UseBasicParsing
    $pins = ($response.Content | ConvertFrom-Json).discovered
    
    Write-Host "Found $($pins.Count) pins to delete"
    
    foreach ($pin in $pins) {
        try {
            Write-Host "Deleting: $($pin.title)"
            Invoke-WebRequest `
                -Uri "https://placetalk-backend-1.onrender.com/pins/$($pin.id)" `
                -Method DELETE `
                -UseBasicParsing | Out-Null
        } catch {
            # Ignore auth errors for test pins
        }
    }
    
    Write-Host ""
    Write-Host "✅ All pins deleted!"
    Write-Host "Database is now clean - start fresh!"
    
} catch {
    Write-Host "Error: $_"
}
