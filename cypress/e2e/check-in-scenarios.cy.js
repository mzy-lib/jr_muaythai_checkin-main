import {
  generateRandomMemberName,
  generateRandomEmail,
  cleanupTestData,
  GROUP_CLASS_TIME_SLOTS,
  PRIVATE_CLASS_TIME_SLOTS,
  TRAINERS,
  performCheckIn,
  verifyCheckInResult,
  createTestMember,
  addMembershipCard,
  addMember,
  checkInMember,
  checkInNewMember,
  fillCheckInForm,
  getRandomPhoneNumber
} from '../support/checkin-helpers';

describe('会员签到系统测试', () => {
  const TEST_PREFIX = 'Test_'; // 测试会员名称前缀，用于清理
  
  beforeEach(() => {
    // 访问应用并登录
    cy.visit('/');
    // 假设登录逻辑已实现，如果需要登录，可以添加登录步骤
    
    // 清理之前的测试数据
    cleanupTestData(TEST_PREFIX);
    
    // 访问签到页面
    cy.visit('/check-in');
  });
  
  it('新会员-团课签到测试', () => {
    const name = `${TEST_PREFIX}新会员1`;
    const phone = getRandomPhoneNumber();
    
    // 执行新会员团课签到
    checkInNewMember(name, phone, '团课');
    
    // 验证签到结果
    verifyCheckInResult({ 
      expectedSuccess: true,
      expectedIsExtra: true
    });
    
    // 验证会员已创建
    cy.visit('/members');
    cy.contains(name).should('be.visible');
    cy.contains(phone).should('be.visible');
  });
  
  it('新会员-私教签到测试', () => {
    const name = `${TEST_PREFIX}新会员2`;
    const phone = getRandomPhoneNumber();
    const trainerName = '张教练'; // 根据实际系统中的教练名称调整
    
    // 执行新会员私教签到
    checkInNewMember(name, phone, '私教', trainerName);
    
    // 验证签到结果
    verifyCheckInResult({ 
      expectedSuccess: true,
      expectedIsExtra: true
    });
    
    // 验证会员已创建
    cy.visit('/members');
    cy.contains(name).should('be.visible');
  });
  
  it('会员-有会员卡-团课签到测试', () => {
    const name = `${TEST_PREFIX}会员1`;
    const phone = getRandomPhoneNumber();
    
    // 创建会员
    addMember(name, phone).then(memberId => {
      // 添加会员卡
      addMembershipCard(
        memberId,
        '团课卡',
        '基础卡',
        '月卡',
        10, // 团课次数
        0 // 私教次数
      );
      
      // 访问签到页面
      cy.visit('/check-in');
      
      // 执行签到
      checkInMember(name, '团课');
      
      // 验证签到结果
      verifyCheckInResult({ expectedSuccess: true });
      
      // 验证剩余课时已更新
      cy.visit(`/members/${memberId}`);
      cy.contains('剩余团课：9次').should('be.visible');
    });
  });
  
  it('会员-无会员卡-团课签到测试', () => {
    const name = `${TEST_PREFIX}会员2`;
    const phone = getRandomPhoneNumber();
    
    // 创建会员（不添加会员卡）
    addMember(name, phone).then(() => {
      // 访问签到页面
      cy.visit('/check-in');
      
      // 执行签到
      checkInMember(name, '团课');
      
      // 验证签到结果 - 应为额外签到
      verifyCheckInResult({ 
        expectedSuccess: true,
        expectedIsExtra: true
      });
    });
  });
  
  it('会员-过期会员卡-签到测试', () => {
    const name = `${TEST_PREFIX}会员3`;
    const phone = getRandomPhoneNumber();
    
    // 创建过期日期（昨天）
    const yesterday = new Date();
    yesterday.setDate(yesterday.getDate() - 1);
    const expiredDate = yesterday.toISOString().split('T')[0];
    
    // 创建会员
    addMember(name, phone).then(memberId => {
      // 添加过期会员卡
      addMembershipCard(
        memberId,
        '团课卡',
        '基础卡',
        '月卡',
        10,
        0,
        expiredDate
      );
      
      // 访问签到页面
      cy.visit('/check-in');
      
      // 执行签到
      checkInMember(name, '团课');
      
      // 验证签到结果 - 应为额外签到
      verifyCheckInResult({ 
        expectedSuccess: true,
        expectedIsExtra: true
      });
    });
  });
  
  it('会员-私教卡-私教签到测试', () => {
    const name = `${TEST_PREFIX}会员4`;
    const phone = getRandomPhoneNumber();
    const trainerName = '李教练'; // 根据实际系统中的教练名称调整
    
    // 创建会员
    addMember(name, phone).then(memberId => {
      // 添加私教卡
      addMembershipCard(
        memberId,
        '私教卡',
        '高级卡',
        '季卡',
        0, // 团课次数
        20 // 私教次数
      );
      
      // 访问签到页面
      cy.visit('/check-in');
      
      // 执行私教签到
      checkInMember(name, '私教', trainerName);
      
      // 验证签到结果
      verifyCheckInResult({ expectedSuccess: true });
      
      // 验证剩余课时已更新
      cy.visit(`/members/${memberId}`);
      cy.contains('剩余私教：19次').should('be.visible');
    });
  });
  
  // 修改：会员重复签到测试 - 符合业务规则（允许重复签到）
  it('会员-重复签到测试', () => {
    const name = `${TEST_PREFIX}会员5`;
    const phone = getRandomPhoneNumber();
    
    // 创建会员
    addMember(name, phone).then(memberId => {
      // 添加会员卡，设置多些初始课时
      addMembershipCard(
        memberId,
        '团课卡',
        '基础卡',
        '季卡',
        10,
        0
      );
      
      // 访问签到页面
      cy.visit('/check-in');
      
      // 首次签到
      checkInMember(name, '团课');
      verifyCheckInResult({ expectedSuccess: true });
      
      // 验证首次签到后课时减少
      cy.visit(`/members/${memberId}`);
      cy.contains('剩余团课：9次').should('be.visible');
      
      // 再次访问签到页面
      cy.visit('/check-in');
      
      // 重复签到（根据业务规则，应该允许重复签到并再次扣费）
      checkInMember(name, '团课');
      
      // 验证重复签到成功
      verifyCheckInResult({ expectedSuccess: true });
      
      // 验证重复签到后课时再次减少
      cy.visit(`/members/${memberId}`);
      cy.contains('剩余团课：8次').should('be.visible');
    });
  });
  
  // 新增：测试允许重复签到并多次扣除课时（适用于多人共用一张卡的场景）
  it('会员-允许重复签到并多次扣费测试', () => {
    const name = `${TEST_PREFIX}共用卡会员`;
    const phone = getRandomPhoneNumber();
    
    // 创建会员
    addMember(name, phone).then(memberId => {
      // 添加会员卡，设置较多的初始课时
      addMembershipCard(
        memberId,
        '团课卡',
        '基础卡',
        '多人共享卡',
        20, // 团课次数
        0   // 私教次数
      );
      
      // 访问签到页面
      cy.visit('/check-in');
      
      // 执行第一次签到
      cy.log('执行第一次签到');
      checkInMember(name, '团课');
      verifyCheckInResult({ expectedSuccess: true });
      
      // 验证第一次签到后课时减少
      cy.visit(`/members/${memberId}`);
      cy.contains('剩余团课：19次').should('be.visible');
      
      // 执行第二次签到（同一天同时段同类型课程）
      cy.visit('/check-in');
      cy.log('执行第二次签到（模拟另一人使用同一张卡）');
      checkInMember(name, '团课');
      
      // 验证第二次签到也成功
      verifyCheckInResult({ expectedSuccess: true });
      
      // 验证第二次签到后课时再次减少
      cy.visit(`/members/${memberId}`);
      cy.contains('剩余团课：18次').should('be.visible');
      
      // 执行第三次签到
      cy.visit('/check-in');
      cy.log('执行第三次签到（模拟第三人使用同一张卡）');
      checkInMember(name, '团课');
      
      // 验证第三次签到也成功
      verifyCheckInResult({ expectedSuccess: true });
      
      // 验证第三次签到后课时再次减少
      cy.visit(`/members/${memberId}`);
      cy.contains('剩余团课：17次').should('be.visible');
      
      // 记录测试结论
      cy.log('测试确认：系统允许同一会员卡在同一天同类型课程进行多次签到并扣除课时');
    });
  });
}); 