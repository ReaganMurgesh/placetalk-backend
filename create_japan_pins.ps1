# Create Test Pins in Japan (Tokyo Area)
$headers = @{"Content-Type" = "application/json"}

# Pin 1: Tokyo Station Cafe
$pin1 = @{
    title = "Tokyo Station Cafe"
    directions = "Near Marunouchi Exit"
    details = "Great coffee and pastries"
    lat = 35.6812
    lon = 139.7671
    type = "location"
    pinCategory = "normal"
} | ConvertTo-Json

Write-Host "Creating Pin 1: Tokyo Station Cafe..."
Invoke-WebRequest -Uri "https://placetalk-backend-1.onrender.com/pins" -Method POST -Headers $headers -Body $pin1 -UseBasicParsing | Out-Null

# Pin 2: Akihabara Electronics Shop
$pin2 = @{
    title = "Akihabara Electronics"
    directions = "Electric Town exit"
    details = "Best gadget shop in the area"
    lat = 35.6980
    lon = 139.7730
    type = "location"
    pinCategory = "normal"
} | ConvertTo-Json

Write-Host "Creating Pin 2: Akihabara Electronics..."
Invoke-WebRequest -Uri "https://placetalk-backend-1.onrender.com/pins" -Method POST -Headers $headers -Body $pin2 -UseBasicParsing | Out-Null

# Pin 3: Shibuya Crossing
$pin3 = @{
    title = "Shibuya Crossing View"
    directions = "Hachiko statue side"
    details = "Perfect view of the crossing"
    lat = 35.6595
    lon = 139.7004
    type = "location"
    pinCategory = "normal"
} | ConvertTo-Json

Write-Host "Creating Pin 3: Shibuya Crossing..."
Invoke-WebRequest -Uri "https://placetalk-backend-1.onrender.com/pins" -Method POST -Headers $headers -Body $pin3 -UseBasicParsing | Out-Null

# Pin 4: Ueno Park  
$pin4 = @{
    title = "Ueno Park Entrance"
    directions = "Main gate"
    details = "Beautiful cherry blossoms in spring"
    lat = 35.7148
    lon = 139.7737
    type = "location"
    pinCategory = "normal"
} | ConvertTo-Json

Write-Host "Creating Pin 4: Ueno Park..."
Invoke-WebRequest -Uri "https://placetalk-backend-1.onrender.com/pins" -Method POST -Headers $headers -Body $pin4 -UseBasicParsing | Out-Null

Write-Host ""
Write-Host "✅ Created 4 test pins in Tokyo area!"
Write-Host "   - Tokyo Station (35.6812, 139.7671)"
Write-Host "   - Akihabara (35.6980, 139.7730)"
Write-Host "   - Shibuya (35.6595, 139.7004)"
Write-Host "   - Ueno Park (35.7148, 139.7737)"
