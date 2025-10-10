import { useNavigate } from 'react-router-dom';

export default function LoginPage() {
  const navigate = useNavigate();

  const handleLoginSuccess = () => {
    // 处理登录成功的逻辑
    navigate('/');
  };

  return (
    // ... 登录表单
    // 在登录成功时调用 handleLoginSuccess
  );
} 