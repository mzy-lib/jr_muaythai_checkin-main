export const testMembers = [
  {
    name: '王小明',
    email: 'wang.xm1@test.com',
    membership: 'ten_classes',
    remaining_classes: 5
  },
  {
    name: '王小明',
    email: 'wang.xm2@test.com',
    membership: 'single_monthly',
    membership_expiry: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000)
  },
  {
    name: '测试会员A',
    email: 'member.a@test.com',
    membership: 'single_monthly',
    membership_expiry: new Date(Date.now() + 15 * 24 * 60 * 60 * 1000)
  },
  {
    name: '新会员测试',
    email: null,
    is_new_member: true
  }
];

export const testScenarios = [
  {
    description: '重名会员验证 - 不提供邮箱',
    input: {
      name: '王小明',
      classType: 'morning'
    },
    expectedResult: {
      needsEmailVerification: true,
      message: '存在重名会员，请输入邮箱验证身份。'
    }
  },
  {
    description: '重名会员验证 - 提供正确邮箱',
    input: {
      name: '王小明',
      email: 'wang.xm1@test.com',
      classType: 'morning'
    },
    expectedResult: {
      success: true,
      isExtra: false
    }
  },
  {
    description: '重名会员验证 - 提供错误邮箱',
    input: {
      name: '王小明',
      email: 'wrong@test.com',
      classType: 'morning'
    },
    expectedResult: {
      success: false,
      message: '邮箱验证失败，请重试。'
    }
  },
  {
    description: '普通会员签到',
    input: {
      name: '测试会员A',
      classType: 'morning'
    },
    expectedResult: {
      success: true,
      isExtra: false
    }
  },
  {
    description: '新会员签到',
    input: {
      name: '新会员测试',
      classType: 'morning'
    },
    expectedResult: {
      success: true,
      isExtra: true
    }
  }
];