import React from 'react';
import { Link } from 'react-router-dom';

interface Props {
  message: string;
}

export default function ExistingMemberPrompt({ message }: Props) {
  return (
    <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-4 mb-6">
      <p className="text-yellow-800 mb-4">{message}</p>
      <Link
        to="/member"
        className="inline-block bg-muaythai-blue text-white px-4 py-2 rounded-md hover:bg-blue-700 transition-colors"
      >
        前往会员签到页面 Go to Member Check-in
      </Link>
    </div>
  );
}