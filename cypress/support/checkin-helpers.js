// 生成随机会员名
export const generateRandomMemberName = () => {
  const prefix = 'Test';
  const randomNumber = Math.floor(Math.random() * 10000);
  return `${prefix}${randomNumber}`;
};

// 生成随机邮箱
export const generateRandomEmail = (name) => {
  const domains = ['test.com', 'example.com', 'cypress.io', 'testing.dev'];
  const randomDomain = domains[Math.floor(Math.random() * domains.length)];
  return `${name.toLowerCase()}@${randomDomain}`;
};

// 清理测试数据（通过API调用）- 旧版本
export const cleanupTestDataLegacy = (memberName) => {
  cy.request({
    method: 'POST',
    url: Cypress.env('apiUrl') + '/rpc/cleanup_test_data',
    body: { p_name_pattern: memberName },
    failOnStatusCode: false
  }).then(response => {
    cy.log(`清理测试数据结果: ${JSON.stringify(response.body)}`);
  });
};

// 常用团课时间段
export const GROUP_CLASS_TIME_SLOTS = {
  MORNING: '09:00-10:30',
  EVENING: '17:00-18:30'
};

// 常用私教时间段
export const PRIVATE_CLASS_TIME_SLOTS = [
  '07:00-08:00', '08:00-09:00', '10:30-11:30',  // 早课
  '14:00-15:00', '15:00-16:00', '16:00-17:00',  // 下午
  '18:30-19:30'  // 晚课
];

// 教练列表
export const TRAINERS = {
  JR: {
    name: 'JR',
    type: 'JR教练'
  },
  SENIOR: [
    { name: 'Da', type: '高级教练' },
    { name: 'Ming', type: '高级教练' },
    { name: 'Big', type: '高级教练' },
    { name: 'Bas', type: '高级教练' },
    { name: 'Sumay', type: '高级教练' },
    { name: 'First', type: '高级教练' }
  ]
};

// 执行签到操作
export const performCheckIn = ({
  courseType, // 'group' 或 'private'
  name,
  email,
  timeSlot,
  trainer = null,
  is1v2 = false
}) => {
  // 访问相应的签到页面
  const url = courseType === 'group' ? '/group-check-in' : '/private-check-in';
  cy.visit(url);
  
  // 填写签到表单
  cy.get('input[name="name"]').type(name);
  cy.get('input[name="email"]').type(email);
  
  if (timeSlot) {
    // 选择时间段
    cy.get('select[name="timeSlot"]').select(timeSlot);
  }
  
  if (courseType === 'private' && trainer) {
    // 选择教练
    cy.get('select[name="trainerId"]').select(trainer);
    
    // 如果是1v2课程，勾选对应选项
    if (is1v2) {
      cy.get('input[name="is1v2"]').check();
    }
  }
  
  // 提交表单
  cy.get('button[type="submit"]').click();
  
  // 等待请求完成
  cy.wait(2000);
};

// 验证签到结果（旧版本）
export const verifyCheckInResultLegacy = ({
  expectedSuccess = true,
  expectedIsExtra = false,
  expectedIsNewMember = false,
  expectedIsDuplicate = false
}) => {
  // 验证成功/失败状态
  if (expectedSuccess) {
    cy.contains('成功').should('be.visible');
  } else {
    cy.contains('失败').should('be.visible');
  }
  
  // 验证额外签到状态
  if (expectedIsExtra) {
    cy.contains('额外签到').should('be.visible');
  }
  
  // 验证新会员状态
  if (expectedIsNewMember) {
    cy.contains('新会员').should('be.visible');
  }
  
  // 验证重复签到状态
  if (expectedIsDuplicate) {
    cy.contains('重复签到').should('be.visible');
  }
};

// 通过API创建测试会员
export const createTestMember = (name, email) => {
  return cy.request({
    method: 'POST',
    url: Cypress.env('apiUrl') + '/rpc/register_new_member',
    body: {
      p_name: name,
      p_email: email,
      p_time_slot: GROUP_CLASS_TIME_SLOTS.MORNING,
      p_is_private: false
    }
  }).then(response => {
    expect(response.status).to.eq(200);
    expect(response.body.success).to.eq(true);
    return response.body.member_id;
  });
};

