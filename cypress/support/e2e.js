// ***********************************************************
// This file supports you when running your e2e tests.
// You can add global configuration and behavior that modifies Cypress here.
//
// You can change the location of this file or turn off
// automatically serving support files with the
// 'supportFile' configuration option.
//
// You can read more here:
// https://on.cypress.io/configuration
// ***********************************************************

// Import commands.js using CommonJS syntax
require('./commands.js');

// 添加自定义命令或覆盖
Cypress.Commands.add('login', (email, password) => {
  cy.visit('/login');
  cy.get('input[name="email"]').type(email);
  cy.get('input[name="password"]').type(password);
  cy.get('button[type="submit"]').click();
});

// 启用Grep命令支持（用于过滤测试）
// 如果没有安装cypress-grep包，下面这行会导致错误，可以删除
// require('cypress-grep'); 