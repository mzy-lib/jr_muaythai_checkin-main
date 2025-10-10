import React, { createContext, useContext, useState, useEffect } from 'react';

interface Member {
  id: string;
  name: string;
  email: string;
  // ... 其他会员属性
}

interface MemberAuthContextType {
  member: Member | null;
  setMember: (member: Member | null) => void;
  isAuthenticated: boolean;
}

const MemberAuthContext = createContext<MemberAuthContextType | undefined>(undefined);

export function MemberAuthProvider({ children }: { children: React.ReactNode }) {
  const [member, setMember] = useState<Member | null>(() => {
    const storedMember = localStorage.getItem('member');
    return storedMember ? JSON.parse(storedMember) : null;
  });

  const isAuthenticated = !!member;

  const value = {
    member,
    setMember,
    isAuthenticated
  };

  return (
    <MemberAuthContext.Provider value={value}>
      {children}
    </MemberAuthContext.Provider>
  );
}

export function useMemberAuth() {
  const context = useContext(MemberAuthContext);
  if (context === undefined) {
    throw new Error('useMemberAuth must be used within a MemberAuthProvider');
  }
  return context;
} 