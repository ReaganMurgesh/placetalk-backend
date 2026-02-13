# Test Pin Creation Script
$headers = @{
    "Content-Type" = "application/json"
}

$body = @{
    title = "Test Cafe Chennai"
    directions = "Near Marina Beach"
    details = "Great coffee spot"
    lat = 13.0827
    lon = 80.2707
    type = "location"
    pinCategory = "normal"
} | ConvertTo-Json

Write-Host "Creating test pin..."
$response = Invoke-WebRequest `
    -Uri "https://placetalk-backend-1.onrender.com/pins" `
    -Method POST `
    -Headers $headers `
    -Body $body `
    -UseBasicParsing

Write-Host "Response:"
$response.Content | ConvertFrom-Json | ConvertTo-Json -Depth 10