// 通过API为会员添加会员卡
export const addMembershipCardApi = (memberId, cardType, cardCategory = null, cardSubtype = null, remainingSessions = null, validUntil = null) => {
  // 计算默认有效期（30天后）
  const defaultValidUntil = validUntil || (() => {
    const date = new Date();
    date.setDate(date.getDate() + 30);
    return date.toISOString().split('T')[0];
  })();
  
  return cy.request({
    method: 'POST',
    url: Cypress.env('apiUrl') + '/rpc/add_membership_card',
    body: {
      p_member_id: memberId,
      p_card_type: cardType, // 'group' 或 'private'
      p_card_category: cardCategory, // 'session' 或 'monthly'（对团课）
      p_card_subtype: cardSubtype, // 具体卡类型
      p_remaining_group_sessions: cardType === 'group' ? remainingSessions : null,
      p_remaining_private_sessions: cardType === 'private' ? remainingSessions : null,
      p_valid_until: defaultValidUntil
    }
  }).then(response => {
    expect(response.status).to.eq(200);
    return response.body.card_id;
  });
};

// 签到测试帮助函数

// 生成随机电话号码
export function getRandomPhoneNumber() {
  return `1${Math.floor(Math.random() * 9) + 1}${Math.random().toString().slice(2, 11)}`;
}

// 清理测试数据
export function cleanupTestData(namePrefix) {
  cy.log(`清理以 "${namePrefix}" 开头的测试数据`);
  cy.request({
    method: 'DELETE',
    url: `/api/testing/cleanup?namePrefix=${encodeURIComponent(namePrefix)}`,
    failOnStatusCode: false
  }).then(response => {
    if (response.status === 200) {
      cy.log(`成功清理了 ${response.body.count || 0} 条测试数据`);
    } else {
      cy.log('清理测试数据失败或API不可用，继续测试');
    }
  });
}

// 添加测试会员
export function addMember(name, phone) {
  cy.log(`添加测试会员: ${name}`);
  
  // 访问会员管理页面
  cy.visit('/members');
  cy.contains('添加会员').click();
  
  // 填写会员信息
  cy.get('input[name="name"]').type(name);
  cy.get('input[name="phone"]').type(phone);
  cy.get('input[name="email"]').type(`${name.replace(/\s+/g, '').toLowerCase()}@test.com`);
  
  // 选择会员类型和性别
  cy.get('select[name="memberType"]').select('标准会员');
  cy.get('select[name="gender"]').select('男');
  
  // 提交表单
  cy.get('button[type="submit"]').click();
  
  // 等待创建完成并获取会员ID
  return cy.get('[data-member-id]').contains(name).parents('[data-member-id]')
    .invoke('attr', 'data-member-id').then(memberId => {
      cy.log(`创建的会员ID: ${memberId}`);
      return memberId;
    });
}

// 添加会员卡
export function addMembershipCard(memberId, cardType, cardCategory, cardSubtype, groupSessions = 0, privateSessions = 0, expiryDate = null) {
  cy.log(`为会员 ${memberId} 添加会员卡`);
  
  // 访问会员详情页
  cy.visit(`/members/${memberId}`);
  cy.contains('添加会员卡').click();
  
  // 填写会员卡信息
  cy.get('select[name="cardType"]').select(cardType);
  cy.get('select[name="cardCategory"]').select(cardCategory);
  cy.get('select[name="cardSubtype"]').select(cardSubtype);
  
  // 设置课时数量
  if (groupSessions > 0) {
    cy.get('input[name="groupSessions"]').clear().type(groupSessions);
  }
  if (privateSessions > 0) {
    cy.get('input[name="privateSessions"]').clear().type(privateSessions);
  }
  
  // 设置过期日期（如果提供）
  if (expiryDate) {
    cy.get('input[name="expiryDate"]').clear().type(expiryDate);
  } else {
    // 默认设置为30天后
    const futureDate = new Date();
    futureDate.setDate(futureDate.getDate() + 30);
    const formattedDate = futureDate.toISOString().split('T')[0];
    cy.get('input[name="expiryDate"]').clear().type(formattedDate);
  }
  
  // 提交表单
  cy.get('button[type="submit"]').contains('添加').click();
  
  // 等待创建完成并获取会员卡ID
  return cy.get('[data-card-id]').first()
    .invoke('attr', 'data-card-id').then(cardId => {
      cy.log(`创建的会员卡ID: ${cardId}`);
      return cardId;
    });
}

// 填写签到表单
export function fillCheckInForm(memberSearchTerm, courseType, trainerName = null) {
  // 搜索会员
  cy.get('input[name="memberSearch"]').clear().type(memberSearchTerm);
  cy.get('button').contains('搜索').click();
  cy.wait(500); // 等待搜索结果
  
  // 选择第一个搜索结果
  cy.get('.search-results').contains(memberSearchTerm).first().click();
  
  // 如果是私教课，选择教练
  if (courseType === '私教' && trainerName) {
    cy.get('select[name="trainer"]').select(trainerName);
  }
  
  // 提交签到
  cy.get('button[type="submit"]').contains('签到').click();
}

