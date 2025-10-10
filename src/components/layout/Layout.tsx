import { ReactNode } from 'react';
import Header from '../common/Header';

interface LayoutProps {
  children: ReactNode;
  showHeader?: boolean;
  showTitle?: boolean;
}

export default function Layout({ 
  children, 
  showHeader = true,
  showTitle = false 
}: LayoutProps) {
  return (
    <div className="min-h-screen bg-gray-100">
      {showHeader && <Header showTitle={showTitle} />}
      <main>{children}</main>
    </div>
  );
} 