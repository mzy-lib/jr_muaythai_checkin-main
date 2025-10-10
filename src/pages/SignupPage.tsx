import { useNavigate } from 'react-router-dom';

export default function SignupPage() {
  const navigate = useNavigate();

  const handleSignupSuccess = () => {
    // 处理注册成功的逻辑
    navigate('/');
  };

  return (
    // ... 注册表单
    // 在注册成功时调用 handleSignupSuccess
  );
} 