// 引入帮助函数
import { getRandomPhoneNumber, cleanupTestData, addMember, addMembershipCard, checkInMember, checkInNewMember, verifyCheckInResult } from '../support/checkin-helpers';

describe('签到功能测试', () => {
  const TEST_PREFIX = 'TestMember';
  
  beforeEach(() => {
    // 每个测试前清理测试数据
    cleanupTestData(TEST_PREFIX);
  });
  
  after(() => {
    // 所有测试完成后清理测试数据
    cleanupTestData(TEST_PREFIX);
  });
  
  it('已有会员成功签到', () => {
    // 1. 准备：创建会员和会员卡
    const memberName = `${TEST_PREFIX}CheckIn${Math.floor(Math.random() * 1000)}`;
    const phone = getRandomPhoneNumber();
    
    // 添加会员并获取会员ID
    cy.log('创建测试会员');
    addMember(memberName, phone).then(memberId => {
      // 添加会员卡
      cy.log('添加会员卡');
      addMembershipCard(
        memberId, 
        '团课卡', 
        '次卡', 
        '10次团课卡', 
        10, // 团课次数
        0,  // 私教次数
        null // 使用默认过期日期
      ).then(() => {
        // 2. 执行：进行签到
        cy.log('执行签到');
        checkInMember(memberName, '团课');
        
        // 3. 验证：签到成功
        cy.log('验证签到结果');
        verifyCheckInResult({ 
          expectedSuccess: true,
          expectedIsExtra: false,
          expectedIsNewMember: false,
          courseType: '团课'
        });
      });
    });
  });
  
  it('新会员签到(自动标记为额外签到)', () => {
    // 测试新会员签到
    const memberName = `${TEST_PREFIX}New${Math.floor(Math.random() * 1000)}`;
    const phone = getRandomPhoneNumber();
    
    // 执行新会员签到
    cy.log('新会员签到');
    checkInNewMember(memberName, phone, '团课');
    
    // 验证：签到成功，但标记为额外签到
    cy.log('验证签到结果');
    verifyCheckInResult({ 
      expectedSuccess: true,
      expectedIsExtra: true,
      expectedIsNewMember: true,
      courseType: '团课'
    });
  });
}); 