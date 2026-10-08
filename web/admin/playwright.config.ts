import { defineConfig } from '@playwright/test';
export default defineConfig({testDir:'./tests',workers:1,use:{baseURL:process.env.ADMIN_BROWSER_URL||'http://127.0.0.1:5173',headless:true},webServer:process.env.ADMIN_BROWSER_URL?undefined:{command:'npm run dev -- --port 5173',url:'http://127.0.0.1:5173',reuseExistingServer:true},reporter:'list'});
