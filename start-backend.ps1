$env:DATABASE_HOST="localhost"
$env:DATABASE_PORT="5432"
$env:DATABASE_USER="sub2api"
$env:DATABASE_PASSWORD="localdev123"
$env:DATABASE_DBNAME="sub2api"
$env:DATABASE_SSLMODE="disable"
$env:REDIS_HOST="localhost"
$env:REDIS_PORT="6379"
$env:SERVER_MODE="debug"
$env:CREEM_ENABLED="true"
$env:CREEM_API_KEY="creem_test_7Tsax4NJ59j82OQz0h2k5K"
$env:CREEM_WEBHOOK_SECRET="whsec_6KCf29ZLEDMGl1rHfCiKqI"
$env:CREEM_PRODUCT_ID="prod_1ie4U2EdRlbIX79dhvIuxN"
$env:CREEM_RATE_MULTIPLIER="10"
$env:CREEM_SUCCESS_URL="https://f3f41fa283f4.ngrok-free.app/redeem?payment=success"

cd C:\Users\calvin\hbf-sub2api\backend
.\sub2api.exe
