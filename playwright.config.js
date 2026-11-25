const { defineConfig } = require("@playwright/test");
const path = require("path");

require("dotenv").config({
  path: path.resolve(__dirname, ".env"),
});

module.exports = defineConfig({
  testDir: "./tests/e2e",
  timeout: 30000,
  workers: 1,
  retries: 0,

  reporter: [
    ["list"],
    ["html", { open: "never" }],
  ],

  use: {
    baseURL: "http://localhost:3000",
    browserName: "chromium",
    headless: true,
    screenshot: "only-on-failure",
    trace: "retain-on-failure",
  },

  webServer: [
    {
      command: "npm run start -w backend",
      url: "http://localhost:3001/api/tags",
      env: {
        NODE_ENV: "test",
        PORT: "3001",
      },
      reuseExistingServer: false,
      timeout: 60000,
    },
    {
      command: "npm run dev -w frontend -- --strictPort",
      url: "http://localhost:3000",
      reuseExistingServer: false,
      timeout: 60000,
    },
  ],
});