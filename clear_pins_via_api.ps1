# Clear all pins via API endpoint
Write-Host "Clearing all pins via backend API..." -ForegroundColor Yellow

# Backend URL
$backendUrl = "https://placetalk-backend-1.onrender.com"

Write-Host "Checking current pins..." -ForegroundColor Green
try {
    $showResponse = Invoke-RestMethod -Uri "$backendUrl/debug/show-all-pins" -Method GET
    Write-Host "Found $($showResponse.total) pins in database" -ForegroundColor White
    
    if ($showResponse.total -gt 0) {
        Write-Host "Clearing all pins..." -ForegroundColor Yellow
        $clearResponse = Invoke-RestMethod -Uri "$backendUrl/debug/clear-all-pins" -Method DELETE
        
        if ($clearResponse.success) {
            Write-Host "SUCCESS: All pins cleared!" -ForegroundColor Green
            Write-Host "Pins remaining: $($clearResponse.remainingPins)" -ForegroundColor White
        } else {
            Write-Host "Failed to clear pins" -ForegroundColor Red
        }
    } else {
        Write-Host "Database is already empty" -ForegroundColor Green
    }
    
} catch {
    Write-Host "Error accessing backend API: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Make sure backend is running at $backendUrl" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. Install updated APK on device" -ForegroundColor White
Write-Host "2. Register as new user" -ForegroundColor White
Write-Host "3. My Pins should show 0 pins initially" -ForegroundColor White
Write-Host "4. Check debug info in app (pull down to refresh)" -ForegroundColor White