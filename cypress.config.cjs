// cypress.config.cjs - CommonJS格式配置文件
const { defineConfig } = require('cypress');

module.exports = defineConfig({
  projectId: 'jr-checkin',
  e2e: {
    baseUrl: 'http://localhost:3011',
    supportFile: 'cypress/support/e2e.js',
    viewportWidth: 1280,
    viewportHeight: 720,
    defaultCommandTimeout: 10000,
    requestTimeout: 10000,
    env: {
      apiUrl: 'http://localhost:3011/api',
    },
    setupNodeEvents(on, config) {
      // 实现节点事件监听器，例如添加自定义任务
    },
  },
  retries: {
    runMode: 1,
    openMode: 0,
  },
}); 