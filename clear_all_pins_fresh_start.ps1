# Clear all pins and user activities for fresh start with proper user isolation
Write-Host "🗂️ Clearing all existing pins for fresh user-based start..." -ForegroundColor yellow

# Database connection details  
$env:PGPASSWORD = "passwordplacetalk"

Write-Host "📊 Connecting to production database..." -ForegroundColor green

# Clear all existing data to start fresh
Write-Host "🗑️ Deleting user activities..." -ForegroundColor white
& psql -h "autorack.proxy.rlwy.net" -p "41345" -U "postgres" -d "railway" -c "DELETE FROM user_activities;"

Write-Host "🗑️ Deleting pin interactions..." -ForegroundColor white  
& psql -h "autorack.proxy.rlwy.net" -p "41345" -U "postgres" -d "railway" -c "DELETE FROM pin_interactions;"

Write-Host "🗑️ Deleting all pins..." -ForegroundColor white
& psql -h "autorack.proxy.rlwy.net" -p "41345" -U "postgres" -d "railway" -c "DELETE FROM pins;"

Write-Host "🔄 Resetting sequences..." -ForegroundColor white
& psql -h "autorack.proxy.rlwy.net" -p "41345" -U "postgres" -d "railway" -c "SELECT setval('pins_id_seq', 1, false);"
& psql -h "autorack.proxy.rlwy.net" -p "41345" -U "postgres" -d "railway" -c "SELECT setval('user_activities_id_seq', 1, false);"

Write-Host ""
Write-Host "🧹 Database cleaned! All pins, activities, and interactions removed." -ForegroundColor green
Write-Host "🎯 Ready for proper user-based pin creation and isolation testing." -ForegroundColor yellow
Write-Host ""
Write-Host "📱 Next steps:" -ForegroundColor cyan
Write-Host "1. Register new user in app" -ForegroundColor white  
Write-Host "2. Create pins - should show 0 in My Pins initially" -ForegroundColor white
Write-Host "3. Test user isolation - each user sees only their own pins" -ForegroundColor white