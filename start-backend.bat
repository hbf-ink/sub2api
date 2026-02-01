@echo off
cd /d C:\Users\calvin\hbf-sub2api\backend
set DATABASE_HOST=localhost
set DATABASE_PORT=5432
set DATABASE_USER=sub2api
set DATABASE_PASSWORD=localdev123
set DATABASE_DBNAME=sub2api
set DATABASE_SSLMODE=disable
set REDIS_HOST=localhost
set REDIS_PORT=6379
set SERVER_MODE=debug
set CREEM_ENABLED=true
set CREEM_API_KEY=creem_test_7Tsax4NJ59j82OQz0h2k5K
set CREEM_WEBHOOK_SECRET=whsec_6KCf29ZLEDMGl1rHfCiKqI
set CREEM_PRODUCT_ID=prod_1ie4U2EdRlbIX79dhvIuxN
set CREEM_RATE_MULTIPLIER=10
set CREEM_SUCCESS_URL=https://b3ab021d8571.ngrok-free.app/redeem?payment=success
sub2api.exe
