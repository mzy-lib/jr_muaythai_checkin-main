import React from 'react';

interface ErrorMessageProps {
  message: string;
}

const ErrorMessage: React.FC<ErrorMessageProps> = ({ message }) => {
  return (
    <div className="text-red-600 p-4 bg-red-50 rounded-lg">
      {message}
    </div>
  );
};

export default ErrorMessage;