// 新会员签到
export function checkInNewMember(name, phone, courseType, trainerName = null) {
  cy.log(`新会员签到: ${name}, 课程类型: ${courseType}`);
  
  // 访问相应的签到页面
  const url = courseType === '私教' ? '/private-check-in' : '/group-check-in';
  cy.visit(url);
  
  // 填写基本信息 - 对于新会员，系统会自动检测并创建新会员
  // 使用标签文本查找输入字段
  cy.contains('label', '姓名').next('input').type(name);
  
  // 生成一个邮箱地址并填写
  const email = `${name.replace(/\s+/g, '').toLowerCase()}@test.com`;
  cy.contains('label', '邮箱').next('input').type(email);
  
  // 选择时间段 (团课为09:00-10:30, 私教有多个时段)
  if (courseType === '私教') {
    cy.contains('label', '时段').next('select').select('09:00-10:00');
    
    // 选择教练
    cy.contains('label', '教练').next('select').then($select => {
      if (trainerName) {
        cy.wrap($select).select(trainerName);
      } else {
        // 选择第一个可用的教练选项
        cy.wrap($select).find('option:not([value=""])').first().then(option => {
          cy.wrap($select).select(option.val());
        });
      }
    });
  } else {
    // 团课选择时间段
    cy.contains('label', '时间段').next('select').select('09:00-10:30');
  }
  
  // 提交签到
  cy.get('button[type="submit"]').contains('签到').click();
}

// 已有会员签到
export function checkInMember(memberName, courseType, trainerName = null) {
  cy.log(`会员签到: ${memberName}, 课程类型: ${courseType}`);
  
  // 访问相应的签到页面
  const url = courseType === '私教' ? '/private-check-in' : '/group-check-in';
  cy.visit(url);
  
  // 填写会员信息
  cy.contains('label', '姓名').next('input').type(memberName);
  
  // 生成一个邮箱地址并填写（已有会员也需要提供邮箱）
  const email = `${memberName.replace(/\s+/g, '').toLowerCase()}@test.com`;
  cy.contains('label', '邮箱').next('input').type(email);
  
  // 选择时间段 (团课为09:00-10:30, 私教有多个时段)
  if (courseType === '私教') {
    cy.contains('label', '时段').next('select').select('09:00-10:00');
    
    // 选择教练
    cy.contains('label', '教练').next('select').then($select => {
      if (trainerName) {
        cy.wrap($select).select(trainerName);
      } else {
        // 选择第一个可用的教练选项
        cy.wrap($select).find('option:not([value=""])').first().then(option => {
          cy.wrap($select).select(option.val());
        });
      }
    });
  } else {
    // 团课选择时间段
    cy.contains('label', '时间段').next('select').select('09:00-10:30');
  }
  
  // 提交签到
  cy.get('button[type="submit"]').contains('签到').click();
}

// 验证签到结果
export function verifyCheckInResult(options = {}) {
  const { 
    expectedSuccess = true, 
    expectedIsExtra = false,
    expectedIsDuplicate = false,
    expectedIsNewMember = false,
    courseType = '团课'
  } = options;
  
  if (expectedSuccess) {
    if (expectedIsNewMember) {
      // 新会员签到成功
      cy.contains('新会员签到成功', { timeout: 10000 }).should('be.visible');
    } else if (expectedIsExtra) {
      // 额外签到
      if (courseType === '私教') {
        cy.contains('私教课额外签到提醒', { timeout: 10000 }).should('be.visible');
      } else {
        cy.contains('额外签到提醒', { timeout: 10000 }).should('be.visible');
      }
      // 检查额外签到说明文本
      cy.contains('本次签到未扣除课时').should('be.visible');
    } else {
      // 普通签到成功
      if (courseType === '私教') {
        cy.contains('私教课签到成功', { timeout: 10000 }).should('be.visible');
      } else {
        cy.contains('签到成功', { timeout: 10000 }).should('be.visible');
      }
    }
  } else {
    if (expectedIsDuplicate) {
      // 重复签到
      cy.contains('重复签到提醒', { timeout: 10000 }).should('be.visible');
    } else {
      // 签到失败
      cy.contains('签到失败', { timeout: 10000 }).should('be.visible');
    }
  }
} 