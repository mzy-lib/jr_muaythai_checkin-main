import React from 'react';

interface HeaderProps {
  showTitle?: boolean;
}

export default function Header({ showTitle = false }: HeaderProps) {
  return (
    <header className="bg-white shadow">
      <div className="max-w-7xl mx-auto py-6 px-4 sm:px-6 lg:px-8">
        {showTitle && (
          <h1 className="flex items-center justify-center text-3xl font-bold">
            <span className="text-5xl mr-4">🥊</span>
            <span className="text-red-600">JR MUAY THAI</span>
            <span className="text-5xl ml-4">🥊</span>
          </h1>
        )}
      </div>
    </header>
  );
} 