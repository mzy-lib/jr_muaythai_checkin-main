import { checkMembersData } from './fetchMembers';

// 运行查询
checkMembersData()
  .then(result => {
    console.log('查询完成，结果：', result);
    process.exit(0);
  })
  .catch(error => {
    console.error('查询出错：', error);
    process.exit(1);
  }); 